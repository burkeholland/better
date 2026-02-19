import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.postrboard.better", category: "PhotoAttachmentPicker")

struct PickedImage {
    let data: Data
    let mimeTypeHint: String?
}

struct PhotoAttachmentPicker: UIViewControllerRepresentable {
    let onComplete: (Result<PickedImage, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: (Result<PickedImage, Error>) -> Void

        init(onComplete: @escaping (Result<PickedImage, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }
            Task {
                do {
                    let picked = try await Self.loadImage(from: result)
                    await MainActor.run { self.onComplete(.success(picked)) }
                } catch {
                    await MainActor.run { self.onComplete(.failure(error)) }
                }
            }
        }

        private static func loadImage(from result: PHPickerResult) async throws -> PickedImage {
            let provider = result.itemProvider
            var lastError: Error?

            // Strategy 1 & 2: Try NSItemProvider file and data representations
            for typeIdentifier in candidateImageTypeIdentifiers(from: provider) {
                guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }

                do {
                    if let fileData = try await loadFileData(provider: provider, typeIdentifier: typeIdentifier) {
                        logger.debug("Loaded via file representation (\(typeIdentifier, privacy: .public))")
                        return PickedImage(
                            data: fileData,
                            mimeTypeHint: resolveMimeType(from: provider, preferredTypeIdentifier: typeIdentifier)
                        )
                    }
                } catch {
                    lastError = error
                    logger.debug("File representation failed for \(typeIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }

                do {
                    if let rawData = try await loadRawData(provider: provider, typeIdentifier: typeIdentifier) {
                        logger.debug("Loaded via data representation (\(typeIdentifier, privacy: .public))")
                        return PickedImage(
                            data: rawData,
                            mimeTypeHint: resolveMimeType(from: provider, preferredTypeIdentifier: typeIdentifier)
                        )
                    }
                } catch {
                    lastError = error
                    logger.debug("Data representation failed for \(typeIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            // Strategy 3: UIImage fallback
            if provider.canLoadObject(ofClass: UIImage.self) {
                do {
                    if let image = try await loadUIImage(provider: provider),
                       let jpegData = image.jpegData(compressionQuality: 0.9) {
                        logger.debug("Loaded via UIImage fallback")
                        return PickedImage(data: jpegData, mimeTypeHint: "image/jpeg")
                    }
                } catch {
                    lastError = error
                    logger.debug("UIImage fallback failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            // Strategy 4 & 5: PHAsset fallback via Photos framework
            if let assetId = result.assetIdentifier {
                // Strategy 4: Request original image data (handles iCloud download on real devices)
                do {
                    let picked = try await loadViaPHAsset(identifier: assetId)
                    logger.debug("Loaded via PHAsset original data fallback")
                    return picked
                } catch {
                    lastError = error
                    logger.debug("PHAsset original data failed: \(error.localizedDescription, privacy: .public)")
                }

                // Strategy 5: Request rendered image at max size (works with locally cached previews)
                do {
                    let picked = try await loadViaPHAssetImage(identifier: assetId)
                    logger.debug("Loaded via PHAsset rendered image fallback")
                    return picked
                } catch {
                    lastError = error
                    logger.debug("PHAsset rendered image failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            throw imageLoadError(underlying: lastError)
        }

        // MARK: - PHAsset Fallback

        private static func loadViaPHAsset(identifier: String) async throws -> PickedImage {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else {
                throw NSError(
                    domain: "PhotoAttachmentPicker",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Photo library access is required to load this image. Please grant access in Settings."]
                )
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                throw NSError(
                    domain: "PhotoAttachmentPicker",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find the selected photo in your library."]
                )
            }

            return try await withCheckedThrowingContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false

                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data else {
                        continuation.resume(throwing: NSError(
                            domain: "PhotoAttachmentPicker",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "Could not load image data from Photos library."]
                        ))
                        return
                    }
                    var mimeType: String? = nil
                    if let uti, let utType = UTType(uti) {
                        mimeType = utType.preferredMIMEType
                    }
                    continuation.resume(returning: PickedImage(data: data, mimeTypeHint: mimeType))
                }
            }
        }

        private static func loadViaPHAssetImage(identifier: String) async throws -> PickedImage {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else {
                throw NSError(
                    domain: "PhotoAttachmentPicker",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Photo library access is required to load this image. Please grant access in Settings."]
                )
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                throw NSError(
                    domain: "PhotoAttachmentPicker",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find the selected photo in your library."]
                )
            }

            // Request a large rendered image — works even with only locally cached thumbnails
            let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            return try await withCheckedThrowingContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = false // Use only locally available data
                options.deliveryMode = .opportunistic
                options.resizeMode = .none
                options.isSynchronous = false

                var resumed = false
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                    // requestImage may call back multiple times (degraded then full); take the first usable one
                    guard !resumed else { return }
                    
                    if let error = info?[PHImageErrorKey] as? Error {
                        resumed = true
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let image, let jpegData = image.jpegData(compressionQuality: 0.9) else {
                        // If degraded, wait for the next callback
                        let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                        if !isDegraded {
                            resumed = true
                            continuation.resume(throwing: NSError(
                                domain: "PhotoAttachmentPicker",
                                code: 5,
                                userInfo: [NSLocalizedDescriptionKey: "Could not render image from Photos library."]
                            ))
                        }
                        return
                    }

                    resumed = true
                    continuation.resume(returning: PickedImage(data: jpegData, mimeTypeHint: "image/jpeg"))
                }
            }
        }

        // MARK: - NSItemProvider Helpers

        private static func candidateImageTypeIdentifiers(from provider: NSItemProvider) -> [String] {
            var identifiers: [String] = []

            for identifier in provider.registeredTypeIdentifiers {
                guard let type = UTType(identifier), type.conforms(to: .image) else { continue }
                if identifier != UTType.image.identifier, !identifiers.contains(identifier) {
                    identifiers.append(identifier)
                }
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                identifiers.append(UTType.image.identifier)
            }

            return identifiers
        }

        private static func imageLoadError(underlying: Error?) -> NSError {
            let baseDescription = "Could not load selected image."

            guard let nsError = underlying as NSError? else {
                return NSError(
                    domain: "PhotoAttachmentPicker",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: baseDescription]
                )
            }

            let description: String
            switch nsError.domain {
            case "CloudPhotoLibraryErrorDomain", "PHAssetExportRequestErrorDomain":
                description = "\(baseDescription) This photo appears to be iCloud-only; download it in Photos and try again."
            case NSItemProvider.errorDomain:
                description = "\(baseDescription) Try another photo or attach it from Files."
            default:
                description = baseDescription
            }

            return NSError(
                domain: "PhotoAttachmentPicker",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: description,
                    NSUnderlyingErrorKey: nsError
                ]
            )
        }

        private static func loadFileData(provider: NSItemProvider, typeIdentifier: String) async throws -> Data? {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    do {
                        let data = try Data(contentsOf: url)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        private static func loadRawData(provider: NSItemProvider, typeIdentifier: String) async throws -> Data? {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }
        }

        private static func loadUIImage(provider: NSItemProvider) async throws -> UIImage? {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: object as? UIImage)
                    }
                }
            }
        }

        private static func resolveMimeType(from provider: NSItemProvider, preferredTypeIdentifier: String? = nil) -> String? {
            if let preferredTypeIdentifier,
               let preferredType = UTType(preferredTypeIdentifier),
               let mime = preferredType.preferredMIMEType,
               mime.hasPrefix("image/") {
                return mime
            }

            for identifier in provider.registeredTypeIdentifiers {
                guard let utType = UTType(identifier),
                      let mime = utType.preferredMIMEType,
                      mime.hasPrefix("image/") else {
                    continue
                }
                return mime
            }
            return nil
        }
    }
}
