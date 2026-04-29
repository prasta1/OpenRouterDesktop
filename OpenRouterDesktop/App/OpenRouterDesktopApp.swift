import SwiftUI

@main
struct OpenRouterDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var modelsViewModel = ModelsViewModel()
    @StateObject private var conversationsViewModel = ConversationsViewModel()
    @StateObject private var promptLibraryViewModel = PromptLibraryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatViewModel)
                .environmentObject(modelsViewModel)
                .environmentObject(conversationsViewModel)
                .environmentObject(promptLibraryViewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    conversationsViewModel.newConversation()
                }
                .keyboardShortcut("N", modifiers: [.command])
                Button("New Folder") {
                    conversationsViewModel.newFolder()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button("Clear Active Chat") {
                    conversationsViewModel.clearActiveMessages()
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])
            }
            CommandMenu("Chat") {
                Button("Previous Chat") {
                    conversationsViewModel.selectAdjacentChat(direction: -1)
                }
                .keyboardShortcut("[", modifiers: [.command])

                Button("Next Chat") {
                    conversationsViewModel.selectAdjacentChat(direction: 1)
                }
                .keyboardShortcut("]", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(modelsViewModel)
        }
    }
}
