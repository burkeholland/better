import SwiftUI
import SwiftData

struct ConversationHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchText = ""

    let onSelect: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            List {
                let pinned = filtered.filter { $0.isPinned }
                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { conversation in
                            Button {
                                onSelect(conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .tint(.primary)
                        }
                    }
                }

                let recent = filtered.filter { !$0.isPinned && !$0.isArchived }
                if !recent.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { conversation in
                            Button {
                                onSelect(conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations Yet",
                        systemImage: "bubble.left",
                        description: Text("Your chat history will appear here")
                    )
                }
            }
        }
    }

    private var filtered: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}
