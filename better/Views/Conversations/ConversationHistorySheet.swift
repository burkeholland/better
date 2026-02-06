import SwiftUI
import SwiftData

struct ConversationHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchText = ""

    let onSelect: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            List {
                let pinned = filtered.filter { $0.isPinned }
                if !pinned.isEmpty {
                    Section {
                        ForEach(pinned) { conversation in
                            Button {
                                onSelect(conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteConversation(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(Theme.coral)
                            }
                            .tint(.primary)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accentGradient)
                            Text("Pinned")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accentGradient)
                        }
                    }
                }

                let recent = filtered.filter { !$0.isPinned && !$0.isArchived }
                if !recent.isEmpty {
                    Section {
                        ForEach(recent) { conversation in
                            Button {
                                onSelect(conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteConversation(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(Theme.coral)
                            }
                            .tint(.primary)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Theme.accentGradient)
                            Text("Recent")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accentGradient)
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
                    .foregroundStyle(Theme.lavender)
                }
            }
            .overlay {
                if conversations.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(Theme.accentGradient)
                            Text("No Conversations Yet")
                                .font(.headline)
                        }
                    } description: {
                        Text("Your chat history will appear here")
                    }
                }
            }
        }
        .tint(Theme.lavender)
    }

    private var filtered: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
        Haptics.light()
    }
}
