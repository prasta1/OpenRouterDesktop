import Foundation
import SwiftUI

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published private(set) var folders: [ChatFolder] = []
    @Published private(set) var conversations: [Conversation] = []
    @Published var activeConversationID: UUID?
    @Published var searchText: String = ""
    @Published var expandedFolderIDs: Set<UUID> = []

    private let store = ConversationStore.shared

    init() {
        load()
    }

    private func load() {
        let index = store.loadIndex()
        folders = index.folders
        var loaded = store.loadAllConversations()

        if loaded.isEmpty, let migrated = store.migrateLegacyConversation() {
            loaded.append(migrated)
        }

        loaded.sort { $0.updatedAt > $1.updatedAt }
        conversations = loaded
        activeConversationID = conversations.first?.id
        expandedFolderIDs = Set(folders.map { $0.id })
    }

    var activeConversation: Conversation? {
        guard let id = activeConversationID else { return nil }
        return conversations.first { $0.id == id }
    }

    var visibleConversations: [Conversation] {
        let sorted = conversations.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { convo in
            if convo.name.localizedCaseInsensitiveContains(searchText) { return true }
            return convo.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var topLevelConversations: [Conversation] {
        visibleConversations.filter { $0.folderID == nil }
    }

    func conversations(in folderID: UUID) -> [Conversation] {
        visibleConversations.filter { $0.folderID == folderID }
    }

    // MARK: - Folder mutations

    @discardableResult
    func newFolder(name: String = "New Folder") -> ChatFolder {
        let folder = ChatFolder(name: name)
        folders.append(folder)
        expandedFolderIDs.insert(folder.id)
        persistIndex()
        return folder
    }

    func renameFolder(id: UUID, to newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = newName
        persistIndex()
    }

    /// Deletes the folder. Conversations inside it are moved to top level (folderID = nil).
    func deleteFolder(id: UUID) {
        for i in conversations.indices where conversations[i].folderID == id {
            conversations[i].folderID = nil
            store.save(conversations[i])
        }
        folders.removeAll { $0.id == id }
        expandedFolderIDs.remove(id)
        persistIndex()
    }

    func toggleFolder(id: UUID) {
        if expandedFolderIDs.contains(id) {
            expandedFolderIDs.remove(id)
        } else {
            expandedFolderIDs.insert(id)
        }
    }

    // MARK: - Conversation mutations

    @discardableResult
    func newConversation(in folderID: UUID? = nil) -> Conversation {
        let convo = Conversation(folderID: folderID)
        conversations.insert(convo, at: 0)
        store.save(convo)
        activeConversationID = convo.id
        if let folderID { expandedFolderIDs.insert(folderID) }
        return convo
    }

    func renameConversation(id: UUID, to newName: String) {
        mutateConversation(id: id) { $0.name = newName }
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        store.delete(conversationID: id)
        if activeConversationID == id {
            activeConversationID = conversations.first?.id
        }
    }

    func moveConversation(id: UUID, toFolder folderID: UUID?) {
        mutateConversation(id: id) { $0.folderID = folderID }
        if let folderID { expandedFolderIDs.insert(folderID) }
    }

    func setModelForActive(_ modelID: String) {
        guard let id = activeConversationID else { return }
        mutateConversation(id: id) { $0.modelID = modelID }
    }

    func togglePin(id: UUID) {
        mutateConversation(id: id) { $0.isPinned.toggle() }
    }

    /// Edit an existing message's content. Used by edit-and-regenerate flow.
    func editMessage(id messageID: UUID, in conversationID: UUID, newContent: String) {
        mutateConversation(id: conversationID) { convo in
            guard let idx = convo.messages.firstIndex(where: { $0.id == messageID }) else { return }
            convo.messages[idx].content = newContent
        }
    }

    /// Drops every message whose index is greater than the matched message's. The matched message itself is kept.
    func truncateAfter(messageID: UUID, in conversationID: UUID) {
        mutateConversation(id: conversationID) { convo in
            guard let idx = convo.messages.firstIndex(where: { $0.id == messageID }) else { return }
            if idx + 1 < convo.messages.count {
                convo.messages.removeSubrange((idx + 1)..<convo.messages.count)
            }
        }
    }

    func setSystemPrompt(for conversationID: UUID, to prompt: String?) {
        let trimmed = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        mutateConversation(id: conversationID) { $0.systemPrompt = value }
    }

    /// Markdown rendering of a conversation. Used for export.
    func markdownExport(for conversationID: UUID) -> String? {
        guard let convo = conversations.first(where: { $0.id == conversationID }) else { return nil }
        var lines: [String] = []
        lines.append("# \(convo.name)")
        lines.append("")
        if let modelID = convo.modelID {
            lines.append("_Model: \(modelID)_")
            lines.append("")
        }
        if let prompt = convo.systemPrompt, !prompt.isEmpty {
            lines.append("## System")
            lines.append("")
            lines.append(prompt)
            lines.append("")
        }
        for message in convo.messages {
            let header = message.role == .user ? "## User" : "## Assistant"
            lines.append(header)
            lines.append("")
            lines.append(message.content)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Navigation helpers

    func selectAdjacentChat(direction: Int) {
        let visible = visibleConversations
        guard !visible.isEmpty else { return }
        let currentIdx = visible.firstIndex { $0.id == activeConversationID } ?? 0
        let count = visible.count
        let newIdx = ((currentIdx + direction) % count + count) % count
        activeConversationID = visible[newIdx].id
    }

    /// Mutates the active conversation in place. Touches `updatedAt` and writes to disk.
    func updateActive(_ change: (inout Conversation) -> Void) {
        guard let id = activeConversationID else { return }
        mutateConversation(id: id, change: change)
    }

    /// In-memory only — used during streaming so we don't hit disk on every chunk.
    func updateActiveInMemory(_ change: (inout Conversation) -> Void) {
        guard let id = activeConversationID,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[idx])
        conversations[idx].updatedAt = Date()
    }

    func saveActive() {
        guard let active = activeConversation else { return }
        store.save(active)
    }

    func deleteMessage(_ message: Message, in conversationID: UUID) {
        mutateConversation(id: conversationID) { convo in
            convo.messages.removeAll { $0.id == message.id }
        }
    }

    func clearActiveMessages() {
        guard let id = activeConversationID else { return }
        mutateConversation(id: id) { $0.messages.removeAll() }
    }

    private func mutateConversation(id: UUID, change: (inout Conversation) -> Void) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[idx])
        conversations[idx].updatedAt = Date()
        store.save(conversations[idx])
    }

    private func persistIndex() {
        store.saveIndex(ConversationStore.Index(folders: folders))
    }
}
