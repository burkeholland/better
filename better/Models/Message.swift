import Foundation
import SwiftData

@Model
final class Message {
    #Unique<Message>([\.id])

    var id: UUID
    var role: String  // "user" or "model"
    var content: String
    var createdAt: Date
    var selectedAt: Date?
    var parentId: UUID?  // For branching - references another Message's id

    var conversation: Conversation?

    // Image data (inline)
    @Attribute(.externalStorage)
    var imageData: Data?
    var imageMimeType: String?

    // Token counts
    var inputTokens: Int?
    var outputTokens: Int?
    var cachedTokens: Int?

    // Thinking content (for thinking models)
    var thinkingContent: String?

    // Is this message currently being streamed?
    @Transient
    var isStreaming: Bool = false

    init(
        role: String,
        content: String,
        parentId: UUID? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.parentId = parentId
    }

    /// Whether this message is from the user
    var isUser: Bool { role == "user" }

    /// Whether this message has an image attachment
    var hasImage: Bool { imageData != nil }
}
