import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var conversationsViewModel: ConversationsViewModel
    @FocusState private var isInputFocused: Bool
    @FocusState private var isChatSearchFocused: Bool
    @State private var showModelPicker: Bool = false
    @State private var showSystemPromptEditor: Bool = false
    @State private var showPromptPicker: Bool = false
    @State private var systemPromptDraft: String = ""
    @State private var chatSearchVisible: Bool = false
    @State private var chatSearchText: String = ""

    private var messages: [Message] {
        let all = conversationsViewModel.activeConversation?.messages ?? []
        let query = chatSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chatSearchVisible, !query.isEmpty else { return all }
        return all.filter { $0.content.localizedCaseInsensitiveContains(query) }
    }

    private var totalMessages: Int {
        conversationsViewModel.activeConversation?.messages.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            modelPickerBar
            Divider()

            if chatSearchVisible {
                chatSearchBar
                Divider()
            }

            if messages.isEmpty {
                emptyStateView
            } else {
                messagesScrollView
            }

            Divider()
            inputArea
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showSystemPromptEditor) {
            systemPromptSheet
        }
        .background(findShortcutButton)
    }

    /// Invisible button that registers Cmd+F as the standard "Find" action and adds it
    /// to the Edit menu automatically. Toggling closes the bar; opening focuses the field.
    private var findShortcutButton: some View {
        Button("Find in Chat") {
            if chatSearchVisible {
                chatSearchVisible = false
                chatSearchText = ""
            } else {
                chatSearchVisible = true
                isChatSearchFocused = true
            }
        }
        .keyboardShortcut("f", modifiers: [.command])
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var chatSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
            TextField("Search this chat", text: $chatSearchText)
                .textFieldStyle(.plain)
                .focused($isChatSearchFocused)
                .onSubmit { isChatSearchFocused = false }
                .onExitCommand {
                    chatSearchVisible = false
                    chatSearchText = ""
                }
            if !chatSearchText.isEmpty {
                Text("\(messages.count) of \(totalMessages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button {
                chatSearchVisible = false
                chatSearchText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close search (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.08))
    }

    private var modelPickerBar: some View {
        HStack(spacing: 8) {
            Button {
                showModelPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                    Text(modelsViewModel.selectedModel?.name ?? "Select a model to load")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
                modelPickerPopover
            }

            systemPromptIndicator

            Spacer()

            if let active = conversationsViewModel.activeConversation {
                conversationStatsView(for: active)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func conversationStatsView(for active: Conversation) -> some View {
        let model = modelsViewModel.selectedModel
        let usage = active.contextUsage(for: model)
        let cost = active.estimatedCost(for: model)

        HStack(spacing: 8) {
            if let cost, cost > 0 {
                Text(Self.formatCost(cost))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("Estimated USD cost based on heuristic token count and the model's per-token price.")
            }

            Text(active.displayTokens)
                .font(.caption)
                .foregroundColor(tokenLabelColor(usage: usage))
                .help(contextHelpText(usage: usage, model: model))

            if let usage, usage >= 0.8 {
                Image(systemName: usage >= 1.0 ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(usage >= 1.0 ? .red : .orange)
                    .help(contextHelpText(usage: usage, model: model))
            }
        }
    }

    private func tokenLabelColor(usage: Double?) -> Color {
        guard let usage else { return .secondary }
        if usage >= 1.0 { return .red }
        if usage >= 0.8 { return .orange }
        return .secondary
    }

    private func contextHelpText(usage: Double?, model: OpenRouterModel?) -> String {
        guard let usage, let limit = model?.contextLength else {
            return "Approximate token count for this chat."
        }
        let pct = Int(usage * 100)
        return "\(pct)% of \(limit.formatted()) token context window."
    }

    /// Format USD cost with appropriate precision. Sub-cent → "<$0.01".
    private static func formatCost(_ value: Double) -> String {
        if value < 0.01 { return "<$0.01" }
        if value < 1 { return String(format: "$%.3f", value) }
        return String(format: "$%.2f", value)
    }

    @ViewBuilder
    private var systemPromptIndicator: some View {
        if conversationsViewModel.activeConversation != nil {
            let hasPrompt = !(conversationsViewModel.activeConversation?.systemPrompt?.isEmpty ?? true)
            Button {
                systemPromptDraft = conversationsViewModel.activeConversation?.systemPrompt ?? ""
                showSystemPromptEditor = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: hasPrompt ? "text.badge.checkmark" : "text.badge.plus")
                    Text(hasPrompt ? "System prompt" : "Add system prompt")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(hasPrompt ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(hasPrompt
                  ? (conversationsViewModel.activeConversation?.systemPrompt ?? "")
                  : "No system prompt set for this chat")
        }
    }

    private var systemPromptSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Prompt")
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
                Button("Clear") {
                    systemPromptDraft = ""
                }
                Spacer()
                Button("Cancel") {
                    showSystemPromptEditor = false
                }
                Button("Save") {
                    if let id = conversationsViewModel.activeConversationID {
                        conversationsViewModel.setSystemPrompt(for: id, to: systemPromptDraft)
                    }
                    showSystemPromptEditor = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private var modelPickerPopover: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search models...", text: $modelsViewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Toggle("Free only", isOn: $modelsViewModel.freeOnly)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Only show $0 / $0 models")
            }
            .padding(8)

            Divider()

            if modelsViewModel.isLoading {
                ProgressView().padding()
            } else if modelsViewModel.filteredModels.isEmpty {
                VStack(spacing: 8) {
                    Text(modelsViewModel.errorMessage ?? "No models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if modelsViewModel.errorMessage != nil {
                        Button("Retry") {
                            Task { await modelsViewModel.fetchModels() }
                        }
                        .controlSize(.small)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(modelsViewModel.groupedModels, id: \.family) { group in
                            Text(group.family)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                            ForEach(group.models) { model in
                                Button {
                                    modelsViewModel.selectModel(model)
                                    showModelPicker = false
                                } label: {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(model.name)
                                                .lineLimit(1)
                                            if let price = model.priceDescription {
                                                Text(price)
                                                    .font(.caption2)
                                                    .foregroundColor(model.isFree ? .green : .secondary)
                                            }
                                        }
                                        Spacer()
                                        if modelsViewModel.selectedModel?.id == model.id {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 360)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.badge.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(conversationsViewModel.activeConversationID == nil
                 ? "Create a chat to begin"
                 : "Start a conversation")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Pick a model above and send a message")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if conversationsViewModel.activeConversationID == nil {
                Button("New Chat") {
                    conversationsViewModel.newConversation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages) { message in
                        MessageRow(
                            message: message,
                            isLastAssistant: message.id == messages.last?.id && message.role == .assistant && !chatViewModel.isLoading,
                            onEdit: message.role == .user ? { newContent in editAndRegenerate(messageID: message.id, newContent: newContent) } : nil,
                            onRegenerate: { regenerate() },
                            onRegenerateWithModel: { modelID in regenerate(modelOverride: modelID) }
                        )
                        .id(message.id)
                    }

                    if chatViewModel.isLoading && messages.last?.role != .assistant {
                        loadingIndicator
                            .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: conversationsViewModel.activeConversationID) {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private var loadingIndicator: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                Circle()
                    .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                    .frame(width: 30, height: 30)
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .tint(Color.blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Thinking")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 4, height: 4)
                            .offset(y: CGFloat(index % 2 == 0 ? 0 : 2))
                    }
                }
                .frame(height: 4)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            if let error = chatViewModel.errorMessage {
                errorBanner(error)
            }

            HStack(alignment: .bottom, spacing: 12) {
                templatesButton

                textEditorView
                    .focused($isInputFocused)

                if chatViewModel.isLoading {
                    stopButton
                } else {
                    sendButton
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 18))
        }
        .buttonStyle(.borderedProminent)
        .disabled(
            chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            modelsViewModel.selectedModel == nil
        )
    }

    private var templatesButton: some View {
        Button {
            showPromptPicker.toggle()
        } label: {
            Image(systemName: "text.append")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Insert prompt template")
        .popover(isPresented: $showPromptPicker, arrowEdge: .top) {
            PromptPickerView(isPresented: $showPromptPicker)
        }
    }

    private var stopButton: some View {
        Button(action: { chatViewModel.cancelStreaming() }) {
            Image(systemName: "stop.fill")
                .font(.system(size: 18))
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .help("Stop streaming")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button(action: { chatViewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .foregroundColor(.orange)
    }

    private var textEditorView: some View {
        TextEditor(text: $chatViewModel.inputText)
            .font(.body)
            .frame(minHeight: 40, maxHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .onKeyPress(.return) {
                if NSEvent.modifierFlags.contains(.shift) {
                    chatViewModel.inputText += "\n"
                    return .handled
                } else {
                    sendMessage()
                    return .handled
                }
            }
    }

    private func sendMessage() {
        guard let model = modelsViewModel.selectedModel else { return }
        isInputFocused = false
        Task {
            await chatViewModel.sendMessage(model: model.id, conversations: conversationsViewModel)
        }
    }

    private func regenerate(modelOverride: String? = nil) {
        let modelID = modelOverride ?? modelsViewModel.selectedModel?.id
        guard let modelID else { return }
        Task {
            await chatViewModel.regenerate(model: modelID, conversations: conversationsViewModel)
        }
    }

    private func editAndRegenerate(messageID: UUID, newContent: String) {
        guard let model = modelsViewModel.selectedModel else { return }
        Task {
            await chatViewModel.editAndRegenerate(
                messageID: messageID,
                newContent: newContent,
                model: model.id,
                conversations: conversationsViewModel
            )
        }
    }
}
