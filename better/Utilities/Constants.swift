import Foundation

enum Constants {
    // Firebase Functions v2 proxy URL — update after deploying
    // Use emulator URL for local dev: http://127.0.0.1:5001/{project}/us-central1/api
    static let apiProxyBaseURL = "https://us-central1-better-38cdf.cloudfunctions.net/api/"

    enum Models {
        // Text models
        static let geminiFlash = "google/gemini-2.5-flash"
        static let deepseekR1 = "deepseek/deepseek-r1"
        
        // Vision model (used automatically when images are attached)
        static let qwenVision = "qwen/qwen2.5-vl-32b-instruct"
        
        // Legacy aliases
        static let deepseekChat = geminiFlash
        static let deepseek = geminiFlash
        static let kimiK25 = deepseekR1
        
        // Image generation models
        static let seedream = "bytedance-seed/seedream-4.5"
        
        // Video models
        static let seedance = "bytedance/seedance-2.0"
        
        // Default
        static let defaultModel = geminiFlash
        
        // All available text models for picker
        static let allTextModels: [(id: String, name: String, description: String)] = [
            (geminiFlash, "Gemini 2.5 Flash", "Fast - $0.30/$2.50 per M tokens"),
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
