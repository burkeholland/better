import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ChatViewModel {
    var conversation: Conversation
    var messageText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    var streamingMessage: Message?
    var messages: [Message] = []

    private let apiClient = GeminiAPIClient()
    private let firestoreService = FirestoreService()
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

    func persistConversation() async {
        try? await firestoreService.updateConversation(conversation, userId: userId)
    }

    // MARK: - Send

    func send(text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isGenerating = true
        errorMessage = nil

        let parentId = activeBranch.last?.id
        let userMessage = Message(role: "user", content: text, parentId: parentId)

        let isNew = messages.isEmpty

        if conversation.title == "New Chat" {
            conversation.title = String(text.prefix(40))
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

        // Build payloads — include user message in case listener hasn't fired yet
        var currentBranch = activeBranch
        if !currentBranch.contains(where: { $0.id == userMessage.id }) {
            currentBranch.append(userMessage)
        }

        let payloads = currentBranch.map { msg in
            MessagePayload(role: msg.role, text: msg.content, imageData: nil, imageMimeType: nil)
        }

        startStreamingResponse(payloads: payloads, parentId: userMessage.id, smartTitleUserText: text)
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

        let payloads = messagesUpToParent.map { msg in
            MessagePayload(role: msg.role, text: msg.content, imageData: nil, imageMimeType: nil)
        }

        startStreamingResponse(payloads: payloads, parentId: parentId)
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

        let payloads = chain.map { msg in
            MessagePayload(role: msg.role, text: msg.content, imageData: nil, imageMimeType: nil)
        }

        startStreamingResponse(payloads: payloads, parentId: userMessage.id)
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

    private func startStreamingResponse(payloads: [MessagePayload], parentId: String?, smartTitleUserText: String? = nil) {
        let assistantMessage = Message(role: "model", content: "", parentId: parentId)
        let assistantMessageId = assistantMessage.id
        let conversationId = conversation.id
        streamingMessage = assistantMessage

        let stream = apiClient.streamContent(
            messages: payloads,
            config: buildConfig(),
            tools: buildTools(),
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
                    self.streamingMessage?.content += text
                case .thinking(let thought):
                    self.streamingMessage?.thinkingContent = (self.streamingMessage?.thinkingContent ?? "") + thought
                case .imageData(let data, let mimeType):
                    await self.uploadStreamingMedia(data: data, mimeType: mimeType, messageId: assistantMessageId, conversationId: conversationId)
                case .functionCall(let name, let args):
                    await self.handleFunctionCall(name: name, args: args, messageId: assistantMessageId, conversationId: conversationId)
                case .usageMetadata(let input, let output, let cached):
                    self.streamingMessage?.inputTokens = input
                    self.streamingMessage?.outputTokens = output
                    self.streamingMessage?.cachedTokens = cached
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
            streamingMessage?.mediaURL = fileURL.absoluteString
            streamingMessage?.mediaMimeType = mimeType
        } catch {
            // Fall back to data URI if disk write fails
            let base64 = data.base64EncodedString()
            streamingMessage?.mediaURL = "data:\(mimeType);base64,\(base64)"
            streamingMessage?.mediaMimeType = mimeType
        }
    }

    private func handleFunctionCall(name: String, args: [String: String], messageId: String, conversationId: String) async {
        if name == "generate_image", let prompt = args["prompt"] {
            let imageModel = conversation.modelName == Constants.Models.pro
                ? Constants.Models.proImage
                : Constants.Models.flashImage

            let imagePayloads = [MessagePayload(role: "user", text: prompt, imageData: nil, imageMimeType: nil)]
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

                if let parts = imageResponse.candidates.first?.content?.parts {
                    for part in parts {
                        if let inlineData = part.inlineData,
                           let data = Data(base64Encoded: inlineData.data) {
                            await uploadStreamingMedia(data: data, mimeType: inlineData.mimeType, messageId: messageId, conversationId: conversationId)
                        }
                        if let text = part.text {
                            guard self.streamingMessage?.id == messageId else { continue }
                            streamingMessage?.content += text
                        }
                    }
                }
            } catch {
                guard self.streamingMessage?.id == messageId else { return }
                streamingMessage?.content += "\n[Image generation failed: \(error.localizedDescription)]"
            }
        } else if name == "generate_video", let prompt = args["prompt"] {
            let aspectRatio = args["aspectRatio"] ?? "16:9"

            do {
                let videoData = try await apiClient.generateVideo(
                    prompt: prompt,
                    aspectRatio: aspectRatio
                )
                await uploadStreamingMedia(data: videoData, mimeType: "video/mp4", messageId: messageId, conversationId: conversationId)
            } catch {
                guard self.streamingMessage?.id == messageId else { return }
                streamingMessage?.content += "\n[Video generation failed: \(error.localizedDescription)]"
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

    private func buildConfig() -> GenerationConfig {
        GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens,
            thinkingBudget: conversation.thinkingBudget
        )
    }

    private func buildTools() -> ToolsConfig {
        ToolsConfig(
            googleSearch: conversation.googleSearchEnabled,
            codeExecution: conversation.codeExecutionEnabled,
            urlContext: conversation.urlContextEnabled,
            imageGeneration: true,
            videoGeneration: true
        )
    }

    private func generateSmartTitle(userText: String, responseText: String) async {
        let truncated = String(userText.prefix(40))
        guard conversation.title == truncated else { return }

        let preview = String(responseText.prefix(200))
        let titleMessages = [
            MessagePayload(role: "user", text: userText, imageData: nil, imageMimeType: nil),
            MessagePayload(role: "model", text: preview, imageData: nil, imageMimeType: nil)
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
