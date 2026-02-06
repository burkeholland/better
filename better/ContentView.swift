import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var currentConversation: Conversation?
    @State private var chatViewModel: ChatViewModel?
    @State private var showSideMenu = false
    @State private var showChatSettings = false

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if let chatVM = chatViewModel {
                        ChatView(viewModel: chatVM, showChatSettings: $showChatSettings)
                    } else {
                        ProgressView()
                            .tint(Theme.mint)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showSideMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title3)
                                .gradientIcon()
                        }
                        .accessibilityLabel("Menu")
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            createNewConversation()
                        } label: {
                            Image(systemName: "plus.message")
                                .font(.title3)
                                .gradientIcon()
                        }
                        .accessibilityLabel("New Chat")
                    }
                }
            }
            .tint(Theme.lavender)

            SideMenuView(
                isOpen: $showSideMenu,
                onSelect: { conversation in
                    switchToConversation(conversation)
                },
                onSettings: {
                    appState.showSettings = true
                },
                onChatSettings: {
                    showChatSettings = true
                }
            )
            .zIndex(1)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let isEdgeSwipe = value.startLocation.x < 24
                    let swipedRight = value.translation.width > 60
                    let swipedLeft = value.translation.width < -60

                    if !showSideMenu && isEdgeSwipe && swipedRight {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showSideMenu = true
                        }
                    } else if showSideMenu && swipedLeft {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showSideMenu = false
                        }
                    }
                }
        )
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
        // Clean up current conversation if it has no messages
        if let current = currentConversation, current.messages.isEmpty, current.modelContext != nil {
            modelContext.delete(current)
            try? modelContext.save()
        }
        let conversation = Conversation()
        switchToConversation(conversation)
        Haptics.light()
    }

    private func switchToConversation(_ conversation: Conversation) {
        currentConversation = conversation
        chatViewModel = ChatViewModel(conversation: conversation, modelContext: modelContext)
    }
}
