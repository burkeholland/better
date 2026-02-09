import SwiftUI
import PhotosUI
import FirebaseFirestore
import AVFoundation
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "ChatViewModel")

@MainActor
@Observable
final class ChatViewModel {
    var conversation: Conversation
    var messageText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    var streamingMessage: Message?
    var messages: [Message] = []
    var pendingAttachment: PendingAttachment?

    private let apiClient = GeminiAPIClient()
    private let firestoreService = FirestoreService()
    private let mediaService = MediaService.shared
    private let userId: String
    private var streamTask: Task<Void, Never>?
    nonisolated(unsafe) private var messagesListener: ListenerRegistration?

    init(conversation: Conversation, userId: String) {
        self.conversation = conversation
        self.userId = userId

        messagesListener = firestoreService.listenToMessages(
            conversationId: conversation.id,
            userId: userId
        ) { [weak self] messages in
            Task { @MainActor [weak self] in
                self?.messages = messages
            }
        }
    }

    deinit {
        messagesListener?.remove()
    }

    // MARK: - Tree Logic

    var activeBranch: [Message] {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [] }
        let roots = sorted.filter { $0.parentId == nil }
        guard let root = roots.last else { return [] }
        var branch: [Message] = [root]
        var current = root
        while true {
            let children = sorted.filter { $0.parentId == current.id }
            guard let latest = children.max(by: { a, b in
                (a.selectedAt ?? a.createdAt) < (b.selectedAt ?? b.createdAt)
            }) else { break }
            branch.append(latest)
            current = latest
        }
        return branch
    }

    func siblings(of message: Message) -> [Message] {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        return sorted.filter { $0.parentId == message.parentId && $0.role == message.role }
    }

    // MARK: - Display

    var displayMessages: [Message] {
        var branch = activeBranch
        if let streaming = streamingMessage {
            branch.append(streaming)
        }
        return branch
    }

    var isProMode: Bool {
        get { conversation.modelName == Constants.Models.pro }
        set {
            conversation.modelName = newValue ? Constants.Models.pro : Constants.Models.flash
            Task { try? await firestoreService.updateConversation(conversation, userId: userId) }
        }
    }

    // MARK: - Token Usage

    var totalInputTokens: Int {
        let persisted = messages.filter { $0.role == "model" }.compactMap(\.inputTokens).reduce(0, +)
        let streaming = streamingMessage?.inputTokens ?? 0
        return persisted + streaming
    }

    var totalOutputTokens: Int {
        let persisted = messages.filter { $0.role == "model" }.compactMap(\.outputTokens).reduce(0, +)
        let streaming = streamingMessage?.outputTokens ?? 0
        return persisted + streaming
    }

    var totalCachedTokens: Int {
        let persisted = messages.filter { $0.role == "model" }.compactMap(\.cachedTokens).reduce(0, +)
        let streaming = streamingMessage?.cachedTokens ?? 0
        return persisted + streaming
    }

    var totalVideoCost: Double {
        let persisted = messages.filter { $0.role == "model" }.compactMap(\.videoCost).reduce(0, +)
        let streaming = streamingMessage?.videoCost ?? 0
        return persisted + streaming
    }

    var hasTokenData: Bool {
        totalInputTokens > 0 || totalOutputTokens > 0 || totalVideoCost > 0
    }

    /// Estimated cost in USD based on current Gemini pricing.
    var estimatedCost: Double {
        let isProModel = conversation.modelName.contains("pro")

        // Gemini 2.5 pricing per token (as of 2025)
        let inputRate: Double  = isProModel ? 1.25  / 1_000_000 : 0.15  / 1_000_000
        let outputRate: Double = isProModel ? 10.0  / 1_000_000 : 0.60  / 1_000_000
        let cachedRate: Double = isProModel ? 0.315 / 1_000_000 : 0.037 / 1_000_000

        let cached = totalCachedTokens
        let nonCachedInput = max(0, totalInputTokens - cached)

        return Double(nonCachedInput) * inputRate
             + Double(totalOutputTokens) * outputRate
             + Double(cached) * cachedRate
             + totalVideoCost
    }

    func persistConversation() async {
        try? await firestoreService.updateConversation(conversation, userId: userId)
    }

    // MARK: - Attachments

    func attachImage(item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Could not load selected image."
                return
            }

            // Determine MIME type from the supported content types
            let mimeType: String
            if let contentType = item.supportedContentTypes.first,
               let mime = MediaTypes.mimeType(from: contentType) {
                mimeType = mime
            } else {
                mimeType = "image/jpeg"
            }

            try MediaTypes.validate(mimeType: mimeType, dataSize: data.count)

            let preview = UIImage(data: data)
            pendingAttachment = PendingAttachment(
                data: data,
                mimeType: mimeType,
                preview: preview,
                filename: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachPDF(url: URL) async {
        errorMessage = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = SupportedMediaType.pdf.rawValue
            try MediaTypes.validate(mimeType: mimeType, dataSize: data.count)

            pendingAttachment = PendingAttachment(
                data: data,
                mimeType: mimeType,
                preview: nil,
                filename: url.lastPathComponent
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePendingAttachment() {
        pendingAttachment = nil
    }

    // MARK: - Send

    func send(text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingAttachment != nil else { return }

        isGenerating = true
        errorMessage = nil

        let parentId = activeBranch.last?.id
        var userMessage = Message(role: "user", content: text, parentId: parentId)

        // Handle pending attachment upload
        let attachment = pendingAttachment
        if let attachment {
            do {
                let storagePath = try await firestoreService.uploadMedia(
                    data: attachment.data,
                    mimeType: attachment.mimeType,
                    userId: userId,
                    conversationId: conversation.id,
                    messageId: userMessage.id
                )
                userMessage.mediaURL = storagePath
                userMessage.mediaMimeType = attachment.mimeType
                // Cache locally so buildPayloads doesn't need to re-download
                mediaService.cacheMedia(data: attachment.data, for: storagePath)
            } catch {
                errorMessage = error.localizedDescription
                isGenerating = false
                return  // Keep pendingAttachment so user can retry
            }
        }

        let isNew = messages.isEmpty

        if conversation.title == "New Chat" {
            if text.isEmpty, let attachment {
                conversation.title = attachment.mimeType.hasPrefix("image/")
                    ? "Image"
                    : "PDF: \(attachment.filename ?? "document")"
            } else {
                conversation.title = String(text.prefix(40))
            }
        }
        conversation.updatedAt = Date()

        do {
            if isNew {
                try await firestoreService.createConversation(conversation, userId: userId)
            } else {
                try await firestoreService.updateConversation(conversation, userId: userId)
            }
            try await firestoreService.addMessage(userMessage, conversationId: conversation.id, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
            return
        }

        // Clear attachment after successful send
        pendingAttachment = nil

        // Build payloads — include user message in case listener hasn't fired yet
        var currentBranch = activeBranch
        if !currentBranch.contains(where: { $0.id == userMessage.id }) {
            currentBranch.append(userMessage)
        }

        let payloads = await buildPayloads(for: currentBranch)

        let smartTitleText = text.isEmpty ? nil : text
        startStreamingResponse(payloads: payloads, parentId: userMessage.id, userText: text, smartTitleUserText: smartTitleText)
    }

    // MARK: - Stop

    func stopGenerating() {
        streamTask?.cancel()
        streamTask = nil

        // Persist partial response if it has meaningful data
        if let finalMessage = streamingMessage, Self.hasPeristableContent(finalMessage) {
            Task {
                try? await firestoreService.addMessage(finalMessage, conversationId: conversation.id, userId: userId)
            }
        }

        streamingMessage = nil
        isGenerating = false
    }

    /// Returns true if the message has text, media, or thinking content worth saving.
    private static func hasPeristableContent(_ msg: Message) -> Bool {
        let hasText = !msg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = msg.mediaURL != nil
        let hasThinking = !(msg.thinkingContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasText || hasMedia || hasThinking
    }

    // MARK: - Regenerate

    func regenerate(from message: Message) async {
        guard message.role == "model" else { return }

        let parentId = message.parentId
        isGenerating = true
        errorMessage = nil

        let branch = activeBranch
        guard let index = branch.firstIndex(where: { $0.id == message.id }) else { return }
        let messagesUpToParent = Array(branch.prefix(index))

        // Use the parent user message text for intent detection during regeneration
        let parentUserText = messagesUpToParent.last(where: { $0.role == "user" })?.content ?? ""
        let payloads = await buildPayloads(for: messagesUpToParent)

        startStreamingResponse(payloads: payloads, parentId: parentId, userText: parentUserText)
    }

    // MARK: - Edit & Resend

    func editAndResend(_ message: Message, newText: String) async {
        guard message.role == "user" else { return }

        var updatedMessage = message
        updatedMessage.content = newText

        // Find all descendants to delete (not the edited message itself)
        var idsToDelete: [String] = []
        var frontier: Set<String> = [message.id]

        while !frontier.isEmpty {
            let children = messages.filter { msg in
                guard let pid = msg.parentId else { return false }
                return frontier.contains(pid)
            }
            let childIds = Set(children.map(\.id))
            frontier = childIds.subtracting(Set(idsToDelete))
            idsToDelete.append(contentsOf: childIds)
        }

        do {
            try await firestoreService.updateMessage(updatedMessage, conversationId: conversation.id, userId: userId)
            if !idsToDelete.isEmpty {
                try await firestoreService.deleteMessages(idsToDelete, conversationId: conversation.id, userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await sendFromMessage(updatedMessage)
    }

    private func sendFromMessage(_ userMessage: Message) async {
        isGenerating = true
        errorMessage = nil

        // Walk up from userMessage to root to build context
        var chain: [Message] = []
        var current: Message? = userMessage
        while let msg = current {
            chain.insert(msg, at: 0)
            if let pid = msg.parentId {
                current = messages.first { $0.id == pid }
            } else {
                current = nil
            }
        }

        let payloads = await buildPayloads(for: chain)

        startStreamingResponse(payloads: payloads, parentId: userMessage.id, userText: userMessage.content)
    }

    // MARK: - Delete

    func deleteFromMessage(_ message: Message) {
        Task {
            do {
                try await firestoreService.deleteMessageSubtree(
                    rootId: message.id,
                    allMessages: messages,
                    conversationId: conversation.id,
                    userId: userId
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteSingleMessage(_ message: Message) {
        Task {
            do {
                var idsToDelete = [message.id]
                if message.role == "user" {
                    let directResponses = messages.filter { $0.parentId == message.id && $0.role == "model" }
                    idsToDelete.append(contentsOf: directResponses.map(\.id))
                }
                try await firestoreService.deleteMessages(idsToDelete, conversationId: conversation.id, userId: userId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Branch Navigation

    func switchBranch(for message: Message, direction: Int) {
        let sibs = siblings(of: message)
        guard sibs.count > 1 else { return }
        guard let currentIndex = sibs.firstIndex(where: { $0.id == message.id }) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < sibs.count else { return }

        var target = sibs[newIndex]
        target.selectedAt = Date()

        Task {
            try? await firestoreService.updateMessage(target, conversationId: conversation.id, userId: userId)
        }

        Haptics.selection()
    }

    func branchInfo(for message: Message) -> (current: Int, total: Int) {
        let sibs = siblings(of: message)
        guard let index = sibs.firstIndex(where: { $0.id == message.id }) else {
            return (1, 1)
        }
        return (index + 1, sibs.count)
    }

    // MARK: - Streaming

    private func startStreamingResponse(payloads: [MessagePayload], parentId: String?, userText: String = "", smartTitleUserText: String? = nil) {
        let assistantMessage = Message(role: "model", content: "", parentId: parentId)
        let assistantMessageId = assistantMessage.id
        let conversationId = conversation.id
        streamingMessage = assistantMessage

        let stream = apiClient.streamContent(
            messages: payloads,
            config: buildConfig(),
            tools: buildTools(userText: userText),
            systemInstruction: conversation.systemInstruction,
            model: conversation.modelName
        )

        streamTask = Task {
            for await event in stream {
                if Task.isCancelled { break }
                // Only mutate if our message is still the active streaming message
                guard self.streamingMessage?.id == assistantMessageId else { continue }

                switch event {
                case .text(let text):
                    if var msg = self.streamingMessage {
                        msg.content += text
                        self.streamingMessage = msg
                    }
                case .thinking(let thought):
                    if var msg = self.streamingMessage {
                        msg.thinkingContent = (msg.thinkingContent ?? "") + thought
                        self.streamingMessage = msg
                    }
                case .imageData(let data, let mimeType):
                    await self.uploadStreamingMedia(data: data, mimeType: mimeType, messageId: assistantMessageId, conversationId: conversationId)
                case .functionCall(let name, let args):
                    await self.handleFunctionCall(name: name, args: args, messageId: assistantMessageId, conversationId: conversationId)
                case .usageMetadata(let input, let output, let cached):
                    if var msg = self.streamingMessage {
                        msg.inputTokens = input
                        msg.outputTokens = output
                        msg.cachedTokens = cached
                        self.streamingMessage = msg
                    }
                case .error(let error):
                    self.errorMessage = error
                case .done:
                    break
                }
            }

            // If cancelled (e.g. stopGenerating was called), do NOT persist — stopGenerating handles that.
            guard !Task.isCancelled else { return }
            // If our message was replaced by a newer stream, bail out.
            guard self.streamingMessage?.id == assistantMessageId else { return }

            let responseContent = self.streamingMessage?.content ?? ""
            await self.persistStreamingMessage()
            self.streamingMessage = nil
            self.isGenerating = false
            self.conversation.updatedAt = Date()
            try? await self.firestoreService.updateConversation(self.conversation, userId: self.userId)
            Haptics.success()

            // Generate smart title on first exchange
            if let userText = smartTitleUserText, self.messages.count <= 2 {
                Task.detached { [weak self] in
                    await self?.generateSmartTitle(userText: userText, responseText: responseContent)
                }
            }
        }
    }

    private func uploadStreamingMedia(data: Data, mimeType: String, messageId: String, conversationId: String) async {
        // Only set media on the matching streaming message
        guard streamingMessage?.id == messageId else { return }

        do {
            let storagePath = try await firestoreService.uploadMedia(
                data: data,
                mimeType: mimeType,
                userId: userId,
                conversationId: conversationId,
                messageId: messageId
            )
            // Cache locally so we don't need to re-download for display
            mediaService.cacheMedia(data: data, for: storagePath)
            if var msg = streamingMessage {
                msg.mediaURL = storagePath
                msg.mediaMimeType = mimeType
                streamingMessage = msg
            }
        } catch {
            // Fall back to local file if Firebase upload fails
            logger.error("Firebase upload failed: \(error.localizedDescription), falling back to local file")
            let ext: String
            switch mimeType {
            case "image/png":  ext = "png"
            case "image/webp": ext = "webp"
            case "video/mp4":  ext = "mp4"
            default:           ext = "jpg"
            }

            let mediaDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("media")
                .appendingPathComponent(conversationId)

            do {
                try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
                let fileURL = mediaDir.appendingPathComponent("\(messageId).\(ext)")
                try data.write(to: fileURL)
                if var msg = streamingMessage {
                    msg.mediaURL = fileURL.absoluteString
                    msg.mediaMimeType = mimeType
                    streamingMessage = msg
                }
            } catch {
                let base64 = data.base64EncodedString()
                if var msg = streamingMessage {
                    msg.mediaURL = "data:\(mimeType);base64,\(base64)"
                    msg.mediaMimeType = mimeType
                    streamingMessage = msg
                }
            }
        }
    }

    private func handleFunctionCall(name: String, args: [String: String], messageId: String, conversationId: String) async {
        if name == "generate_image", let prompt = args["prompt"] {
            let imageModel = conversation.modelName == Constants.Models.pro
                ? Constants.Models.proImage
                : Constants.Models.flashImage

            let imagePayloads = [MessagePayload(role: "user", text: prompt, mediaData: nil, mediaMimeType: nil)]
            let imageConfig = GenerationConfig(
                temperature: conversation.temperature,
                topP: conversation.topP,
                topK: conversation.topK,
                maxOutputTokens: conversation.maxOutputTokens,
                thinkingBudget: nil,
                responseModalities: ["IMAGE"],
                imageConfig: nil
            )

            do {
                let imageResponse = try await apiClient.generateContent(
                    messages: imagePayloads,
                    config: imageConfig,
                    tools: nil,
                    systemInstruction: nil,
                    model: imageModel
                )

                // Accumulate image generation token usage
                if let usage = imageResponse.usageMetadata, var msg = self.streamingMessage, msg.id == messageId {
                    msg.inputTokens = (msg.inputTokens ?? 0) + (usage.promptTokenCount ?? 0)
                    msg.outputTokens = (msg.outputTokens ?? 0) + (usage.candidatesTokenCount ?? 0)
                    msg.cachedTokens = (msg.cachedTokens ?? 0) + (usage.cachedContentTokenCount ?? 0)
                    self.streamingMessage = msg
                }

                if let parts = imageResponse.candidates.first?.content?.parts {
                    for part in parts {
                        if let inlineData = part.inlineData,
                           let data = Data(base64Encoded: inlineData.data) {
                            await uploadStreamingMedia(data: data, mimeType: inlineData.mimeType, messageId: messageId, conversationId: conversationId)
                        }
                        if let text = part.text {
                            guard self.streamingMessage?.id == messageId else { continue }
                            if var msg = self.streamingMessage {
                                msg.content += text
                                self.streamingMessage = msg
                            }
                        }
                    }
                }
            } catch {
                guard self.streamingMessage?.id == messageId else { return }
                if var msg = self.streamingMessage {
                    msg.content += "\n[Image generation failed: \(error.localizedDescription)]"
                    self.streamingMessage = msg
                }
            }
        } else if name == "generate_video", let prompt = args["prompt"] {
            let aspectRatio = args["aspectRatio"] ?? "16:9"

            do {
                let videoData = try await apiClient.generateVideo(
                    prompt: prompt,
                    aspectRatio: aspectRatio
                )
                await uploadStreamingMedia(data: videoData, mimeType: "video/mp4", messageId: messageId, conversationId: conversationId)

                // Estimate video cost from duration
                if var msg = self.streamingMessage, msg.id == messageId {
                    let duration = await Self.videoDuration(from: videoData)
                    // Veo per-second pricing
                    let perSecondRate = 0.35
                    msg.videoCost = (msg.videoCost ?? 0) + duration * perSecondRate
                    self.streamingMessage = msg
                }
            } catch {
                guard self.streamingMessage?.id == messageId else { return }
                if var msg = self.streamingMessage {
                    msg.content += "\n[Video generation failed: \(error.localizedDescription)]"
                    self.streamingMessage = msg
                }
            }
        }
    }

    private func persistStreamingMessage() async {
        guard let finalMessage = streamingMessage, Self.hasPeristableContent(finalMessage) else { return }
        do {
            try await firestoreService.addMessage(finalMessage, conversationId: conversation.id, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Get the duration of video data in seconds using AVAsset.
    private static func videoDuration(from data: Data) async -> Double {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        do {
            try data.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite ? seconds : 8.0  // fallback to 8s
        } catch {
            return 8.0  // Veo typically generates ~8s clips
        }
    }

    private func buildConfig() -> GenerationConfig {
        GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens,
            thinkingBudget: conversation.thinkingBudget
        )
    }

    private func buildTools(userText: String) -> ToolsConfig {
        let intent = detectMediaIntent(from: userText)
        return ToolsConfig(
            googleSearch: conversation.googleSearchEnabled,
            codeExecution: conversation.codeExecutionEnabled,
            urlContext: conversation.urlContextEnabled,
            imageGeneration: intent.wantsImage,
            videoGeneration: intent.wantsVideo
        )
    }

    /// Lightweight intent detection: checks whether the user's message suggests
    /// they want an image or video generated.
    private func detectMediaIntent(from text: String) -> (wantsImage: Bool, wantsVideo: Bool) {
        let lower = text.lowercased()

        // Action verbs that signal generation intent
        let generationVerbs = ["generate", "create", "make", "draw", "paint",
                               "sketch", "illustrate", "design", "render",
                               "produce", "compose", "craft"]

        let imageNouns = ["image", "picture", "photo", "illustration",
                          "artwork", "drawing", "painting", "portrait",
                          "sketch", "icon", "logo", "graphic",
                          "wallpaper", "poster", "banner", "meme"]

        let videoNouns = ["video", "clip", "animation", "movie",
                          "film", "footage", "motion"]

        // Check for explicit "generate an image" / "make a video" style phrases
        let hasGenerationVerb = generationVerbs.contains { lower.contains($0) }

        let mentionsImage = imageNouns.contains { lower.contains($0) }
        let mentionsVideo = videoNouns.contains { lower.contains($0) }

        let wantsImage = hasGenerationVerb && mentionsImage
        let wantsVideo = hasGenerationVerb && mentionsVideo

        return (wantsImage, wantsVideo)
    }

    private func buildPayloads(for messages: [Message]) async -> [MessagePayload] {
        var payloads: [MessagePayload] = []
        for msg in messages {
            var mediaData: Data? = nil
            var mediaMime: String? = nil

            if let urlString = msg.mediaURL, let mimeType = msg.mediaMimeType {
                if MediaTypes.isSupported(mimeType) {
                    let maxBytes = MediaLimits.maxBytes(for: mimeType)
                    do {
                        mediaData = try await mediaService.downloadMedia(from: urlString, maxBytes: maxBytes)
                        mediaMime = mimeType
                    } catch {
                        // Log but don't block the request — send without media
                        print("Failed to download media for message \(msg.id): \(error.localizedDescription)")
                    }
                }
            }

            payloads.append(MessagePayload(
                role: msg.role,
                text: msg.content,
                mediaData: mediaData,
                mediaMimeType: mediaMime
            ))
        }
        return payloads
    }

    private func generateSmartTitle(userText: String, responseText: String) async {
        let truncated = String(userText.prefix(40))
        guard conversation.title == truncated else { return }

        let preview = String(responseText.prefix(200))
        let titleMessages = [
            MessagePayload(role: "user", text: userText, mediaData: nil, mediaMimeType: nil),
            MessagePayload(role: "model", text: preview, mediaData: nil, mediaMimeType: nil)
        ]

        let config = GenerationConfig(
            temperature: 0.5,
            topP: 0.9,
            topK: 20,
            maxOutputTokens: 20,
            thinkingBudget: 0
        )

        do {
            let response = try await apiClient.generateContent(
                messages: titleMessages,
                config: config,
                tools: nil,
                systemInstruction: "Generate a concise 3-6 word title for this conversation. Return only the title text, nothing else.",
                model: "gemini-2.5-flash-lite"
            )

            let title = response.candidates.first?.content?.parts?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return }

            conversation.title = title
            try? await firestoreService.updateConversation(conversation, userId: userId)
        } catch {
            // Silently fail — keep the truncated title
        }
    }
}
