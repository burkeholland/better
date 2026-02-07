import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ConversationListViewModel {
    var conversations: [Conversation] = []
    var searchText: String = ""
    var selectedConversation: Conversation?

    private let firestoreService = FirestoreService()
    nonisolated(unsafe) private var listener: ListenerRegistration?
    private let userId: String

    init(userId: String) {
        self.userId = userId
        listener = firestoreService.listenToConversations(userId: userId) { [weak self] conversations in
            Task { @MainActor [weak self] in
                self?.conversations = conversations
            }
        }
    }

    deinit {
        listener?.remove()
    }

    func createConversation() -> Conversation {
        let conversation = Conversation()
        // Don't write to Firestore yet — ChatViewModel.send() creates
        // the doc on first message, avoiding empty conversations.
        selectedConversation = conversation
        Haptics.light()
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        Task {
            try? await firestoreService.deleteConversation(conversation.id, userId: userId)
        }
        Haptics.medium()
    }

    func togglePin(_ conversation: Conversation) {
        var updated = conversation
        updated.isPinned.toggle()
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = updated
        }
        Task {
            try? await firestoreService.updateConversation(updated, userId: userId)
        }
    }

    func archiveConversation(_ conversation: Conversation) {
        var updated = conversation
        updated.isArchived = true
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        Task {
            try? await firestoreService.updateConversation(updated, userId: userId)
        }
    }

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var pinnedConversations: [Conversation] {
        filteredConversations.filter { $0.isPinned }
    }

    var recentConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned && !$0.isArchived }
    }
}
