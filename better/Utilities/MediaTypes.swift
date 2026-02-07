import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - Supported MIME Types

enum SupportedMediaType: String, CaseIterable {
    // Images
    case png = "image/png"
    case jpeg = "image/jpeg"
    case webp = "image/webp"
    case heic = "image/heic"
    case heif = "image/heif"

    // Documents
    case pdf = "application/pdf"

    var isImage: Bool { rawValue.hasPrefix("image/") }
    var isPDF: Bool { self == .pdf }
}

// MARK: - Media Validation

enum MediaLimits {
    /// ~15 MB for images (leaves headroom for base64 overhead)
    static let maxImageBytes = 15 * 1024 * 1024
    /// ~10 MB for PDFs (leaves headroom for base64 overhead)
    static let maxPDFBytes = 10 * 1024 * 1024

    static func maxBytes(for mimeType: String) -> Int {
        if mimeType == SupportedMediaType.pdf.rawValue {
            return maxPDFBytes
        }
        return maxImageBytes
    }
}

enum MediaTypeError: LocalizedError {
    case unsupportedType(String)
    case fileTooLarge(bytes: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let mime):
            return "Unsupported file type: \(mime)"
        case .fileTooLarge(let bytes, let limit):
            let sizeMB = Double(bytes) / 1_048_576
            let limitMB = Double(limit) / 1_048_576
            return String(format: "File is %.1f MB, limit is %.0f MB", sizeMB, limitMB)
        }
    }
}

// MARK: - Helpers

enum MediaTypes {
    /// All MIME strings the app accepts for Gemini uploads.
    static let allowedMIMETypes: Set<String> = Set(SupportedMediaType.allCases.map(\.rawValue))

    /// Convert a `UTType` to its preferred MIME string, if available.
    static func mimeType(from utType: UTType) -> String? {
        utType.preferredMIMEType
    }

    /// Returns true if the MIME string is in the allowlist.
    static func isSupported(_ mimeType: String) -> Bool {
        allowedMIMETypes.contains(mimeType)
    }

    /// Validate MIME type and data size; throws on failure.
    static func validate(mimeType: String, dataSize: Int) throws {
        guard isSupported(mimeType) else {
            throw MediaTypeError.unsupportedType(mimeType)
        }
        let limit = MediaLimits.maxBytes(for: mimeType)
        guard dataSize <= limit else {
            throw MediaTypeError.fileTooLarge(bytes: dataSize, limit: limit)
        }
    }
}

// MARK: - PendingAttachment

struct PendingAttachment: Identifiable, Equatable {
    let id = UUID().uuidString
    let data: Data
    let mimeType: String
    let preview: UIImage?   // non-nil for images
    let filename: String?   // non-nil for PDFs

    static func == (lhs: PendingAttachment, rhs: PendingAttachment) -> Bool {
        lhs.id == rhs.id
    }
}
