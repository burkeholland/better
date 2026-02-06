import Foundation

enum StreamEvent: Sendable {
    case text(String)
    case thinking(String)
    case imageData(Data, mimeType: String)
    case usageMetadata(inputTokens: Int, outputTokens: Int, cachedTokens: Int?)
    case error(String)
    case done
}

enum GeminiStreamParser {
    static func parse<S: AsyncSequence>(_ bytes: S) -> AsyncStream<StreamEvent> where S.Element == UInt8 {
        AsyncStream { continuation in
            Task {
                var buffer = Data()

                do {
                    for try await byte in bytes {
                        if byte == 10 {
                            let line = String(data: buffer, encoding: .utf8) ?? ""
                            buffer.removeAll(keepingCapacity: true)
                            handleLine(line, continuation: continuation)
                        } else {
                            buffer.append(byte)
                        }
                    }

                    if !buffer.isEmpty {
                        let line = String(data: buffer, encoding: .utf8) ?? ""
                        handleLine(line, continuation: continuation)
                    }
                } catch {
                    continuation.yield(.error("Stream error: \(error.localizedDescription)"))
                }

                continuation.finish()
            }
        }
    }

    private static func handleLine(_ rawLine: String, continuation: AsyncStream<StreamEvent>.Continuation) {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else {
            return
        }

        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty else {
            return
        }

        if payload == "[DONE]" {
            continuation.yield(.done)
            return
        }

        guard let data = payload.data(using: .utf8) else {
            continuation.yield(.error("Invalid UTF-8 payload"))
            return
        }

        do {
            let response = try JSONDecoder().decode(StreamResponse.self, from: data)
            emitEvents(from: response, continuation: continuation)
        } catch {
            continuation.yield(.error("Decode error: \(error.localizedDescription)"))
        }
    }

    private static func emitEvents(from response: StreamResponse, continuation: AsyncStream<StreamEvent>.Continuation) {
        if let usage = response.usageMetadata {
            let inputTokens = usage.promptTokenCount ?? 0
            let outputTokens = usage.candidatesTokenCount ?? 0
            continuation.yield(
                .usageMetadata(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cachedTokens: usage.cachedContentTokenCount
                )
            )
        }

        guard let candidate = response.candidates?.first,
              let parts = candidate.content?.parts
        else {
            return
        }

        for part in parts {
            if part.thought == true, let text = part.text {
                continuation.yield(.thinking(text))
                continue
            }

            if let text = part.text {
                continuation.yield(.text(text))
            }

            if let inlineData = part.inlineData {
                if let imageData = Data(base64Encoded: inlineData.data) {
                    continuation.yield(.imageData(imageData, mimeType: inlineData.mimeType))
                } else {
                    continuation.yield(.error("Invalid base64 image data"))
                }
            }
        }
    }
}

private struct StreamResponse: Codable {
    let candidates: [StreamCandidate]?
    let usageMetadata: StreamUsageMetadata?
}

private struct StreamCandidate: Codable {
    let content: StreamContent?
    let finishReason: String?
}

private struct StreamContent: Codable {
    let parts: [StreamPart]?
    let role: String?
}

private struct StreamPart: Codable {
    let text: String?
    let inlineData: StreamInlineData?
    let thought: Bool?
}

private struct StreamInlineData: Codable {
    let mimeType: String
    let data: String
}

private struct StreamUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let cachedContentTokenCount: Int?
}
