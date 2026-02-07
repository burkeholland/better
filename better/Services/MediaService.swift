import Foundation

enum MediaServiceError: LocalizedError {
    case invalidURL(String)
    case downloadFailed(statusCode: Int)
    case fileTooLarge(bytes: Int, limit: Int)

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
        }
    }
}

@MainActor @Observable
final class MediaService {
    static let shared = MediaService()

    /// In-memory cache of downloaded media bytes, keyed by URL string.
    private var cache: [String: Data] = [:]

    private init() {}

    /// Download media from a URL with a size guard.
    /// Returns cached data if previously downloaded.
    func downloadMedia(from urlString: String, maxBytes: Int = MediaLimits.maxImageBytes) async throws -> Data {
        if let cached = cache[urlString] {
            return cached
        }

        guard let url = URL(string: urlString) else {
            throw MediaServiceError.invalidURL(urlString)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw MediaServiceError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        guard data.count <= maxBytes else {
            throw MediaServiceError.fileTooLarge(bytes: data.count, limit: maxBytes)
        }

        cache[urlString] = data
        return data
    }

    /// Clear the download cache.
    func clearCache() {
        cache.removeAll()
    }
}
