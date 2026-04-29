import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = OpenRouterService.shared
    private var streamingTask: Task<Void, Never>?
    private var autoNameTask: Task<Void, Never>?

    /// During streaming, accumulate deltas and flush to the UI at most every `streamFlushInterval`
    /// seconds. Markdown re-parsing on every chunk is wasteful for long answers; ~80ms feels smooth.
    private let streamFlushInterval: TimeInterval = 0.08

    func sendMessage(model: String, conversations: ConversationsViewModel) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isLoading else { return }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = OpenRouterError.noModelSelected.errorDescription
            return
        }

        if conversations.activeConversationID == nil {
            conversations.newConversation()
        }

        let userMessage = Message(role: .user, content: inputText)
        conversations.updateActive { $0.messages.append(userMessage) }
        inputText = ""

        await streamCurrentConversation(model: model, conversations: conversations, allowAutoName: true)
    }

    /// Drop trailing assistant messages and re-stream from the last user message.
    func regenerate(model: String, conversations: ConversationsViewModel) async {
        guard !isLoading else { return }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = OpenRouterError.noModelSelected.errorDescription
            return
        }
        conversations.updateActive { convo in
            while convo.messages.last?.role == .assistant {
                convo.messages.removeLast()
            }
        }
        guard conversations.activeConversation?.messages.last?.role == .user else { return }

        await streamCurrentConversation(model: model, conversations: conversations, allowAutoName: false)
    }

    /// Replace the user message with `newContent`, drop everything after it, then re-stream.
    func editAndRegenerate(
        messageID: UUID,
        newContent: String,
        model: String,
        conversations: ConversationsViewModel
    ) async {
        guard !isLoading else { return }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = OpenRouterError.noModelSelected.errorDescription
            return
        }
        guard let convoID = conversations.activeConversationID else { return }
        conversations.editMessage(id: messageID, in: convoID, newContent: newContent)
        conversations.truncateAfter(messageID: messageID, in: convoID)

        await streamCurrentConversation(model: model, conversations: conversations, allowAutoName: false)
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        autoNameTask?.cancel()
    }

    private func streamCurrentConversation(
        model: String,
        conversations: ConversationsViewModel,
        allowAutoName: Bool
    ) async {
        guard let convoID = conversations.activeConversationID else { return }

        let messageCountBefore = conversations.activeConversation?.messages.count ?? 0
        let shouldAutoName = allowAutoName
            && messageCountBefore == 1
            && conversations.activeConversation?.name == "New Chat"

        isLoading = true
        errorMessage = nil

        let conversationToSend = conversations.activeConversation?.messages ?? []
        let systemPrompt = conversations.activeConversation?.systemPrompt
        let temperature = UserDefaults.standard.double(forKey: PreferenceKeys.temperature).nonZero
            ?? DefaultParameters.temperature
        let maxTokens = UserDefaults.standard.integer(forKey: PreferenceKeys.maxTokens).nonZero
            ?? DefaultParameters.maxTokens

        let startTime = Date()
        let flushInterval = streamFlushInterval

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            var assistantStarted = false
            var pendingDelta = ""
            var lastFlushDate = Date()

            @MainActor func flush() {
                guard !pendingDelta.isEmpty else { return }
                let toFlush = pendingDelta
                pendingDelta = ""
                conversations.updateActiveInMemory { convo in
                    if assistantStarted, var last = convo.messages.last, last.role == .assistant {
                        last.content += toFlush
                        convo.messages[convo.messages.count - 1] = last
                    } else {
                        convo.messages.append(Message(role: .assistant, content: toFlush))
                    }
                }
                assistantStarted = true
            }

            do {
                let stream = self.service.streamChatCompletion(
                    model: model,
                    messages: conversationToSend,
                    systemPrompt: systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens
                )
                for try await delta in stream {
                    if Task.isCancelled { break }
                    pendingDelta += delta
                    if Date().timeIntervalSince(lastFlushDate) >= flushInterval {
                        flush()
                        lastFlushDate = Date()
                    }
                }
                flush()

                // Stamp the assistant message with how long generation took.
                let duration = Date().timeIntervalSince(startTime)
                conversations.updateActiveInMemory { convo in
                    guard let lastIdx = convo.messages.indices.last,
                          convo.messages[lastIdx].role == .assistant else { return }
                    convo.messages[lastIdx].generationDuration = duration
                }

                conversations.saveActive()
                conversations.setModelForActive(model)

                if shouldAutoName, !Task.isCancelled {
                    self.autoNameTask?.cancel()
                    self.autoNameTask = Task { [weak self] in
                        await self?.autoNameConversation(id: convoID, model: model, conversations: conversations)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
                flush()
                if assistantStarted {
                    conversations.saveActive()
                }
            }

            self.isLoading = false
            self.streamingTask = nil
        }
        streamingTask = task
        await task.value
    }

    private func autoNameConversation(
        id: UUID,
        model: String,
        conversations: ConversationsViewModel
    ) async {
        guard let convo = conversations.conversations.first(where: { $0.id == id }) else { return }

        let summarizationContext = convo.messages + [
            Message(
                role: .user,
                content: "Reply with ONLY a 3-6 word title summarizing the conversation above. No quotes, no trailing punctuation."
            )
        ]

        do {
            let stream = service.streamChatCompletion(
                model: model,
                messages: summarizationContext,
                temperature: 0.3,
                maxTokens: 30
            )
            var title = ""
            for try await delta in stream {
                if Task.isCancelled { return }
                title += delta
            }
            if Task.isCancelled { return }
            let cleaned = title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "Title:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            conversations.renameConversation(id: id, to: String(cleaned.prefix(60)))
        } catch {
            // best-effort; leave the existing name
        }
    }

    func copyMessage(_ message: Message) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}
