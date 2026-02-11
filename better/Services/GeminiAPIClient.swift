import Foundation
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "GeminiAPIClient")

struct MessagePayload: Sendable {
    let role: String
    let text: String
    let mediaData: Data?
    let mediaMimeType: String?
}

struct GenerationConfig: Sendable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let maxOutputTokens: Int
    let thinkingBudget: Int?
    var responseModalities: [String]? = nil
    var imageConfig: ImageConfig? = nil
}

struct ImageConfig: Encodable, Sendable {
    let aspectRatio: String?
}

struct ToolsConfig: Sendable {
    let googleSearch: Bool
    let codeExecution: Bool
    let urlContext: Bool
    let imageGeneration: Bool
    let videoGeneration: Bool
}

struct ModelInfo: Codable, Sendable {
    let name: String
    let displayName: String?
    let description: String?
    let supportedGenerationMethods: [String]?
}

struct GenerateContentResponse: Codable, Sendable {
    let candidates: [ResponseCandidate]
    let usageMetadata: UsageMetadata?
}

struct ResponseCandidate: Codable, Sendable {
    let content: ResponseContent?
    let finishReason: String?
}

struct ResponseContent: Codable, Sendable {
    let parts: [ResponsePart]?
    let role: String?
}

struct ResponsePart: Codable, Sendable {
    let text: String?
    let inlineData: ResponseInlineData?
    let thought: Bool?
    let functionCall: FunctionCallResponse?
}

struct FunctionCallResponse: Codable, Sendable {
    let name: String
    let args: [String: String]?
}

struct ResponseInlineData: Codable, Sendable {
    let mimeType: String
    let data: String
}

struct UsageMetadata: Codable, Sendable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let cachedContentTokenCount: Int?
}

enum GeminiAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError
    case invalidResponse(message: String)
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key"
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let statusCode, let message):
            if let message {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP \(statusCode)"
        case .decodingError:
            return "Unable to decode response"
        case .invalidResponse(let message):
            return message
        case .requestFailed(let error):
            return error.localizedDescription
        }
    }
}

final class GeminiAPIClient {
    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/")

    func generateContent(
        messages: [MessagePayload],
        config: GenerationConfig,
        tools: ToolsConfig?,
        systemInstruction: String?,
        model: String
    ) async throws -> GenerateContentResponse {
        let apiKey = try requireAPIKey()
        let requestBody = buildRequestBody(messages: messages, config: config, tools: tools, systemInstruction: systemInstruction)
        let endpoint = "models/\(model):generateContent?key=\(apiKey)"

        var request = try makeRequest(endpoint: endpoint, method: "POST")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            return try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        } catch let error as GeminiAPIError {
            throw error
        } catch let error as DecodingError {
            throw GeminiAPIError.decodingError
        } catch {
            throw GeminiAPIError.requestFailed(error)
        }
    }

    func streamContent(
        messages: [MessagePayload],
        config: GenerationConfig,
        tools: ToolsConfig?,
        systemInstruction: String?,
        model: String
    ) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    let apiKey = try requireAPIKey()
                    let requestBody = buildRequestBody(messages: messages, config: config, tools: tools, systemInstruction: systemInstruction)
                    let endpoint = "models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"

                    var request = try makeRequest(endpoint: endpoint, method: "POST")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        let errorData = await readAllBytes(bytes)
                        let message = parseAPIErrorMessage(from: errorData)
                        continuation.yield(.error("HTTP \(http.statusCode): \(message ?? "Unknown error")"))
                        continuation.finish()
                        return
                    }

                    for await event in GeminiStreamParser.parse(bytes) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch let error as GeminiAPIError {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    func listModels() async throws -> [ModelInfo] {
        let apiKey = try requireAPIKey()
        let endpoint = "models?key=\(apiKey)"
        let request = try makeRequest(endpoint: endpoint, method: "GET")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            let result = try JSONDecoder().decode(ListModelsResponse.self, from: data)
            return result.models
        } catch let error as GeminiAPIError {
            throw error
        } catch let error as DecodingError {
            throw GeminiAPIError.decodingError
        } catch {
            throw GeminiAPIError.requestFailed(error)
        }
    }

    /// Summary of a message for intent classification context.
    struct MessageSummary: Sendable {
        let role: String
        let hasGeneratedImage: Bool
        let hasGeneratedVideo: Bool
        let textPreview: String
    }

    /// Fast intent classification using Flash to determine whether the user wants
    /// image or video generation. Returns (wantsImage, wantsVideo). Uses minimal
    /// tokens and the cheapest model for speed.
    ///
    /// - Parameters:
    ///   - userMessage: The current user message to classify
    ///   - hasAttachment: Whether the user attached media to this message
    ///   - conversationContext: Summary of recent messages for context-aware iteration
    func classifyMediaIntent(
        userMessage: String,
        hasAttachment: Bool,
        conversationContext: [MessageSummary] = []
    ) async -> (wantsImage: Bool, wantsVideo: Bool) {
        do {
            let apiKey = try requireAPIKey()

            let attachmentContext = hasAttachment
                ? " The user has also attached media (image or PDF) with this message."
                : ""

            // Build conversation context summary for the AI
            var contextSection = ""
            if !conversationContext.isEmpty {
                let contextLines = conversationContext.enumerated().map { index, msg in
                    var desc = "[\(msg.role)]"
                    if msg.hasGeneratedImage { desc += " [generated image]" }
                    if msg.hasGeneratedVideo { desc += " [generated video]" }
                    desc += " \(msg.textPreview)"
                    return "\(index + 1). \(desc)"
                }
                contextSection = """
                
                Recent conversation context:
                \(contextLines.joined(separator: "\n"))
                
                """
            }

            let classificationPrompt = """
            Classify the user's intent. Does this message request generating an image or video?
            \(contextSection)
            Rules:
            - "image": true if the user wants a NEW image created/generated/drawn/designed
            - "image": true if the user wants to MODIFY/ITERATE on a previously generated image (e.g., "make it brighter", "add a sunset", "change the background")
            - "video": true if the user wants a NEW video created/generated/animated
            - "video": true if the user wants to MODIFY/ITERATE on a previously generated video
            - "video": true if the user wants to turn/convert a previously generated IMAGE into a video or animation
            - Asking questions ABOUT images/videos is NOT generation intent
            - Analyzing or describing an existing attached image is NOT generation intent
            - "Turn this into a video", "animate this", "make it move" referring to a previous image IS video intent

            User message: "\(userMessage)"\(attachmentContext)

            Respond with ONLY valid JSON, no markdown: {"image": bool, "video": bool}
            """

            let payload: [String: Any] = [
                "contents": [["parts": [["text": classificationPrompt]]]],
                "generationConfig": [
                    "temperature": 0,
                    "maxOutputTokens": 20
                ]
            ]

            let model = Constants.Models.flash
            let endpoint = "models/\(model):generateContent?key=\(apiKey)"
            var request = try makeRequest(endpoint: endpoint, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)

            let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
            guard let responseText = decoded.candidates.first?.content?.parts?.first?.text else {
                return (false, false)
            }

            // Parse the JSON response — strip any markdown fencing
            let cleaned = responseText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: String.Encoding.utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Bool] {
                let wantsImage = result["image"] ?? false
                let wantsVideo = result["video"] ?? false
                logger.info("AI intent classification: image=\(wantsImage), video=\(wantsVideo) for: \(userMessage)")
                return (wantsImage, wantsVideo)
            }

            return (false, false)
        } catch {
            logger.warning("Intent classification failed, falling back: \(error.localizedDescription)")
            return (false, false)
        }
    }

    func generateVideo(prompt: String, aspectRatio: String? = nil) async throws -> Data {
        let apiKey = try requireAPIKey()
        let requestBody = GenerateVideoRequest(
            instances: [GenerateVideoInstance(prompt: prompt)],
            parameters: aspectRatio.map { GenerateVideoParameters(aspectRatio: $0) }
        )
        let endpoint = "models/veo-3.1-generate-preview:predictLongRunning"

        var request = try makeRequest(endpoint: endpoint, method: "POST")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            let operation = try JSONDecoder().decode(GenerateVideoOperation.self, from: data)
            print("Video generation started: \(operation.name)")

            var status = try await fetchVideoOperationStatus(name: operation.name, apiKey: apiKey)
            if let error = status.error {
                throw GeminiAPIError.invalidResponse(
                    message: operationErrorDescription(error, operationName: status.name ?? operation.name)
                )
            }
            while status.done != true {
                try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                status = try await fetchVideoOperationStatus(name: operation.name, apiKey: apiKey)
                print("Polling video status... done: \(status.done ?? false)")
                if let error = status.error {
                    throw GeminiAPIError.invalidResponse(
                        message: operationErrorDescription(error, operationName: status.name ?? operation.name)
                    )
                }
            }

            // Check if the video was blocked by safety filters
            if let filteredReasons = status.response?.generateVideoResponse?.raiMediaFilteredReasons,
               !filteredReasons.isEmpty {
                let reason = filteredReasons.first ?? "Unknown safety filter reason"
                throw GeminiAPIError.invalidResponse(message: reason)
            }

            guard let uri = status.response?.generateVideoResponse?.generatedSamples?.first?.video?.uri else {
                let operationName = status.name ?? operation.name
                throw GeminiAPIError.invalidResponse(
                    message: "Video generation completed without a video URI. Operation: \(operationName)"
                )
            }

            print("Video URI found: \(uri)")
            print("Downloading video from URI...")
            let videoData = try await downloadVideo(from: uri)
            print("Video downloaded: \(videoData.count) bytes")
            return videoData
        } catch let error as GeminiAPIError {
            throw error
        } catch let error as DecodingError {
            print("DecodingError: \(error)")
            throw GeminiAPIError.decodingError
        } catch {
            throw GeminiAPIError.requestFailed(error)
        }
    }

    private func requireAPIKey() throws -> String {
        guard let key = KeychainService.loadAPIKey(), !key.isEmpty else {
            throw GeminiAPIError.missingAPIKey
        }
        return key
    }

    private func makeRequest(endpoint: String, method: String) throws -> URLRequest {
        guard let baseURL else {
            throw GeminiAPIError.invalidURL
        }
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw GeminiAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            throw GeminiAPIError.httpError(
                statusCode: http.statusCode,
                message: parseAPIErrorMessage(from: data)
            )
        }
    }

    private func fetchVideoOperationStatus(name: String, apiKey: String) async throws -> GenerateVideoOperationStatus {
        let endpoint = name
        var request = try makeRequest(endpoint: endpoint, method: "GET")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        // Always log raw JSON when done so we can debug response structure
        let rawJSON = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        if rawJSON.contains("\"done\": true") || rawJSON.contains("\"done\":true") {
            logger.info("Video operation completed. Raw JSON: \(rawJSON)")
        }

        do {
            return try JSONDecoder().decode(GenerateVideoOperationStatus.self, from: data)
        } catch {
            logger.error("Failed to decode video operation status. Raw JSON: \(rawJSON)")
            throw error
        }
    }

    private func downloadVideo(from uri: String) async throws -> Data {
        guard let url = URL(string: uri) else {
            throw GeminiAPIError.invalidURL
        }

        let apiKey = try requireAPIKey()
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GeminiAPIError.httpError(statusCode: http.statusCode, message: nil)
        }
        return data
    }

    private func parseAPIErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error.message
    }

    private func operationErrorDescription(
        _ error: GenerateVideoOperationError,
        operationName: String?
    ) -> String {
        var message = "Video generation failed"
        if let operationName, !operationName.isEmpty {
            message += " for operation \(operationName)"
        }

        var details: [String] = []
        if let code = error.code {
            details.append("code \(code)")
        }
        if let errorMessage = error.message, !errorMessage.isEmpty {
            details.append(errorMessage)
        }

        if details.isEmpty {
            return message + "."
        }
        return message + ": " + details.joined(separator: " - ")
    }

    private func buildRequestBody(
        messages: [MessagePayload],
        config: GenerationConfig,
        tools: ToolsConfig?,
        systemInstruction: String?
    ) -> GenerateContentRequest {
        let contents = messages.compactMap { message -> Content? in
            let parts = buildParts(from: message)
            guard !parts.isEmpty else {
                return nil
            }
            return Content(role: message.role, parts: parts)
        }

        let generationConfig = GenerationConfigBody(
            temperature: config.temperature,
            topP: config.topP,
            topK: config.topK,
            maxOutputTokens: config.maxOutputTokens,
            thinkingBudget: config.thinkingBudget,
            responseModalities: config.responseModalities,
            imageConfig: config.imageConfig
        )

        let system = systemInstruction.map { SystemInstruction(parts: [Part(text: $0, inlineData: nil)]) }
        let toolsArray = buildTools(tools)

        return GenerateContentRequest(
            contents: contents,
            generationConfig: generationConfig,
            systemInstruction: system,
            tools: toolsArray
        )
    }

    private func buildParts(from message: MessagePayload) -> [Part] {
        var parts: [Part] = []

        // Media part first per Gemini API recommendations
        if let data = message.mediaData, let mimeType = message.mediaMimeType {
            let base64 = data.base64EncodedString()
            let inline = InlineData(mimeType: mimeType, data: base64)
            parts.append(Part(text: nil, inlineData: inline))
        }

        if !message.text.isEmpty {
            parts.append(Part(text: message.text, inlineData: nil))
        }

        return parts
    }

    private func buildTools(_ tools: ToolsConfig?) -> [Tool]? {
        guard let tools else {
            return nil
        }

        var toolList: [Tool] = []
        if tools.googleSearch {
            toolList.append(Tool(googleSearch: Empty(), codeExecution: nil, urlContext: nil, functionDeclarations: nil))
        }
        if tools.codeExecution {
            toolList.append(Tool(googleSearch: nil, codeExecution: Empty(), urlContext: nil, functionDeclarations: nil))
        }
        if tools.urlContext {
            toolList.append(Tool(googleSearch: nil, codeExecution: nil, urlContext: Empty(), functionDeclarations: nil))
        }
        if tools.imageGeneration {
            let decl = FunctionDeclaration(
                name: "generate_image",
                description: "Generate an image based on a text description. Use this whenever the user asks you to create, generate, draw, paint, sketch, illustrate, or make an image, picture, photo, illustration, or artwork.",
                parameters: FunctionParameters(
                    type: "object",
                    properties: [
                        "prompt": FunctionProperty(
                            type: "string",
                            description: "A detailed, optimized prompt for image generation. Enhance the user's request with specific details about style, composition, lighting, colors, and mood to produce the best possible image."
                        )
                    ],
                    required: ["prompt"]
                )
            )
            toolList.append(Tool(googleSearch: nil, codeExecution: nil, urlContext: nil, functionDeclarations: [decl]))
        }
        if tools.videoGeneration {
            let decl = FunctionDeclaration(
                name: "generate_video",
                description: "Generate a video from a text description. Use this when the user asks you to create, generate, or make a video, clip, or animation.",
                parameters: FunctionParameters(
                    type: "object",
                    properties: [
                        "prompt": FunctionProperty(
                            type: "string",
                            description: "A detailed, optimized prompt for video generation. Enhance the user's request with specific details about camera movement, scene composition, action, lighting, and mood."
                        ),
                        "aspectRatio": FunctionProperty(
                            type: "string",
                            description: "Video aspect ratio: '16:9' for landscape or '9:16' for portrait. Default is '16:9'."
                        )
                    ],
                    required: ["prompt"]
                )
            )
            toolList.append(Tool(googleSearch: nil, codeExecution: nil, urlContext: nil, functionDeclarations: [decl]))
        }

        return toolList.isEmpty ? nil : toolList
    }

    private func readAllBytes(_ bytes: URLSession.AsyncBytes) async -> Data {
        var data = Data()
        do {
            for try await chunk in bytes {
                data.append(chunk)
            }
        } catch {
            return data
        }
        return data
    }
}

private struct GenerateContentRequest: Encodable {
    let contents: [Content]
    let generationConfig: GenerationConfigBody
    let systemInstruction: SystemInstruction?
    let tools: [Tool]?
}

private struct Content: Encodable {
    let role: String
    let parts: [Part]
}

private struct Part: Encodable {
    let text: String?
    let inlineData: InlineData?
}

private struct InlineData: Encodable {
    let mimeType: String
    let data: String
}

private struct GenerationConfigBody: Encodable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let maxOutputTokens: Int
    let thinkingBudget: Int?
    let responseModalities: [String]?
    let imageConfig: ImageConfig?
}

private struct SystemInstruction: Encodable {
    let parts: [Part]
}

private struct Empty: Encodable {}

private struct Tool: Encodable {
    let googleSearch: Empty?
    let codeExecution: Empty?
    let urlContext: Empty?
    let functionDeclarations: [FunctionDeclaration]?
}

private struct FunctionDeclaration: Encodable {
    let name: String
    let description: String
    let parameters: FunctionParameters
}

private struct FunctionParameters: Encodable {
    let type: String
    let properties: [String: FunctionProperty]
    let required: [String]
}

private struct FunctionProperty: Encodable {
    let type: String
    let description: String
}

private struct APIErrorResponse: Codable {
    let error: APIErrorBody
}

private struct APIErrorBody: Codable {
    let message: String?
}

private struct ListModelsResponse: Codable {
    let models: [ModelInfo]
}

private struct GenerateVideoRequest: Encodable {
    let instances: [GenerateVideoInstance]
    let parameters: GenerateVideoParameters?
}

private struct GenerateVideoInstance: Encodable {
    let prompt: String
}

private struct GenerateVideoParameters: Encodable {
    let aspectRatio: String?
}

private struct GenerateVideoOperation: Decodable {
    let name: String
}

private struct GenerateVideoOperationStatus: Decodable {
    let name: String?
    let done: Bool?
    let response: GenerateVideoOperationResponse?
    let error: GenerateVideoOperationError?
}

private struct GenerateVideoOperationError: Decodable {
    let code: Int?
    let message: String?
}

private struct GenerateVideoOperationResponse: Decodable {
    let generateVideoResponse: GenerateVideoResponseBody?

    private enum CodingKeys: String, CodingKey {
        case generateVideoResponse
    }
}

private struct GenerateVideoResponseBody: Decodable {
    let generatedSamples: [GenerateVideoSample]?
    let raiMediaFilteredCount: Int?
    let raiMediaFilteredReasons: [String]?
}

private struct GenerateVideoSample: Decodable {
    let video: GenerateVideoVideo?
}

private struct GenerateVideoVideo: Decodable {
    let uri: String?
}
