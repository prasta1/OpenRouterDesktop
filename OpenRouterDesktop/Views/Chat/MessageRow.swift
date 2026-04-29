import SwiftUI
import MarkdownUI

struct MessageRow: View {
    let message: Message
    let isLastAssistant: Bool
    let onEdit: ((String) -> Void)?
    let onRegenerate: (() -> Void)?
    let onRegenerateWithModel: ((String) -> Void)?

    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var conversationsViewModel: ConversationsViewModel
    @EnvironmentObject var modelsViewModel: ModelsViewModel

    @State private var showEditSheet: Bool = false

    init(
        message: Message,
        isLastAssistant: Bool = false,
        onEdit: ((String) -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil,
        onRegenerateWithModel: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.isLastAssistant = isLastAssistant
        self.onEdit = onEdit
        self.onRegenerate = onRegenerate
        self.onRegenerateWithModel = onRegenerateWithModel
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                messageBubble
                if message.role == .assistant, let footer = timingFooter {
                    footer
                }
                actionButtons
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showEditSheet) {
            EditMessageSheet(originalContent: message.content) { newContent in
                onEdit?(newContent)
            }
        }
    }

    private var messageBubble: some View {
        Markdown(message.content)
            .markdownTheme(.gitHub)
            .markdownCodeSyntaxHighlighter(.swiftHighlighter)
            .markdownBlockStyle(\.codeBlock) { configuration in
                CopyableCodeBlock(configuration: configuration)
            }
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(messageBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var timingFooter: Text? {
        guard let duration = message.generationDuration, duration > 0 else { return nil }
        let approxTokens = max(1, message.content.approximateTokenCount)
        let tokensPerSecond = Double(approxTokens) / duration
        let durationStr = String(format: "%.1fs", duration)
        let tpsStr = tokensPerSecond >= 100
            ? String(format: "%.0f t/s", tokensPerSecond)
            : String(format: "%.1f t/s", tokensPerSecond)
        return Text("\(durationStr) · \(approxTokens) tokens · \(tpsStr)")
    }

    private var messageBackground: some View {
        Group {
            if message.role == .user {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                .background(
                    Circle()
                        .fill(avatarColor)
                )
                .frame(width: 32, height: 32)
            Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }

    /// Click = regenerate with currently-selected model.
    /// Disclosure menu = pick a different model for this regeneration.
    @ViewBuilder
    private func regenerateControl(onRegenerate: @escaping () -> Void) -> some View {
        if let onRegenerateWithModel, !modelsViewModel.filteredModels.isEmpty {
            Menu {
                ForEach(modelsViewModel.filteredModels) { model in
                    Button(model.name) { onRegenerateWithModel(model.id) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            } primaryAction: {
                onRegenerate()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .help("Regenerate (click) — or pick a different model")
            .disabled(chatViewModel.isLoading)
        } else {
            Button(action: onRegenerate) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Regenerate response")
            .disabled(chatViewModel.isLoading)
        }
    }

    private var avatarColor: Color {
        switch message.role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.purple
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: { chatViewModel.copyMessage(message) }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy")

            if message.role == .user, onEdit != nil {
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Edit & regenerate")
                .disabled(chatViewModel.isLoading)
            }

            if isLastAssistant, let onRegenerate {
                regenerateControl(onRegenerate: onRegenerate)
            }

            if let convoID = conversationsViewModel.activeConversationID {
                Button(action: { conversationsViewModel.deleteMessage(message, in: convoID) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
        .foregroundColor(.secondary)
        .padding(4)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}
