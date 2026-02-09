import Foundation
import FirebaseStorage

enum MediaServiceError: LocalizedError {
    case invalidURL(String)
    case downloadFailed(statusCode: Int)
    case fileTooLarge(bytes: Int, limit: Int)
    case storageDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid media URL: \(url)"
        case .downloadFailed(let code):
            return "Download failed with status \(code)"
        case .fileTooLarge(let bytes, let limit):
            let sizeMB = Double(bytes) / 1_048_576
            let limitMB = Double(limit) / 1_048_576
            return String(format: "File is %.1f MB, limit is %.0f MB", sizeMB, limitMB)
        case .storageDownloadFailed(let message):
            return "Storage download failed: \(message)"
        }
    }
}

@MainActor @Observable
final class MediaService {
    static let shared = MediaService()

    /// In-memory cache of downloaded media bytes, keyed by storage path or URL.
    private var cache: [String: Data] = [:]
    private let storage = Storage.storage()

    private init() {}

    /// Pre-cache media data (e.g. right after uploading, to avoid re-downloading).
    func cacheMedia(data: Data, for key: String) {
        cache[key] = data
    }

    /// Download media by storage path or URL.
    /// Storage paths (e.g. "media/user/conv/msg.png") use the Firebase Storage SDK.
    /// HTTP(S) URLs use URLSession.
    /// Returns cached data if previously downloaded.
    func downloadMedia(from pathOrURL: String, maxBytes: Int = MediaLimits.maxImageBytes) async throws -> Data {
        if let cached = cache[pathOrURL] {
            return cached
        }

        let data: Data

        if pathOrURL.hasPrefix("http://") || pathOrURL.hasPrefix("https://") || pathOrURL.hasPrefix("data:") {
            // HTTP URL — use URLSession
            guard let url = URL(string: pathOrURL) else {
                throw MediaServiceError.invalidURL(pathOrURL)
            }
            let (downloaded, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw MediaServiceError.downloadFailed(statusCode: httpResponse.statusCode)
            }
            data = downloaded
        } else {
            // Firebase Storage path — use Storage SDK directly
            let ref = storage.reference().child(pathOrURL)
            do {
                data = try await ref.data(maxSize: Int64(maxBytes))
            } catch {
                throw MediaServiceError.storageDownloadFailed(error.localizedDescription)
            }
        }

        guard data.count <= maxBytes else {
            throw MediaServiceError.fileTooLarge(bytes: data.count, limit: maxBytes)
        }

        cache[pathOrURL] = data
        return data
    }

    /// Clear the download cache.
    func clearCache() {
        cache.removeAll()
    }
}
