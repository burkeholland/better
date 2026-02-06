import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var currentConversation: Conversation?
    @State private var chatViewModel: ChatViewModel?
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if let chatVM = chatViewModel {
                    ChatView(viewModel: chatVM)
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.counterclockwise")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewConversation()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            ConversationHistorySheet(
                onSelect: { conversation in
                    switchToConversation(conversation)
                    showHistory = false
                }
            )
        }
        .sheet(isPresented: Bindable(appState).showSettings) {
            SettingsView()
        }
        .onAppear {
            if !appState.hasAPIKey {
                appState.showSettings = true
            }
            if currentConversation == nil {
                createNewConversation()
            }
        }
    }

    private func createNewConversation() {
        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        switchToConversation(conversation)
        Haptics.light()
    }

    private func switchToConversation(_ conversation: Conversation) {
        currentConversation = conversation
        chatViewModel = ChatViewModel(conversation: conversation, modelContext: modelContext)
    }
}
