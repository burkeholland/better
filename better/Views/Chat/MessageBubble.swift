import SwiftUI
import UIKit
import AVKit
import Photos

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MessageBubble: View {
    let message: Message
    let isStreaming: Bool
    let branchInfo: (current: Int, total: Int)
    let onRegenerate: () -> Void
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
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
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
            if !didAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    didAppear = true
                }
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
        VStack(alignment: .leading, spacing: 8) {
            messageContent
                .foregroundStyle(Theme.charcoal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.messagePaddingHorizontal)
        .padding(.vertical, 4)
    }

    var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isStreaming && message.content.isEmpty {
                ThinkingView()
            }

            if let urlString = message.mediaURL {
                if message.mediaMimeType == "video/mp4", let url = URL(string: urlString) {
                    VideoBubble(videoURL: url, messageId: message.id)
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
                } else if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture {
                                    if let img = loadedImage {
                                        selectedImage = IdentifiableImage(image: img)
                                    }
                                }
                        case .failure:
                            Label("Image failed to load", systemImage: "photo")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                    }
                    .task {
                        if loadedImage == nil {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                await MainActor.run { loadedImage = UIImage(data: data) }
                            } catch { }
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

            if let input = message.inputTokens, let output = message.outputTokens {
                tokenCounts(input: input, output: output, cached: message.cachedTokens)
            }
        }
        .fullScreenCover(item: $selectedImage) { item in
            ImageViewer(image: item.image)
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

    func tokenCounts(input: Int, output: Int, cached: Int?) -> some View {
        let cachedText = cached.map { " · \($0) cached" } ?? ""
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Theme.mint).frame(width: 6, height: 6)
                Circle().fill(Theme.lavender).frame(width: 6, height: 6)
                Circle().fill(Theme.peach).frame(width: 6, height: 6)
            }

            Text("\(input) in · \(output) out\(cachedText)")
                .font(.caption2)
                .foregroundStyle(Theme.charcoal.opacity(0.6))
        }
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
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        showingSaveSuccess = true
                    }
                } else {
                    saveErrorMessage = error?.localizedDescription ?? "Failed to save video"
                    showingSaveError = true
                }
                // Only clean up temp files, not original local files
                if !fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                    // Skip removal — it's the original file
                } else {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
}
