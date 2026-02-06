import SwiftUI
import SwiftData

@Observable
final class ConversationListViewModel {
    var searchText: String = ""
    var selectedConversation: Conversation?

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createConversation() -> Conversation {
        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        selectedConversation = conversation
        Haptics.light()
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        modelContext.delete(conversation)
        try? modelContext.save()
        Haptics.medium()
    }

    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        try? modelContext.save()
    }

    func archiveConversation(_ conversation: Conversation) {
        conversation.isArchived = true
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        try? modelContext.save()
    }
}
