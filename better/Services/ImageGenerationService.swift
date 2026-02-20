import Foundation
import FirebaseAuth
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "ImageGenerationService")

enum ImageGenerationError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case noImageInResponse
    case invalidImageData
    case requestFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing API key"
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Unknown error")"
        case .noImageInResponse: return "No image returned from API"
        case .invalidImageData: return "Invalid image data"
        case .requestFailed(let error): return error.localizedDescription
        }
    }
}

final class ImageGenerationService {
    private let baseURL = URL(string: Constants.apiProxyBaseURL)
    
    /// Generate an image using Seedream 4.5 via chat/completions endpoint
    /// Returns the image data and mime type
    func generateImage(prompt: String) async throws -> (data: Data, mimeType: String) {
        guard let user = Auth.auth().currentUser else {
            throw ImageGenerationError.missingAPIKey
        }
        let authToken = try await user.getIDToken()
        
        // Use chat/completions endpoint (NOT /images/generations - that doesn't exist on OpenRouter)
        guard let url = URL(string: "chat/completions", relativeTo: baseURL) else {
            throw ImageGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("chat/completions", forHTTPHeaderField: "X-OpenRouter-Path")
        
        // Seedream 4.5 image generation via chat completions
        // Must include modality: ["image"] to get image output
        let body: [String: Any] = [
            "model": Constants.Models.seedream,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "modality": ["image"],  // Required for image output
            "max_tokens": 1024
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        logger.info("Generating image with Seedream 4.5: \(prompt)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            logger.info("Image generation response: HTTP \(http.statusCode)")
            if http.statusCode >= 400 {
                let message = parseErrorMessage(from: data)
                let rawResponse = String(data: data, encoding: .utf8) ?? "non-utf8"
                logger.error("Image generation failed: HTTP \(http.statusCode) - \(message ?? rawResponse)")
                throw ImageGenerationError.httpError(statusCode: http.statusCode, message: message)
            }
        }
        
        // Parse response - image is in choices[0].message.content as base64 data URL
        // or in choices[0].message.images array
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-utf8"
            logger.error("Failed to parse image response: \(rawResponse.prefix(500))")
            throw ImageGenerationError.noImageInResponse
        }
        
        // Try to get image from "images" array first (OpenRouter style)
        if let images = message["images"] as? [[String: Any]],
           let firstImage = images.first,
           let imageUrlObj = firstImage["image_url"] as? [String: Any],
           let dataUrl = imageUrlObj["url"] as? String {
            return try parseDataUrl(dataUrl)
        }
        
        // Fall back to content field (might contain data URL or markdown)
        if let content = message["content"] as? String {
            // Check if content is a data URL
            if content.hasPrefix("data:image/") {
                return try parseDataUrl(content)
            }
            
            // Check if it's embedded in markdown ![image](data:...)
            if let range = content.range(of: "data:image/"),
               let endRange = content.range(of: ")", range: range.upperBound..<content.endIndex) {
                let dataUrl = String(content[range.lowerBound..<endRange.lowerBound])
                return try parseDataUrl(dataUrl)
            }
            
            logger.warning("Unexpected content format: \(content.prefix(200))")
        }
        
        throw ImageGenerationError.noImageInResponse
    }
    
    private func parseDataUrl(_ dataUrl: String) throws -> (data: Data, mimeType: String) {
        // Parse data URL like "data:image/png;base64,iVBOR..."
        let parts = dataUrl.components(separatedBy: ";base64,")
        guard parts.count == 2 else {
            throw ImageGenerationError.invalidImageData
        }
        
        let mimeType = String(parts[0].dropFirst(5)) // Remove "data:"
        guard let imageData = Data(base64Encoded: parts[1]) else {
            throw ImageGenerationError.invalidImageData
        }
        
        logger.info("Image parsed successfully: \(imageData.count) bytes, type: \(mimeType)")
        return (imageData, mimeType)
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}
