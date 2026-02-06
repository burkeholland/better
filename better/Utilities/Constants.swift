import Foundation

enum Constants {
    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/"
    static let keychainServiceName = "com.postrboard.better"
    static let keychainAPIKeyAccount = "gemini-api-key"

    enum Models {
        static let flash = "gemini-flash-latest"
        static let pro = "gemini-pro-latest"
        static let flashImage = "gemini-2.5-flash-image"
        static let proImage = "gemini-3-pro-image-preview"
        static let defaultModel = flash
    }

    enum Defaults {
        static let temperature: Double = 1.0
        static let topP: Double = 0.95
        static let topK: Int = 40
        static let maxOutputTokens: Int = 8192
    }
}
