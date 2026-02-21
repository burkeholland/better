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

    // Media generation toggles
    var imageGenerationEnabled: Bool
    var videoGenerationEnabled: Bool
    
    // Models that have been removed — remap to default
    private static let deprecatedModels: Set<String> = [
        "deepseek/deepseek-chat",
        "moonshotai/kimi-k2.5",
        "meta-llama/llama-4-maverick:free",
        "gemini-flash-latest",
        "gemini-pro-latest",
        "gemini-2.5-flash-image",
        "gemini-3-pro-image-preview",
        "veo-3.1-generate-preview"
    ]

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
        self.imageGenerationEnabled = false
        self.videoGenerationEnabled = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        systemInstruction = try container.decodeIfPresent(String.self, forKey: .systemInstruction)
        let raw = try container.decode(String.self, forKey: .modelName)
        modelName = Self.deprecatedModels.contains(raw) ? Constants.Models.defaultModel : raw
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 1.0
        topP = try container.decodeIfPresent(Double.self, forKey: .topP) ?? 0.95
        topK = try container.decodeIfPresent(Int.self, forKey: .topK) ?? 40
        maxOutputTokens = try container.decodeIfPresent(Int.self, forKey: .maxOutputTokens) ?? 8192
        imageGenerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .imageGenerationEnabled) ?? false
        videoGenerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .videoGenerationEnabled) ?? false
    }
}
