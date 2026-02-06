import Foundation

enum Constants {
    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/"
    static let keychainServiceName = "com.postrboard.better"
    static let keychainAPIKeyAccount = "gemini-api-key"

    enum Models {
        static let all: [(id: String, name: String, description: String)] = [
            ("gemini-2.5-pro", "Gemini 2.5 Pro", "Advanced thinking"),
            ("gemini-2.5-flash", "Gemini 2.5 Flash", "Best price-performance"),
            ("gemini-2.5-flash-lite", "Gemini 2.5 Flash Lite", "Fastest & cheapest"),
            ("gemini-2.5-flash-preview-image-generation", "Gemini Image Gen", "Image generation"),
        ]

        static let defaultModel = "gemini-2.5-flash"
    }

    enum Defaults {
        static let temperature: Double = 1.0
        static let topP: Double = 0.95
        static let topK: Int = 40
        static let maxOutputTokens: Int = 8192
    }
}
