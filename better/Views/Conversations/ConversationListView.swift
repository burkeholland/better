import SwiftUI

struct ConversationListView: View {
    @Bindable var viewModel: ConversationListViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: $viewModel.selectedConversation) {
            let pinned = viewModel.pinnedConversations
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteConversation(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    viewModel.togglePin(conversation)
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            let unpinned = viewModel.recentConversations
            Section("Recent") {
                ForEach(unpinned) { conversation in
                    ConversationRow(conversation: conversation)
                        .tag(conversation)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                viewModel.togglePin(conversation)
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.orange)

                            Button {
                                viewModel.archiveConversation(conversation)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search conversations")
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let _ = viewModel.createConversation()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    appState.showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .overlay {
            if viewModel.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left",
                    description: Text("Tap + to start a new chat")
                )
            }
        }
    }
}
