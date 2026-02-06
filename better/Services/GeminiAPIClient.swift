import Foundation

struct MessagePayload: Sendable {
    let role: String
    let text: String
    let imageData: Data?
    let imageMimeType: String?
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

    private func parseAPIErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error.message
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

        if !message.text.isEmpty {
            parts.append(Part(text: message.text, inlineData: nil))
        }

        if let data = message.imageData, let mimeType = message.imageMimeType {
            let base64 = data.base64EncodedString()
            let inline = InlineData(mimeType: mimeType, data: base64)
            parts.append(Part(text: nil, inlineData: inline))
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
