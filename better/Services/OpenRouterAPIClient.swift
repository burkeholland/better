import Foundation
import FirebaseAuth
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "OpenRouterAPIClient")

// MARK: - Stream Event Types

enum StreamEvent: Sendable {
    case text(String)
    case thinking(String)
    case imageData(Data, mimeType: String)
    case toolCalls([ToolCall])
    case usageMetadata(inputTokens: Int, outputTokens: Int, cachedTokens: Int?)
    case error(String)
    case done
}

// MARK: - Shared Payload Types (used by other code)

struct MessagePayload: Sendable {
    let role: String
    let text: String
    let mediaData: Data?
    let mediaMimeType: String?
    let toolCalls: [ToolCall]?
    let toolCallId: String?

    init(role: String, text: String, mediaData: Data? = nil, mediaMimeType: String? = nil, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.text = text
        self.mediaData = mediaData
        self.mediaMimeType = mediaMimeType
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

struct GenerationConfig: Sendable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let maxOutputTokens: Int
}

// MARK: - OpenRouter Response Types

struct OpenRouterResponse: Codable, Sendable {
    let id: String?
    let choices: [OpenRouterChoice]
    let usage: OpenRouterUsage?
}

struct OpenRouterChoice: Codable, Sendable {
    let index: Int
    let message: OpenRouterResponseMessage?
    let delta: OpenRouterResponseDelta?
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index
        case message
        case delta
        case finishReason = "finish_reason"
    }
}

struct OpenRouterResponseMessage: Codable, Sendable {
    let role: String?
    let content: String?
}

struct OpenRouterResponseDelta: Codable, Sendable {
    let role: String?
    let content: String?
}

struct OpenRouterUsage: Codable, Sendable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - OpenRouter Error Types

enum OpenRouterAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError
    case invalidResponse(message: String)
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenRouter API key"
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

// Alias for backward compatibility with code referencing GeminiAPIError
typealias GeminiAPIError = OpenRouterAPIError

// MARK: - OpenRouter API Client

final class OpenRouterAPIClient {
    private let baseURL = URL(string: Constants.apiProxyBaseURL)

    /// Get the current user's Firebase Auth ID token for proxy authentication
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            logger.error("No authenticated user")
            throw OpenRouterAPIError.missingAPIKey
        }
        return try await user.getIDToken()
    }

    func generateContent(
        messages: [MessagePayload],
        config: GenerationConfig,
        systemInstruction: String?,
        model: String
    ) async throws -> OpenRouterResponse {
        let apiKey = try await getAuthToken()
        let requestBody = buildRequestBody(
            messages: messages,
            config: config,
            systemInstruction: systemInstruction,
            model: model,
            stream: false
        )

        var request = try makeRequest(endpoint: "chat/completions", method: "POST")
        request.httpBody = try JSONEncoder().encode(requestBody)
        setHeaders(&request, apiKey: apiKey)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            return try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        } catch let error as OpenRouterAPIError {
            throw error
        } catch is DecodingError {
            throw OpenRouterAPIError.decodingError
        } catch {
            throw OpenRouterAPIError.requestFailed(error)
        }
    }

    func streamContent(
        messages: [MessagePayload],
        config: GenerationConfig,
        systemInstruction: String?,
        model: String,
        tools: [ToolDefinition]? = nil
    ) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    let apiKey = try await self.getAuthToken()
                    let requestBody = buildRequestBody(
                        messages: messages,
                        config: config,
                        systemInstruction: systemInstruction,
                        model: model,
                        stream: true,
                        tools: tools
                    )

                    var request = try makeRequest(endpoint: "chat/completions", method: "POST")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    setHeaders(&request, apiKey: apiKey)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    logger.info("Streaming request to: \(request.url?.absoluteString ?? "nil", privacy: .public)")
                    logger.info("Model: \(model, privacy: .public)")
                    if let tools {
                        logger.info("Tools: \(tools.count) tool definitions attached")
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let http = response as? HTTPURLResponse {
                        logger.info("Stream response: HTTP \(http.statusCode, privacy: .public)")
                    }
                    
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        let errorData = await readAllBytes(bytes)
                        let message = parseAPIErrorMessage(from: errorData)
                        continuation.yield(.error("HTTP \(http.statusCode): \(message ?? "Unknown error")"))
                        continuation.finish()
                        return
                    }

                    for await event in OpenRouterStreamParser.parse(bytes) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch let error as OpenRouterAPIError {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func makeRequest(endpoint: String, method: String) throws -> URLRequest {
        guard let baseURL else {
            throw OpenRouterAPIError.invalidURL
        }
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw OpenRouterAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func setHeaders(_ request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Tell the proxy which OpenRouter endpoint to forward to
        request.setValue("chat/completions", forHTTPHeaderField: "X-OpenRouter-Path")
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            throw OpenRouterAPIError.httpError(
                statusCode: http.statusCode,
                message: parseAPIErrorMessage(from: data)
            )
        }
    }

    private func parseAPIErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error?.message
    }

    private func buildRequestBody(
        messages: [MessagePayload],
        config: GenerationConfig,
        systemInstruction: String?,
        model: String,
        stream: Bool,
        tools: [ToolDefinition]? = nil
    ) -> OpenRouterRequest {
        var requestMessages: [OpenRouterRequestMessage] = []

        // Add system instruction if provided
        if let systemInstruction, !systemInstruction.isEmpty {
            requestMessages.append(OpenRouterRequestMessage(
                role: "system",
                content: .text(systemInstruction)
            ))
        }

        // Convert message payloads
        for message in messages {
            let requestMessage = buildRequestMessage(from: message)
            requestMessages.append(requestMessage)
        }

        let activeTools = (tools?.isEmpty == false) ? tools : nil
        return OpenRouterRequest(
            model: model,
            messages: requestMessages,
            temperature: config.temperature,
            topP: config.topP,
            maxTokens: config.maxOutputTokens,
            stream: stream,
            streamOptions: stream ? StreamOptions(includeUsage: true) : nil,
            tools: activeTools,
            toolChoice: activeTools != nil ? "auto" : nil
        )
    }

    private func buildRequestMessage(from payload: MessagePayload) -> OpenRouterRequestMessage {
        // Map Gemini-style "model" role to OpenAI-style "assistant"
        let role = payload.role == "model" ? "assistant" : payload.role

        // Tool result messages
        if role == "tool", let toolCallId = payload.toolCallId {
            return OpenRouterRequestMessage(
                role: "tool",
                content: .text(payload.text),
                toolCallId: toolCallId
            )
        }

        // Assistant messages that contain tool calls
        if let toolCalls = payload.toolCalls, !toolCalls.isEmpty {
            let requestCalls = toolCalls.map { call in
                RequestToolCall(
                    id: call.id,
                    type: "function",
                    function: RequestToolCallFunction(
                        name: call.functionName,
                        arguments: call.arguments
                    )
                )
            }
            return OpenRouterRequestMessage(
                role: "assistant",
                toolCalls: requestCalls
            )
        }

        // If there's media, use content array format
        if let mediaData = payload.mediaData, let mimeType = payload.mediaMimeType {
            var contentParts: [OpenRouterContentPart] = []

            // Add image part first
            let base64String = mediaData.base64EncodedString()
            let dataURL = "data:\(mimeType);base64,\(base64String)"
            contentParts.append(.imageURL(OpenRouterImageURL(url: dataURL)))

            // Add text part
            if !payload.text.isEmpty {
                contentParts.append(.text(payload.text))
            }

            return OpenRouterRequestMessage(
                role: role,
                content: .parts(contentParts)
            )
        }

        // Text-only message
        return OpenRouterRequestMessage(
            role: role,
            content: .text(payload.text)
        )
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

// MARK: - OpenRouter Stream Parser

enum OpenRouterStreamParser {
    static func parse<S: AsyncSequence>(_ bytes: S) -> AsyncStream<StreamEvent> where S.Element == UInt8 {
        AsyncStream { continuation in
            Task {
                var buffer = Data()
                var toolCallAccumulator: [Int: AccumulatingToolCall] = [:]

                do {
                    for try await byte in bytes {
                        if byte == 10 { // newline
                            let line = String(data: buffer, encoding: .utf8) ?? ""
                            buffer.removeAll(keepingCapacity: true)
                            handleLine(line, continuation: continuation, toolCallAccumulator: &toolCallAccumulator)
                        } else {
                            buffer.append(byte)
                        }
                    }

                    if !buffer.isEmpty {
                        let line = String(data: buffer, encoding: .utf8) ?? ""
                        handleLine(line, continuation: continuation, toolCallAccumulator: &toolCallAccumulator)
                    }
                } catch {
                    continuation.yield(.error("Stream error: \(error.localizedDescription)"))
                }

                // Emit accumulated tool calls before done
                if !toolCallAccumulator.isEmpty {
                    let calls = toolCallAccumulator.sorted { $0.key < $1.key }
                        .map { ToolCall(id: $0.value.id, functionName: $0.value.name, arguments: $0.value.arguments) }
                    logger.info("Emitting \(calls.count) tool call(s): \(calls.map(\.functionName).joined(separator: ", "), privacy: .public)")
                    continuation.yield(.toolCalls(calls))
                }

                continuation.yield(.done)
                continuation.finish()
            }
        }
    }

    private static func handleLine(_ rawLine: String, continuation: AsyncStream<StreamEvent>.Continuation, toolCallAccumulator: inout [Int: AccumulatingToolCall]) {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else {
            return
        }

        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty else {
            return
        }

        if payload == "[DONE]" {
            return
        }

        guard let data = payload.data(using: .utf8) else {
            continuation.yield(.error("Invalid UTF-8 payload"))
            return
        }

        do {
            let response = try JSONDecoder().decode(OpenRouterStreamResponse.self, from: data)
            emitEvents(from: response, continuation: continuation, toolCallAccumulator: &toolCallAccumulator)
        } catch {
            logger.debug("Failed to decode stream chunk: \(error.localizedDescription)")
        }
    }

    private static func emitEvents(from response: OpenRouterStreamResponse, continuation: AsyncStream<StreamEvent>.Continuation, toolCallAccumulator: inout [Int: AccumulatingToolCall]) {
        // Emit usage metadata if present
        if let usage = response.usage {
            let inputTokens = usage.promptTokens ?? 0
            let outputTokens = usage.completionTokens ?? 0
            continuation.yield(
                .usageMetadata(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedTokens: nil
                )
            )
        }

        guard let choice = response.choices?.first,
              let delta = choice.delta else {
            return
        }
        
        // Emit reasoning/thinking content from DeepSeek R1
        let thinkingText = delta.reasoning ?? delta.reasoningContent
        if let thinkingText, !thinkingText.isEmpty {
            continuation.yield(.thinking(thinkingText))
        }

        // Emit text content from delta
        if let content = delta.content, !content.isEmpty {
            continuation.yield(.text(content))
        }

        // Accumulate tool calls from delta
        if let toolCalls = delta.toolCalls {
            for tc in toolCalls {
                let index = tc.index ?? 0
                if toolCallAccumulator[index] == nil {
                    toolCallAccumulator[index] = AccumulatingToolCall()
                }
                if let id = tc.id {
                    toolCallAccumulator[index]!.id = id
                }
                if let name = tc.function?.name {
                    toolCallAccumulator[index]!.name = name
                }
                if let args = tc.function?.arguments {
                    toolCallAccumulator[index]!.arguments += args
                }
            }
        }
    }
}

// MARK: - OpenRouter Request Types

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [OpenRouterRequestMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool
    let streamOptions: StreamOptions?
    let tools: [ToolDefinition]?
    let toolChoice: String?

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
        case streamOptions = "stream_options"
        case tools
        case toolChoice = "tool_choice"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(topP, forKey: .topP)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(streamOptions, forKey: .streamOptions)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
    }
}

private struct StreamOptions: Encodable {
    let includeUsage: Bool

    private enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

private struct OpenRouterRequestMessage: Encodable {
    let role: String
    let content: OpenRouterMessageContent?
    let toolCalls: [RequestToolCall]?
    let toolCallId: String?

    init(role: String, content: OpenRouterMessageContent? = nil, toolCalls: [RequestToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        // OpenRouter requires "content": null (not omitted) for assistant tool-call messages
        if toolCalls != nil {
            try container.encodeNil(forKey: .content)
        } else {
            try container.encodeIfPresent(content, forKey: .content)
        }
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
    }
}

private struct RequestToolCall: Encodable {
    let id: String
    let type: String
    let function: RequestToolCallFunction
}

private struct RequestToolCallFunction: Encodable {
    let name: String
    let arguments: String
}

private enum OpenRouterMessageContent: Encodable {
    case text(String)
    case parts([OpenRouterContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

private enum OpenRouterContentPart: Encodable {
    case text(String)
    case imageURL(OpenRouterImageURL)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let imageURL):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageURL, forKey: .imageURL)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct OpenRouterImageURL: Encodable {
    let url: String
}

// MARK: - OpenRouter Stream Response Types

private struct OpenRouterStreamResponse: Codable {
    let id: String?
    let choices: [OpenRouterStreamChoice]?
    let usage: OpenRouterUsage?
}

private struct OpenRouterStreamChoice: Codable {
    let index: Int?
    let delta: OpenRouterStreamDelta?
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }
}

private struct OpenRouterStreamDelta: Codable {
    let role: String?
    let content: String?
    let reasoning: String?
    let reasoningContent: String?
    let toolCalls: [StreamToolCallDelta]?
    
    private enum CodingKeys: String, CodingKey {
        case role, content, reasoning
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }
}

private struct StreamToolCallDelta: Codable {
    let index: Int?
    let id: String?
    let type: String?
    let function: StreamFunctionDelta?
}

private struct StreamFunctionDelta: Codable {
    let name: String?
    let arguments: String?
}

/// Mutable accumulator for tool calls being streamed incrementally.
private struct AccumulatingToolCall {
    var id: String = ""
    var name: String = ""
    var arguments: String = ""
}

// MARK: - OpenRouter Error Response

private struct OpenRouterErrorResponse: Codable {
    let error: OpenRouterErrorBody?
}

private struct OpenRouterErrorBody: Codable {
    let message: String?
    let type: String?
    let code: String?
}
