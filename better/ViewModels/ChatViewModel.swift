import SwiftUI
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
    var generationStatus: String = "Thinking"
    var errorMessage: String?
    var streamingMessage: Message?
    var messages: [Message] = []
    var pendingAttachment: PendingAttachment?

    // Cached tree computations — recomputed only when `messages` changes
    private(set) var activeBranch: [Message] = []

    private let apiClient = OpenRouterAPIClient()
    private let imageService = ImageGenerationService()
    private let videoService = VideoGenerationService()
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
                self?.recomputeActiveBranch()
            }
        }
    }

    deinit {
        messagesListener?.remove()
    }

    // MARK: - Tree Logic

    private func recomputeActiveBranch() {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { activeBranch = []; return }
        let roots = sorted.filter { $0.parentId == nil }
        guard let root = roots.last else { activeBranch = []; return }
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
        activeBranch = branch
    }

    func siblings(of message: Message) -> [Message] {
        messages.filter { $0.parentId == message.parentId && $0.role == message.role }
            .sorted { $0.createdAt < $1.createdAt }
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
        get { conversation.modelName == Constants.Models.deepseekR1 }
        set {
            conversation.modelName = newValue ? Constants.Models.deepseekR1 : Constants.Models.deepseekChat
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

    var estimatedCost: Double {
        // OpenRouter Kimi K2.5 pricing per token
        let isKimi = conversation.modelName.contains("kimi")
        
        let inputRate: Double  = isKimi ? 0.50 / 1_000_000 : 0.28 / 1_000_000  // Kimi vs DeepSeek
        let outputRate: Double = isKimi ? 2.80 / 1_000_000 : 0.42 / 1_000_000
        
        return Double(totalInputTokens) * inputRate
             + Double(totalOutputTokens) * outputRate
             + totalVideoCost
    }

    func persistConversation() async {
        try? await firestoreService.updateConversation(conversation, userId: userId)
    }

    // MARK: - Attachments

    func attachImageData(data: Data, mimeTypeHint: String?, filename: String?) {
        errorMessage = nil

        do {
            let mimeType = resolveImageMimeType(data: data, hint: mimeTypeHint)
            try MediaTypes.validate(mimeType: mimeType, dataSize: data.count)

            let preview = UIImage(data: data)
            pendingAttachment = PendingAttachment(
                data: data,
                mimeType: mimeType,
                preview: preview,
                filename: filename
            )
        } catch {
            errorMessage = "Could not attach image: \(error.localizedDescription)"
        }
    }

    /// Attach an image from a file URL (used by file importer, bypasses Photos/iCloud).
    func attachImageFile(url: URL) async {
        errorMessage = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)

            let ext = url.pathExtension.lowercased()
            let mimeHint: String
            switch ext {
            case "png": mimeHint = "image/png"
            case "jpg", "jpeg": mimeHint = "image/jpeg"
            case "webp": mimeHint = "image/webp"
            case "heic": mimeHint = "image/heic"
            case "heif": mimeHint = "image/heif"
            default: mimeHint = "image/jpeg"
            }

            attachImageData(data: data, mimeTypeHint: mimeHint, filename: url.lastPathComponent)
        } catch {
            errorMessage = "Could not attach image: \(error.localizedDescription)"
        }
    }

    private func resolveImageMimeType(data: Data, hint: String?) -> String {
        if let hint, hint.hasPrefix("image/"), MediaTypes.isSupported(hint) {
            return hint
        }

        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 8,
           bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47,
           bytes[4] == 0x0D, bytes[5] == 0x0A, bytes[6] == 0x1A, bytes[7] == 0x0A {
            return "image/png"
        }

        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xD8 {
            return "image/jpeg"
        }

        if bytes.count >= 12,
           String(bytes: bytes[0...3], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8...11], encoding: .ascii) == "WEBP" {
            return "image/webp"
        }

        if bytes.count >= 12,
           String(bytes: bytes[4...7], encoding: .ascii) == "ftyp",
           let brand = String(bytes: bytes[8...11], encoding: .ascii) {
            if brand == "heic" || brand == "heix" || brand == "hevc" {
                return "image/heic"
            }
            if brand == "heif" || brand == "mif1" || brand == "msf1" {
                return "image/heif"
            }
        }

        return "image/jpeg"
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

        // Check if user wants image or video generation (always enabled)
        let intent = await detectMediaIntent(text: text)
        
        if intent.wantsImage {
            // Route to image generation
            await handleImageGeneration(prompt: text, parentId: userMessage.id)
        } else if intent.wantsVideo {
            // Route to video generation
            await handleVideoGeneration(prompt: text, parentId: userMessage.id)
        } else {
            // Normal text response
            let smartTitleText = text.isEmpty ? nil : text
            startStreamingResponse(payloads: payloads, parentId: userMessage.id, userText: text, smartTitleUserText: smartTitleText, hasAttachment: attachment != nil)
        }
    }
    
    // MARK: - Media Intent Detection
    
    /// Asks the LLM to classify whether the user wants image or video generation.
    /// Falls back to text if the classification call fails.
    private func detectMediaIntent(text: String) async -> (wantsImage: Bool, wantsVideo: Bool) {
        let classificationMessages = [
            MessagePayload(role: "user", text: text, mediaData: nil, mediaMimeType: nil)
        ]
        
        let config = GenerationConfig(
            temperature: 0,
            topP: 1.0,
            topK: 1,
            maxOutputTokens: 20
        )
        
        let systemPrompt = """
            Classify the user's intent. Reply with exactly one word:
            - "image" if they want an image/picture/photo/drawing/illustration generated
            - "video" if they want a video/animation/clip generated
            - "text" if they want a normal text response
            Reply with only that one word, nothing else.
            """
        
        do {
            let response = try await apiClient.generateContent(
                messages: classificationMessages,
                config: config,
                systemInstruction: systemPrompt,
                model: Constants.Models.deepseek
            )
            
            let classification = response.choices.first?.message?.content?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? "text"
            
            let wantsImage = classification == "image"
            let wantsVideo = classification == "video"
            
            logger.info("Intent detection: \(classification) (image=\(wantsImage), video=\(wantsVideo)) for: \(text.prefix(50))")
            
            return (wantsImage, wantsVideo)
        } catch {
            logger.warning("Intent detection failed, defaulting to text: \(error.localizedDescription)")
            return (false, false)
        }
    }
    
    // MARK: - Image Generation
    
    private func handleImageGeneration(prompt: String, parentId: String?) async {
        let assistantMessage = Message(role: "model", content: "", parentId: parentId)
        let assistantMessageId = assistantMessage.id
        let conversationId = conversation.id
        streamingMessage = assistantMessage
        generationStatus = "Generating image…"
        
        do {
            let (imageData, mimeType) = try await imageService.generateImage(prompt: prompt)
            
            // Upload to Firebase
            generationStatus = "Uploading…"
            let storagePath = try await firestoreService.uploadMedia(
                data: imageData,
                mimeType: mimeType,
                userId: userId,
                conversationId: conversationId,
                messageId: assistantMessageId
            )
            
            // Update streaming message with image
            if var msg = streamingMessage, msg.id == assistantMessageId {
                msg.mediaURL = storagePath
                msg.mediaMimeType = mimeType
                msg.content = "Here's the image I generated for: \"\(prompt)\""
                streamingMessage = msg
            }
            
            // Cache locally
            mediaService.cacheMedia(data: imageData, for: storagePath)
            
            // Persist the message
            await persistStreamingMessage()
            streamingMessage = nil
            isGenerating = false
            Haptics.success()
            
        } catch {
            logger.error("Image generation failed: \(error.localizedDescription)")
            if var msg = streamingMessage, msg.id == assistantMessageId {
                msg.content = "Sorry, I couldn't generate that image. \(error.localizedDescription)"
                streamingMessage = msg
            }
            await persistStreamingMessage()
            streamingMessage = nil
            isGenerating = false
            Haptics.error()
        }
    }
    
    // MARK: - Video Generation
    
    private func handleVideoGeneration(prompt: String, parentId: String?) async {
        let assistantMessage = Message(role: "model", content: "", parentId: parentId)
        let assistantMessageId = assistantMessage.id
        let conversationId = conversation.id
        streamingMessage = assistantMessage
        
        for await status in videoService.generateVideo(prompt: prompt) {
            guard streamingMessage?.id == assistantMessageId else { return }
            
            switch status {
            case .pending:
                generationStatus = "Starting video generation…"
            case .processing(let progress):
                if let p = progress {
                    generationStatus = "Generating video… \(Int(p * 100))%"
                } else {
                    generationStatus = "Generating video…"
                }
            case .completed(let videoData):
                generationStatus = "Uploading…"
                do {
                    let storagePath = try await firestoreService.uploadMedia(
                        data: videoData,
                        mimeType: "video/mp4",
                        userId: userId,
                        conversationId: conversationId,
                        messageId: assistantMessageId
                    )
                    
                    if var msg = streamingMessage, msg.id == assistantMessageId {
                        msg.mediaURL = storagePath
                        msg.mediaMimeType = "video/mp4"
                        msg.content = "Here's the video I generated for: \"\(prompt)\""
                        streamingMessage = msg
                    }
                    
                    mediaService.cacheMedia(data: videoData, for: storagePath)
                    await persistStreamingMessage()
                    streamingMessage = nil
                    isGenerating = false
                    Haptics.success()
                    return
                } catch {
                    if var msg = streamingMessage, msg.id == assistantMessageId {
                        msg.content = "Video generated but upload failed: \(error.localizedDescription)"
                        streamingMessage = msg
                    }
                    await persistStreamingMessage()
                    streamingMessage = nil
                    isGenerating = false
                    Haptics.error()
                    return
                }
            case .failed(let error):
                if var msg = streamingMessage, msg.id == assistantMessageId {
                    msg.content = "Sorry, I couldn't generate that video. \(error)"
                    streamingMessage = msg
                }
                await persistStreamingMessage()
                streamingMessage = nil
                isGenerating = false
                Haptics.error()
                return
            }
        }
    }

    // MARK: - Stop

    func stopGenerating() {
        streamTask?.cancel()
        streamTask = nil

        // Persist partial response if it has meaningful data
        if let finalMessage = streamingMessage, Self.hasPersistableContent(finalMessage) {
            Task {
                try? await firestoreService.addMessage(finalMessage, conversationId: conversation.id, userId: userId)
            }
        }

        streamingMessage = nil
        isGenerating = false
    }

    /// Returns true if the message has text, media, or thinking content worth saving.
    private static func hasPersistableContent(_ msg: Message) -> Bool {
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

        let parentUser = messagesUpToParent.last(where: { $0.role == "user" })
        let parentUserText = parentUser?.content ?? ""

        // If the parent user message has media, go straight to vision/text — don't override with intent
        if parentUser?.hasMedia == true {
            let payloads = await buildPayloads(for: messagesUpToParent)
            startStreamingResponse(payloads: payloads, parentId: parentId, userText: parentUserText)
        } else {
            let intent = await detectMediaIntent(text: parentUserText)
            if intent.wantsImage {
                await handleImageGeneration(prompt: parentUserText, parentId: parentId)
            } else if intent.wantsVideo {
                await handleVideoGeneration(prompt: parentUserText, parentId: parentId)
            } else {
                let payloads = await buildPayloads(for: messagesUpToParent)
                startStreamingResponse(payloads: payloads, parentId: parentId, userText: parentUserText)
            }
        }
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

        // If the message has media, go straight to vision/text — don't override with intent
        if userMessage.hasMedia {
            let payloads = await buildPayloads(for: chain)
            startStreamingResponse(payloads: payloads, parentId: userMessage.id, userText: userMessage.content)
        } else {
            let intent = await detectMediaIntent(text: userMessage.content)
            if intent.wantsImage {
                await handleImageGeneration(prompt: userMessage.content, parentId: userMessage.id)
            } else if intent.wantsVideo {
                await handleVideoGeneration(prompt: userMessage.content, parentId: userMessage.id)
            } else {
                let payloads = await buildPayloads(for: chain)
                startStreamingResponse(payloads: payloads, parentId: userMessage.id, userText: userMessage.content)
            }
        }
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

    private func startStreamingResponse(payloads: [MessagePayload], parentId: String?, userText: String = "", smartTitleUserText: String? = nil, hasAttachment: Bool = false) {
        // Auto-switch to vision model only when a user message has media attached
        let hasMedia = payloads.contains { $0.role == "user" && $0.mediaData != nil }
        let model = hasMedia ? Constants.Models.qwenVision : conversation.modelName
        
        let assistantMessage = Message(role: "model", content: "", parentId: parentId)
        let assistantMessageId = assistantMessage.id
        let conversationId = conversation.id
        streamingMessage = assistantMessage
        generationStatus = "Thinking"

        streamTask = Task {
            let systemInstruction = buildSystemInstruction()

            logger.debug("System instruction: \(systemInstruction)")

            let stream = apiClient.streamContent(
                messages: payloads,
                config: buildConfig(),
                systemInstruction: systemInstruction,
                model: model
            )
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
                    // Handle inline image data from stream
                    await self.uploadStreamingMedia(data: data, mimeType: mimeType, messageId: assistantMessageId, conversationId: conversationId)
                case .functionCall(_, _):
                    // Function calls not used with OpenRouter
                    break
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

    private func persistStreamingMessage() async {
        guard let finalMessage = streamingMessage, Self.hasPersistableContent(finalMessage) else { return }
        do {
            try await firestoreService.addMessage(finalMessage, conversationId: conversation.id, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildConfig() -> GenerationConfig {
        GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens
        )
    }

    private func buildSystemInstruction() -> String {
        var parts: [String] = []
        
        // Minimal identity
        parts.append("You are a helpful AI assistant.")
        
        // Append user's custom system instruction if present
        if let custom = conversation.systemInstruction, !custom.isEmpty {
            parts.append(custom)
        }
        
        return parts.joined(separator: "\n\n")
    }

    private func buildPayloads(for messages: [Message]) async -> [MessagePayload] {
        var payloads: [MessagePayload] = []
        for msg in messages {
            var mediaData: Data? = nil
            var mediaMime: String? = nil

            // Only include media for user messages — assistant-generated images/videos
            // should not be sent back to the API (wastes tokens, wrong role for vision APIs)
            if msg.isUser, let urlString = msg.mediaURL, let mimeType = msg.mediaMimeType {
                if MediaTypes.isSupported(mimeType) {
                    let maxBytes = MediaLimits.maxBytes(for: mimeType)
                    do {
                        mediaData = try await mediaService.downloadMedia(from: urlString, maxBytes: maxBytes)
                        mediaMime = mimeType
                    } catch {
                        logger.warning("Failed to download media for message \(msg.id): \(error.localizedDescription)")
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
            maxOutputTokens: 20
        )

        do {
            let response = try await apiClient.generateContent(
                messages: titleMessages,
                config: config,
                systemInstruction: "Generate a concise 3-6 word title for this conversation. Return only the title text, nothing else.",
                model: Constants.Models.deepseek  // Use cheap model for titles
            )

            let title = response.choices.first?.message?.content?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return }

            conversation.title = title
            try? await firestoreService.updateConversation(conversation, userId: userId)
        } catch {
            // Silently fail — keep the truncated title
        }
    }
}
