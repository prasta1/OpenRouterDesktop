import SwiftUI

struct PromptPickerView: View {
    @EnvironmentObject var promptLibrary: PromptLibraryViewModel
    @EnvironmentObject var conversationsViewModel: ConversationsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Binding var isPresented: Bool

    @State private var search: String = ""
    @State private var showManager: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search prompts...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            Divider()

            let filtered = promptLibrary.filtered(matching: search)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !filtered.system.isEmpty {
                        sectionHeader(PromptTemplate.Kind.systemPrompt.sectionTitle)
                        ForEach(filtered.system) { prompt in
                            row(prompt) { applySystemPrompt(prompt) }
                        }
                    }
                    if !filtered.snippets.isEmpty {
                        sectionHeader(PromptTemplate.Kind.userSnippet.sectionTitle)
                        ForEach(filtered.snippets) { prompt in
                            row(prompt) { insertSnippet(prompt) }
                        }
                    }
                    if filtered.system.isEmpty && filtered.snippets.isEmpty {
                        Text("No prompts match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 360)

            Divider()

            HStack {
                Button("Manage Prompts…") {
                    showManager = true
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(8)
        }
        .frame(width: 340)
        .sheet(isPresented: $showManager) {
            PromptManagerView()
                .environmentObject(promptLibrary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func row(_ prompt: PromptTemplate, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name)
                    .font(.system(size: 13, weight: .medium))
                Text(prompt.body)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applySystemPrompt(_ prompt: PromptTemplate) {
        if conversationsViewModel.activeConversationID == nil {
            conversationsViewModel.newConversation()
        }
        if let id = conversationsViewModel.activeConversationID {
            conversationsViewModel.setSystemPrompt(for: id, to: prompt.body)
        }
        isPresented = false
    }

    private func insertSnippet(_ prompt: PromptTemplate) {
        if chatViewModel.inputText.isEmpty {
            chatViewModel.inputText = prompt.body
        } else {
            chatViewModel.inputText += "\n\n\(prompt.body)"
        }
        isPresented = false
    }
}
