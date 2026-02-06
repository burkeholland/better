import Foundation
import SwiftData

@Model
final class Conversation {
    #Unique<Conversation>([\.id])

    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isArchived: Bool
    var systemInstruction: String?
    var modelName: String

    // Generation parameters
    var temperature: Double
    var topP: Double
    var topK: Int
    var maxOutputTokens: Int
    var thinkingBudget: Int?

    // Tools
    var googleSearchEnabled: Bool
    var codeExecutionEnabled: Bool
    var urlContextEnabled: Bool

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(
        title: String = "New Chat",
        modelName: String = "gemini-2.5-flash",
        temperature: Double = 1.0,
        topP: Double = 0.95,
        topK: Int = 40,
        maxOutputTokens: Int = 8192
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.isArchived = false
        self.modelName = modelName
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxOutputTokens = maxOutputTokens
        self.googleSearchEnabled = false
        self.codeExecutionEnabled = false
        self.urlContextEnabled = false
        self.messages = []
    }

    /// Returns the active branch of messages (from root to the most recent leaf on the active path)
    var activeBranch: [Message] {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [] }

        // Find root messages (no parent)
        let roots = sorted.filter { $0.parentId == nil }
        guard let root = roots.last else { return [] }

        // Walk the active branch: for each message, pick the latest child
        var branch: [Message] = [root]
        var current = root

        while true {
            let children = sorted.filter { $0.parentId == current.id }
            guard let latest = children.last else { break }
            branch.append(latest)
            current = latest
        }

        return branch
    }

    /// Returns sibling messages for a given message (messages with the same parentId)
    func siblings(of message: Message) -> [Message] {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        return sorted.filter { $0.parentId == message.parentId && $0.role == message.role }
    }
}
