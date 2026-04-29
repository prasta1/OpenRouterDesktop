import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SidebarView: View {
    @EnvironmentObject var conversationsViewModel: ConversationsViewModel
    @EnvironmentObject var modelsViewModel: ModelsViewModel

    @State private var renamingFolder: ChatFolder?
    @State private var renamingConversation: Conversation?
    @State private var systemPromptConversation: Conversation?
    @State private var renameText: String = ""
    @State private var systemPromptDraft: String = ""
    @State private var topLevelDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            chatList
            Divider()
            statusSection
        }
        .background(.ultraThinMaterial)
        .sheet(item: $renamingFolder) { folder in
            renameSheet(title: "Rename Folder", initial: folder.name) { newName in
                conversationsViewModel.renameFolder(id: folder.id, to: newName)
            }
        }
        .sheet(item: $renamingConversation) { convo in
            renameSheet(title: "Rename Chat", initial: convo.name) { newName in
                conversationsViewModel.renameConversation(id: convo.id, to: newName)
            }
        }
        .sheet(item: $systemPromptConversation) { convo in
            systemPromptSheet(for: convo)
        }
    }

    private var header: some View {
        HStack {
            Text("Chats")
                .font(.headline)
            Spacer()
            Menu {
                Button {
                    conversationsViewModel.newFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button {
                    conversationsViewModel.newConversation()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                conversationsViewModel.newConversation()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("New Chat")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        TextField("Search chats...", text: $conversationsViewModel.searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    private var chatList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                Button {
                    conversationsViewModel.newFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption)
                        Text("New Folder")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                ForEach(conversationsViewModel.folders) { folder in
                    folderRow(folder)
                }

                if !conversationsViewModel.folders.isEmpty {
                    Divider().padding(.vertical, 4)
                }

                ForEach(conversationsViewModel.topLevelConversations) { convo in
                    conversationRow(convo, indented: false)
                }

                topLevelDropZone

                if conversationsViewModel.conversations.isEmpty && conversationsViewModel.folders.isEmpty {
                    emptyState
                }
            }
            .padding(.bottom, 8)
        }
    }

    /// A drop zone at the bottom that catches "move to top level" drops even when no top-level chats exist.
    private var topLevelDropZone: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .overlay(
                Rectangle()
                    .stroke(topLevelDropTargeted ? Color.accentColor : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .padding(.horizontal, 6)
            )
            .onDrop(of: [.text], isTargeted: $topLevelDropTargeted) { providers in
                handleDrop(providers: providers, toFolder: nil)
            }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No chats yet")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Start a new chat") {
                conversationsViewModel.newConversation()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func folderRow(_ folder: ChatFolder) -> some View {
        FolderRow(
            folder: folder,
            isExpanded: conversationsViewModel.expandedFolderIDs.contains(folder.id),
            conversations: conversationsViewModel.conversations(in: folder.id),
            activeID: conversationsViewModel.activeConversationID,
            onToggle: { conversationsViewModel.toggleFolder(id: folder.id) },
            onRename: { renamingFolder = folder },
            onDelete: { conversationsViewModel.deleteFolder(id: folder.id) },
            onNewChatInFolder: { conversationsViewModel.newConversation(in: folder.id) },
            onSelectConversation: { conversationsViewModel.activeConversationID = $0 },
            onRenameConversation: { renamingConversation = $0 },
            onTogglePin: { conversationsViewModel.togglePin(id: $0) },
            onMoveConversation: { conversationsViewModel.moveConversation(id: $0, toFolder: $1) },
            onDeleteConversation: { conversationsViewModel.deleteConversation(id: $0) },
            onEditSystemPrompt: { systemPromptConversation = $0 },
            onExport: { exportConversation($0) },
            onDrop: { providers in handleDrop(providers: providers, toFolder: folder.id) },
            allFolders: conversationsViewModel.folders
        )
    }

    private func conversationRow(_ convo: Conversation, indented: Bool) -> some View {
        ConversationRow(
            conversation: convo,
            isActive: conversationsViewModel.activeConversationID == convo.id,
            indented: indented,
            allFolders: conversationsViewModel.folders,
            onTap: { conversationsViewModel.activeConversationID = convo.id },
            onRename: { renamingConversation = convo },
            onTogglePin: { conversationsViewModel.togglePin(id: convo.id) },
            onMove: { conversationsViewModel.moveConversation(id: convo.id, toFolder: $0) },
            onDelete: { conversationsViewModel.deleteConversation(id: convo.id) },
            onEditSystemPrompt: { systemPromptConversation = convo },
            onExport: { exportConversation(convo) }
        )
    }

    private func renameSheet(title: String, initial: String, onSave: @escaping (String) -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Button("Cancel") {
                    renamingFolder = nil
                    renamingConversation = nil
                }
                Spacer()
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onSave(trimmed) }
                    renamingFolder = nil
                    renamingConversation = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .frame(width: 280)
        }
        .padding(20)
        .onAppear { renameText = initial }
    }

    private func systemPromptSheet(for convo: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Prompt — \(convo.name)")
                .font(.headline)
            Text("Sent as a `system` message at the start of every API call for this chat. Leave empty to disable.")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $systemPromptDraft)
                .font(.body)
                .frame(width: 480, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            HStack {
                Button("Clear") { systemPromptDraft = "" }
                Spacer()
                Button("Cancel") { systemPromptConversation = nil }
                Button("Save") {
                    conversationsViewModel.setSystemPrompt(for: convo.id, to: systemPromptDraft)
                    systemPromptConversation = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { systemPromptDraft = convo.systemPrompt ?? "" }
    }

    private var statusSection: some View {
        HStack {
            Circle()
                .fill(modelsViewModel.hasAPIKey ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(modelsViewModel.hasAPIKey ? "API Key Configured" : "No API Key")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func handleDrop(providers: [NSItemProvider], toFolder folderID: UUID?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let raw = object as? String, let id = UUID(uuidString: raw) else { return }
            DispatchQueue.main.async {
                conversationsViewModel.moveConversation(id: id, toFolder: folderID)
            }
        }
        return true
    }

    private func exportConversation(_ convo: Conversation) {
        guard let markdown = conversationsViewModel.markdownExport(for: convo.id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(convo.name).md"
        panel.title = "Export Chat"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - FolderRow

private struct FolderRow: View {
    let folder: ChatFolder
    let isExpanded: Bool
    let conversations: [Conversation]
    let activeID: UUID?
    let onToggle: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onNewChatInFolder: () -> Void
    let onSelectConversation: (UUID) -> Void
    let onRenameConversation: (Conversation) -> Void
    let onTogglePin: (UUID) -> Void
    let onMoveConversation: (UUID, UUID?) -> Void
    let onDeleteConversation: (UUID) -> Void
    let onEditSystemPrompt: (Conversation) -> Void
    let onExport: (Conversation) -> Void
    let onDrop: ([NSItemProvider]) -> Bool
    let allFolders: [ChatFolder]

    @State private var isDropTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
            .contextMenu {
                Button("New Chat in Folder", action: onNewChatInFolder)
                Button("Rename", action: onRename)
                Divider()
                Button("Delete Folder", role: .destructive, action: onDelete)
            }
            .onDrop(of: [.text], isTargeted: $isDropTargeted, perform: onDrop)

            if isExpanded {
                if conversations.isEmpty {
                    Text("Folder is Empty")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.leading, 36)
                        .padding(.vertical, 4)
                } else {
                    ForEach(conversations) { convo in
                        ConversationRow(
                            conversation: convo,
                            isActive: activeID == convo.id,
                            indented: true,
                            allFolders: allFolders,
                            onTap: { onSelectConversation(convo.id) },
                            onRename: { onRenameConversation(convo) },
                            onTogglePin: { onTogglePin(convo.id) },
                            onMove: { onMoveConversation(convo.id, $0) },
                            onDelete: { onDeleteConversation(convo.id) },
                            onEditSystemPrompt: { onEditSystemPrompt(convo) },
                            onExport: { onExport(convo) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - ConversationRow

private struct ConversationRow: View {
    let conversation: Conversation
    let isActive: Bool
    let indented: Bool
    let allFolders: [ChatFolder]
    let onTap: () -> Void
    let onRename: () -> Void
    let onTogglePin: () -> Void
    let onMove: (UUID?) -> Void
    let onDelete: () -> Void
    let onEditSystemPrompt: () -> Void
    let onExport: () -> Void

    @EnvironmentObject var conversationsViewModel: ConversationsViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .help("Pinned")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.name.isEmpty ? "New Chat" : conversation.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                if let snippet = matchSnippet {
                    Text(snippet)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if conversation.approxTokenCount > 0 {
                    Text(conversation.displayTokens)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if conversation.systemPrompt?.isEmpty == false {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .help("Has system prompt")
            }
        }
        .padding(.leading, indented ? 36 : 12)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onDrag {
            NSItemProvider(object: conversation.id.uuidString as NSString)
        }
        .contextMenu {
            Button(conversation.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Rename", action: onRename)
            Button("Edit System Prompt", action: onEditSystemPrompt)
            Menu("Move to") {
                Button("Top Level") { onMove(nil) }
                if !allFolders.isEmpty {
                    Divider()
                    ForEach(allFolders) { folder in
                        Button(folder.name) { onMove(folder.id) }
                    }
                }
            }
            Button("Export as Markdown…", action: onExport)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    /// When the user is searching and the match is in message content (not the title),
    /// produce a one-line snippet around the match with the matched substring bolded.
    /// Returns nil if there's no search, or if the title alone matched.
    private var matchSnippet: AttributedString? {
        let query = conversationsViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        if conversation.name.range(of: query, options: .caseInsensitive) != nil { return nil }
        for msg in conversation.messages {
            if let range = msg.content.range(of: query, options: .caseInsensitive) {
                return Self.buildSnippet(content: msg.content, matchRange: range, query: query)
            }
        }
        return nil
    }

    private static func buildSnippet(content: String, matchRange: Range<String.Index>, query: String) -> AttributedString {
        let lower = content.index(matchRange.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
        let upper = content.index(matchRange.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex
        var snippet = String(content[lower..<upper])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if lower != content.startIndex { snippet = "…" + snippet }
        if upper != content.endIndex { snippet += "…" }

        var attr = AttributedString(snippet)
        if let matchRange = attr.range(of: query, options: .caseInsensitive) {
            attr[matchRange].font = .system(size: 10, weight: .semibold)
            attr[matchRange].foregroundColor = .accentColor
        }
        return attr
    }
}
