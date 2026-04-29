import SwiftUI

struct ContentView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @EnvironmentObject var conversationsViewModel: ConversationsViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .frame(minWidth: 240)
        } detail: {
            ChatView()
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            Task {
                await modelsViewModel.fetchModels()
                modelsViewModel.loadSavedModel()
                applyConversationModelIfPresent()
            }
        }
        .onChange(of: conversationsViewModel.activeConversationID) {
            applyConversationModelIfPresent()
        }
    }

    /// When the active chat already has a `modelID`, prefer that over the global "last selected" model
    /// so each conversation remembers what it was last used with.
    private func applyConversationModelIfPresent() {
        guard let modelID = conversationsViewModel.activeConversation?.modelID,
              let model = modelsViewModel.models.first(where: { $0.id == modelID }) else { return }
        modelsViewModel.selectedModel = model
    }
}
