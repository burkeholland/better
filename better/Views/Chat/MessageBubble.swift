import SwiftUI
import UIKit
import AVKit
import Photos

/// Shared image cache that survives LazyVStack view recycling.
private final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct MessageBubble: View {
    let message: Message
    let isStreaming: Bool
    let generationStatus: String
    let branchInfo: (current: Int, total: Int)
    let isLastInBranch: Bool
    let onRegenerate: () -> Void
    let onFork: () -> Void
    let onEdit: (String) -> Void
    let onDeleteSingle: () -> Void
    let onDelete: () -> Void
    let onBranchSwitch: (Int) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var showStreamingCursor = false
    @State private var didAppear = false
    @State private var selectedImage: IdentifiableImage?
    @State private var loadedImage: UIImage?
    @State private var imageLoadFailed = false
    @State private var localVideoURL: URL?
    @State private var videoLoadFailed = false
    @State private var selectedPDF: IdentifiableURL?
    @State private var copied = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            if branchInfo.total > 1 {
                BranchNavigator(
                    current: branchInfo.current,
                    total: branchInfo.total,
                    onSwitch: onBranchSwitch
                )
            }

            if isEditing {
                editView
            } else {
                messageRow
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.isUser {
                Button {
                    editText = message.content
                    isEditing = true
                } label: {
                    Label("Edit & Resend", systemImage: "square.and.pencil")
                }
            }

            if !message.isUser {
                Button {
                    onFork()
                } label: {
                    Label("Fork", systemImage: "arrow.triangle.branch")
                }

                if isLastInBranch {
                    Button {
                        onRegenerate()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            Button(role: .destructive) {
                onDeleteSingle()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete from here", systemImage: "trash.slash")
            }
        }
        .onAppear {
            if editText.isEmpty {
                editText = message.content
            }
            if !didAppear && !isStreaming {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    didAppear = true
                }
            } else {
                didAppear = true
            }
            if isStreaming {
                startStreamingAnimation()
            }
        }
        .onChange(of: isStreaming) { _, streaming in
            if streaming {
                startStreamingAnimation()
            } else {
                showStreamingCursor = false
            }
        }
    }
}

private extension MessageBubble {
    static func decodeDataURI(_ uri: String) -> UIImage? {
        // Expected format: data:<mimeType>;base64,<data>
        guard let commaIndex = uri.firstIndex(of: ",") else { return nil }
        let base64String = String(uri[uri.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }

    var messageRow: some View {
        Group {
            if message.isUser {
                userMessage
            } else {
                assistantMessage
            }
        }
        .scaleEffect(didAppear ? 1.0 : 0.95)
        .opacity(didAppear ? 1.0 : 0.0)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    var userMessage: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 40)

            messageContent
                .padding(.horizontal, Theme.messagePaddingHorizontal)
                .padding(.vertical, Theme.messagePaddingVertical)
                .background(Theme.lavender.opacity(0.15))
                .foregroundStyle(Theme.charcoal)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleRadius, style: .continuous))
                .frame(maxWidth: userBubbleMaxWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, Theme.messagePaddingHorizontal)
    }

    var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            messageContent
                .foregroundStyle(Theme.charcoal)

            if !isStreaming && !message.content.isEmpty {
                actionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.messagePaddingHorizontal)
        .padding(.vertical, 4)
    }

    var actionBar: some View {
        HStack(spacing: 16) {
            Button {
                onFork()
            } label: {
                Label("Fork", systemImage: "arrow.triangle.branch")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Theme.charcoal.opacity(0.4))

            if isLastInBranch {
                Button {
                    onRegenerate()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                }
                .foregroundStyle(Theme.charcoal.opacity(0.4))
            }

            Button {
                handleCopy()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                    if copied {
                        Text("Copied!")
                            .font(.caption2)
                            .transition(.opacity)
                    }
                }
            }
            .foregroundStyle(copied ? Theme.mint : Theme.charcoal.opacity(0.4))
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
        .padding(.top, 2)
    }

    private func handleCopy() {
        UIPasteboard.general.string = message.content
        Haptics.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }

    var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isStreaming && message.content.isEmpty {
                ThinkingView(label: generationStatus)
            }

            if let urlString = message.mediaURL {
                if message.isPDF, let url = URL(string: urlString) {
                    pdfCard(url: url)
                } else if message.mediaMimeType == "video/mp4" {
                    // Video: handle both direct URLs and Firebase Storage paths
                    if let url = URL(string: urlString), urlString.hasPrefix("http") || urlString.hasPrefix("file://") {
                        VideoBubble(videoURL: url, messageId: message.id)
                    } else if let localURL = localVideoURL {
                        VideoBubble(videoURL: localURL, messageId: message.id)
                    } else if videoLoadFailed {
                        Label("Video failed to load", systemImage: "video.slash")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView("Loading video…")
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .task {
                                do {
                                    let data = try await MediaService.shared.downloadMedia(
                                        from: urlString,
                                        maxBytes: 100_000_000
                                    )
                                    let tempURL = FileManager.default.temporaryDirectory
                                        .appendingPathComponent("\(message.id).mp4")
                                    try data.write(to: tempURL)
                                    localVideoURL = tempURL
                                } catch {
                                    videoLoadFailed = true
                                }
                            }
                    }
                } else if urlString.hasPrefix("file://"),
                          let fileURL = URL(string: urlString),
                          let uiImage = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            selectedImage = IdentifiableImage(image: uiImage)
                        }
                } else if urlString.hasPrefix("data:"), let uiImage = Self.decodeDataURI(urlString) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            selectedImage = IdentifiableImage(image: uiImage)
                        }
                } else if let url = URL(string: urlString), urlString.hasPrefix("http") {
                    Group {
                        if let loadedImage {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture {
                                    selectedImage = IdentifiableImage(image: loadedImage)
                                }
                        } else if imageLoadFailed {
                            Label("Image failed to load", systemImage: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                    }
                    .task {
                        guard loadedImage == nil else { return }
                        if let cached = ImageCache.shared.image(forKey: urlString) {
                            loadedImage = cached
                            return
                        }
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let image = UIImage(data: data) {
                                ImageCache.shared.setImage(image, forKey: urlString)
                                loadedImage = image
                            } else {
                                imageLoadFailed = true
                            }
                        } catch {
                            imageLoadFailed = true
                        }
                    }
                } else {
                    // Firebase Storage path or other — use MediaService
                    Group {
                        if let loadedImage {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture {
                                    selectedImage = IdentifiableImage(image: loadedImage)
                                }
                        } else if imageLoadFailed {
                            Label("Image failed to load", systemImage: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                    }
                    .task {
                        guard loadedImage == nil else { return }
                        if let cached = ImageCache.shared.image(forKey: urlString) {
                            loadedImage = cached
                            return
                        }
                        do {
                            let data = try await MediaService.shared.downloadMedia(from: urlString)
                            if let image = UIImage(data: data) {
                                ImageCache.shared.setImage(image, forKey: urlString)
                                loadedImage = image
                            } else {
                                imageLoadFailed = true
                            }
                        } catch {
                            imageLoadFailed = true
                        }
                    }
                }
            }

            if !message.content.isEmpty {
                if message.isUser {
                    Text(message.content)
                        .textSelection(.enabled)
                } else {
                    MarkdownRenderer(text: message.content)
                }
            }

            if isStreaming && !message.content.isEmpty {
                streamingCursor
            }
        }
        .fullScreenCover(item: $selectedImage) { item in
            ImageViewer(image: item.image)
        }
        .fullScreenCover(item: $selectedPDF) { item in
            PDFViewer(url: item.url)
        }
    }

    var streamingCursor: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.accentGradient)
            .frame(width: 3, height: 18)
            .opacity(showStreamingCursor ? 1.0 : 0.25)
            .scaleEffect(x: 1.0, y: showStreamingCursor ? 1.0 : 0.7, anchor: .center)
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: showStreamingCursor)
    }

    func pdfCard(url: URL) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 30))
                .gradientIcon()
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white))
                .shadow(color: Theme.bubbleShadowColor, radius: 2, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.charcoal)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text("PDF Document")
                    .font(.caption)
                    .foregroundStyle(Theme.charcoal.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            selectedPDF = IdentifiableURL(url: url)
        }
        .frame(maxWidth: 300)
    }

    var editView: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $editText)
                .frame(minHeight: 80, maxHeight: 220)
                .padding(10)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.lilac.opacity(0.5), lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                .foregroundStyle(Theme.charcoal)

                Spacer()

                Button {
                    onEdit(editText)
                    isEditing = false
                } label: {
                    Text("Send")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Theme.mint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.cream.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    var userBubbleMaxWidth: CGFloat {
        UIScreen.main.bounds.width * 0.8
    }

    func startStreamingAnimation() {
        showStreamingCursor = true
    }
}

struct VideoBubble: View {
    let videoURL: URL
    let messageId: String

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showFullScreen = false

    @State private var showingShareSheet = false
    @State private var showingSaveSuccess = false
    @State private var saveErrorMessage: String?
    @State private var showingSaveError = false

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .onReceive(player.publisher(for: \.timeControlStatus)) { status in
                        isPlaying = status == .playing
                    }
            } else {
                ZStack {
                    Color.black.opacity(0.1)
                    ProgressView()
                }
                .frame(height: 300)
            }

            if !isPlaying {
                ZStack {
                    Color.black.opacity(0.2)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                showFullScreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(8)
            .shadow(radius: 2)
        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: showFullScreen) { _, isShowing in
            if !isShowing {
                setupPlayer()
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }

                VStack {
                    HStack {
                        Button {
                            showFullScreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()

                        Spacer()
                    }

                    Spacer()

                    HStack(spacing: 30) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            actionButton(icon: "square.and.arrow.up", text: "Share")
                        }

                        Button {
                            saveToPhotos()
                        } label: {
                            actionButton(icon: "square.and.arrow.down", text: "Save")
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [videoURL])
            }
            .overlay {
                if showingSaveSuccess {
                    saveSuccessView
                }
            }
            .alert("Save Error", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Unknown error")
            }
        }
    }

    private func setupPlayer() {
        guard player == nil else { return }
        player = AVPlayer(url: videoURL)
    }

    private func actionButton(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.white)
        .frame(width: 60)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveSuccessView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.mint)
            Text("Saved to Photos")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveSuccess = false
                }
            }
        }
    }

    private func saveToPhotos() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(messageId).mp4")

        Task {
            do {
                let saveURL: URL
                if videoURL.isFileURL {
                    // Local file — use it directly, no download needed
                    saveURL = videoURL
                } else {
                    // Remote URL — download to temp file first
                    let (data, _) = try await URLSession.shared.data(from: videoURL)
                    try data.write(to: tempURL)
                    saveURL = tempURL
                }

                let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                switch status {
                case .authorized, .limited:
                    performSave(fileURL: saveURL)
                case .notDetermined:
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                    if newStatus == .authorized || newStatus == .limited {
                        performSave(fileURL: saveURL)
                    } else {
                        await MainActor.run {
                            saveErrorMessage = "Please enable photo library access in Settings to save videos."
                            showingSaveError = true
                        }
                    }
                default:
                    await MainActor.run {
                        saveErrorMessage = "Please enable photo library access in Settings to save videos."
                        showingSaveError = true
                    }
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.localizedDescription
                    showingSaveError = true
                }
            }
        }
    }

    private func performSave(fileURL: URL) {
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                }
                withAnimation {
                    showingSaveSuccess = true
                }
            } catch {
                saveErrorMessage = error.localizedDescription
                showingSaveError = true
            }
            // Clean up temp files only
            if fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
