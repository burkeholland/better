import Foundation

enum Constants {
    static let openRouterBaseURL = "https://openrouter.ai/api/v1/"
    static let keychainServiceName = "com.postrboard.better"
    static let keychainAPIKeyAccount = "openrouter-api-key"

    enum Models {
        // Text models
        static let deepseekChat = "deepseek/deepseek-chat"
        static let deepseekR1 = "deepseek/deepseek-r1"
        
        // Vision model (used automatically when images are attached)
        static let qwenVision = "qwen/qwen2.5-vl-32b-instruct"
        
        // Legacy aliases
        static let kimiK25 = deepseekR1
        static let deepseek = deepseekChat
        
        // Image generation models
        static let seedream = "bytedance-seed/seedream-4.5"
        
        // Video models
        static let seedance = "bytedance/seedance-2.0"
        
        // Default
        static let defaultModel = deepseekChat
        
        // All available text models for picker
        static let allTextModels: [(id: String, name: String, description: String)] = [
            (deepseekChat, "DeepSeek V3.2", "Fast - $0.28/$0.42 per M tokens"),
            (deepseekR1, "DeepSeek R1", "Thoughtful - $0.55/$2.19 per M tokens")
        ]
    }

    enum Defaults {
        static let temperature: Double = 1.0
        static let topP: Double = 0.95
        static let topK: Int = 40
        static let maxOutputTokens: Int = 8192
    }

    enum Firestore {
        static let usersCollection = "users"
        static let conversationsCollection = "conversations"
        static let messagesCollection = "messages"
        static let mediaStoragePath = "media"
    }
}
