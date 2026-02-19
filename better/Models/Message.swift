import Foundation

struct Message: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var role: String  // "user" or "model"
    var content: String
    var createdAt: Date
    var selectedAt: Date?
    var parentId: String?  // For branching - references another Message's id

    // Media (Firebase Storage URL)
    var mediaURL: String?
    var mediaMimeType: String?

    // Token counts
    var inputTokens: Int?
    var outputTokens: Int?
    var cachedTokens: Int?

    // Video generation cost (estimated from duration)
    var videoCost: Double?

    // Thinking content (for thinking models)
    var thinkingContent: String?

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        parentId: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.parentId = parentId
    }

    /// Whether this message is from the user
    var isUser: Bool { role == "user" }

    /// Whether this message has an image attachment
    var hasImage: Bool { mediaMimeType?.hasPrefix("image/") == true }

    /// Whether this message has a PDF attachment
    var isPDF: Bool { mediaMimeType == "application/pdf" }

    /// Whether this message has any media attachment
    var hasMedia: Bool { mediaURL != nil }
}
