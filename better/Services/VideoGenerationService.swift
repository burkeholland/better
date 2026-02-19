import Foundation
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "VideoGenerationService")

enum VideoGenerationError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case jobFailed(message: String)
    case timeout
    case noVideoInResponse
    case requestFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing API key"
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Unknown error")"
        case .jobFailed(let msg): return "Video generation failed: \(msg)"
        case .timeout: return "Video generation timed out"
        case .noVideoInResponse: return "No video returned from API"
        case .requestFailed(let error): return error.localizedDescription
        }
    }
}

enum VideoGenerationStatus: Sendable {
    case pending
    case processing(progress: Double?)
    case completed(videoData: Data)
    case failed(error: String)
}

final class VideoGenerationService {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/")
    
    /// Generate a video using Seedance 2.0
    /// This is a long-running operation (1-10 minutes)
    /// Returns an AsyncStream of status updates
    func generateVideo(
        prompt: String,
        duration: Int = 10,
        resolution: String = "1080p"
    ) -> AsyncStream<VideoGenerationStatus> {
        AsyncStream { continuation in
            Task {
                do {
                    guard let apiKey = KeychainService.loadAPIKey(), !apiKey.isEmpty else {
                        continuation.yield(.failed(error: "Missing API key"))
                        continuation.finish()
                        return
                    }
                    
                    continuation.yield(.pending)
                    
                    // Submit the video generation job
                    let jobId = try await submitVideoJob(
                        prompt: prompt,
                        duration: duration,
                        resolution: resolution,
                        apiKey: apiKey
                    )
                    
                    logger.info("Video job submitted: \(jobId)")
                    continuation.yield(.processing(progress: 0.1))
                    
                    // Poll for completion (max 15 minutes)
                    let maxAttempts = 90  // 15 min at 10s intervals
                    var attempts = 0
                    
                    while attempts < maxAttempts {
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                        attempts += 1
                        
                        let status = try await checkJobStatus(jobId: jobId, apiKey: apiKey)
                        
                        switch status {
                        case .processing(let progress):
                            continuation.yield(.processing(progress: progress))
                        case .completed(let data):
                            logger.info("Video generated: \(data.count) bytes")
                            continuation.yield(.completed(videoData: data))
                            continuation.finish()
                            return
                        case .failed(let error):
                            continuation.yield(.failed(error: error))
                            continuation.finish()
                            return
                        case .pending:
                            continuation.yield(.processing(progress: Double(attempts) / Double(maxAttempts)))
                        }
                    }
                    
                    // Timeout
                    continuation.yield(.failed(error: "Video generation timed out after 15 minutes"))
                    continuation.finish()
                    
                } catch {
                    logger.error("Video generation failed: \(error.localizedDescription)")
                    continuation.yield(.failed(error: error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }
    
    private func submitVideoJob(
        prompt: String,
        duration: Int,
        resolution: String,
        apiKey: String
    ) async throws -> String {
        guard let url = URL(string: "chat/completions", relativeTo: baseURL) else {
            throw VideoGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://better.postrboard.com", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Better", forHTTPHeaderField: "X-Title")
        
        // Seedance video generation request
        let body: [String: Any] = [
            "model": Constants.Models.seedance,
            "messages": [
                [
                    "role": "user",
                    "content": "Generate a \(duration) second video at \(resolution): \(prompt)"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        logger.info("Submitting video job: \(prompt)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = parseErrorMessage(from: data)
            throw VideoGenerationError.httpError(statusCode: http.statusCode, message: message)
        }
        
        // Parse job ID from response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jobId = json["id"] as? String else {
            // For some models, video data might come directly in response
            if let videoData = try? extractVideoFromResponse(data) {
                // Store temporarily and return a fake job ID
                // This handles sync video responses
                throw VideoGenerationError.noVideoInResponse
            }
            throw VideoGenerationError.noVideoInResponse
        }
        
        return jobId
    }
    
    private func checkJobStatus(jobId: String, apiKey: String) async throws -> VideoGenerationStatus {
        // For OpenRouter, we may need to poll a different endpoint
        // This depends on how Seedance exposes job status
        // For now, assume the video comes in the initial response or we need to
        // implement provider-specific polling
        
        guard let url = URL(string: "jobs/\(jobId)", relativeTo: baseURL) else {
            throw VideoGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 {
                // Job not found - might still be processing
                return .processing(progress: nil)
            }
            if http.statusCode >= 400 {
                let message = parseErrorMessage(from: data)
                return .failed(error: message ?? "Unknown error")
            }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .processing(progress: nil)
        }
        
        if let status = json["status"] as? String {
            switch status.lowercased() {
            case "completed", "done", "success":
                if let videoURL = json["video_url"] as? String {
                    let videoData = try await downloadVideo(from: videoURL, apiKey: apiKey)
                    return .completed(videoData: videoData)
                }
                return .failed(error: "No video URL in completed job")
            case "failed", "error":
                let error = json["error"] as? String ?? "Unknown error"
                return .failed(error: error)
            case "processing", "running", "pending":
                let progress = json["progress"] as? Double
                return .processing(progress: progress)
            default:
                return .processing(progress: nil)
            }
        }
        
        return .processing(progress: nil)
    }
    
    private func downloadVideo(from urlString: String, apiKey: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw VideoGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw VideoGenerationError.httpError(statusCode: http.statusCode, message: nil)
        }
        
        return data
    }
    
    private func extractVideoFromResponse(_ data: Data) throws -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VideoGenerationError.noVideoInResponse
        }
        
        // Try to extract video URL or base64 from content
        if content.hasPrefix("data:video/") {
            let parts = content.components(separatedBy: ";base64,")
            if parts.count == 2, let decoded = Data(base64Encoded: parts[1]) {
                return decoded
            }
        }
        
        throw VideoGenerationError.noVideoInResponse
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
