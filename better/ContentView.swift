import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppState.self) private var appState

    @State private var conversationListVM: ConversationListViewModel?
    @State private var currentConversation: Conversation?
    @State private var chatViewModel: ChatViewModel?
    @State private var showSideMenu = false
    @State private var showChatSettings = false

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
                    .tint(Theme.mint)
            } else if !authService.isSignedIn {
                LoginView()
            } else {
                mainContent
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn, let userId = authService.userId {
                conversationListVM = ConversationListViewModel(userId: userId)
                createNewConversation()
            } else {
                conversationListVM = nil
                currentConversation = nil
                chatViewModel = nil
            }
        }
    }

    private var mainContent: some View {
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

            if let vm = conversationListVM {
                SideMenuView(
                    conversationListVM: vm,
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
        guard let vm = conversationListVM else { return }
        let conversation = vm.createConversation()
        switchToConversation(conversation)
    }

    private func switchToConversation(_ conversation: Conversation) {
        guard let userId = authService.userId else { return }
        currentConversation = conversation
        chatViewModel = ChatViewModel(conversation: conversation, userId: userId)
    }
}
