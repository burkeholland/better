import Foundation

struct Conversation: Codable, Identifiable, Equatable, Hashable {
    var id: String
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

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        modelName: String = Constants.Models.defaultModel,
        temperature: Double = 1.0,
        topP: Double = 0.95,
        topK: Int = 40,
        maxOutputTokens: Int = 8192
    ) {
        self.id = id
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
    }
}
