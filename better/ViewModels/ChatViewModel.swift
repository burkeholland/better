import SwiftUI
import SwiftData

@Observable
final class ChatViewModel {
    var conversation: Conversation
    var messageText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    var streamingMessage: Message?

    private let apiClient = GeminiAPIClient()
    private var streamTask: Task<Void, Never>?
    private var modelContext: ModelContext

    init(conversation: Conversation, modelContext: ModelContext) {
        self.conversation = conversation
        self.modelContext = modelContext
    }

    // Computed: active branch of messages to display
    var displayMessages: [Message] {
        conversation.activeBranch
    }

    // Send a message
    func send(text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isGenerating = true
        errorMessage = nil

        // Determine parent: last message in active branch
        let parentId = displayMessages.last?.id

        // Create user message
        let userMessage = Message(role: "user", content: text, parentId: parentId)
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        conversation.updatedAt = Date()

        // Auto-title on first message
        if conversation.title == "New Chat" {
            conversation.title = String(text.prefix(40))
        }

        try? modelContext.save()

        // Build message payloads from active branch
        let branch = conversation.activeBranch
        let payloads = branch.map { msg in
            MessagePayload(
                role: msg.role,
                text: msg.content,
                imageData: msg.imageData,
                imageMimeType: msg.imageMimeType
            )
        }

        let config = GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens,
            thinkingBudget: conversation.thinkingBudget
        )

        let tools: ToolsConfig? = {
            if conversation.googleSearchEnabled || conversation.codeExecutionEnabled || conversation.urlContextEnabled {
                return ToolsConfig(
                    googleSearch: conversation.googleSearchEnabled,
                    codeExecution: conversation.codeExecutionEnabled,
                    urlContext: conversation.urlContextEnabled
                )
            }
            return nil
        }()

        // Create placeholder response message
        let responseMessage = Message(role: "model", content: "", parentId: userMessage.id)
        responseMessage.conversation = conversation
        responseMessage.isStreaming = true
        modelContext.insert(responseMessage)
        self.streamingMessage = responseMessage

        // Stream response
        let stream = apiClient.streamContent(
            messages: payloads,
            config: config,
            tools: tools,
            systemInstruction: conversation.systemInstruction,
            model: conversation.modelName
        )

        streamTask = Task {
            for await event in stream {
                switch event {
                case .text(let text):
                    responseMessage.content += text
                case .thinking(let thought):
                    responseMessage.thinkingContent = (responseMessage.thinkingContent ?? "") + thought
                case .imageData(let data, let mimeType):
                    responseMessage.imageData = data
                    responseMessage.imageMimeType = mimeType
                case .usageMetadata(let input, let output, let cached):
                    responseMessage.inputTokens = input
                    responseMessage.outputTokens = output
                    responseMessage.cachedTokens = cached
                case .error(let error):
                    errorMessage = error
                case .done:
                    break
                }
            }

            responseMessage.isStreaming = false
            self.streamingMessage = nil
            self.isGenerating = false
            conversation.updatedAt = Date()
            try? modelContext.save()
            Haptics.success()
        }
    }

    // Stop generation
    func stopGenerating() {
        streamTask?.cancel()
        streamTask = nil
        streamingMessage?.isStreaming = false
        streamingMessage = nil
        isGenerating = false
        try? modelContext.save()
    }

    // Regenerate from a specific assistant message (creates new branch)
    func regenerate(from message: Message) async {
        guard message.role == "model" else { return }

        // The new response will share the same parentId as the message being regenerated
        let parentId = message.parentId

        isGenerating = true
        errorMessage = nil

        // Build messages up to (not including) the message being regenerated
        let branch = conversation.activeBranch
        guard let index = branch.firstIndex(where: { $0.id == message.id }) else { return }
        let messagesUpToParent = Array(branch.prefix(index))

        let payloads = messagesUpToParent.map { msg in
            MessagePayload(
                role: msg.role,
                text: msg.content,
                imageData: msg.imageData,
                imageMimeType: msg.imageMimeType
            )
        }

        let config = GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens,
            thinkingBudget: conversation.thinkingBudget
        )

        let tools: ToolsConfig? = {
            if conversation.googleSearchEnabled || conversation.codeExecutionEnabled || conversation.urlContextEnabled {
                return ToolsConfig(
                    googleSearch: conversation.googleSearchEnabled,
                    codeExecution: conversation.codeExecutionEnabled,
                    urlContext: conversation.urlContextEnabled
                )
            }
            return nil
        }()

        // Create new branch response
        let responseMessage = Message(role: "model", content: "", parentId: parentId)
        responseMessage.conversation = conversation
        responseMessage.isStreaming = true
        modelContext.insert(responseMessage)
        self.streamingMessage = responseMessage

        let stream = apiClient.streamContent(
            messages: payloads,
            config: config,
            tools: tools,
            systemInstruction: conversation.systemInstruction,
            model: conversation.modelName
        )

        streamTask = Task {
            for await event in stream {
                switch event {
                case .text(let text):
                    responseMessage.content += text
                case .thinking(let thought):
                    responseMessage.thinkingContent = (responseMessage.thinkingContent ?? "") + thought
                case .imageData(let data, let mimeType):
                    responseMessage.imageData = data
                    responseMessage.imageMimeType = mimeType
                case .usageMetadata(let input, let output, let cached):
                    responseMessage.inputTokens = input
                    responseMessage.outputTokens = output
                    responseMessage.cachedTokens = cached
                case .error(let error):
                    errorMessage = error
                case .done:
                    break
                }
            }

            responseMessage.isStreaming = false
            self.streamingMessage = nil
            self.isGenerating = false
            conversation.updatedAt = Date()
            try? modelContext.save()
        }
    }

    // Edit a user message and re-send (creates new branch)
    func editAndResend(_ message: Message, newText: String) async {
        guard message.role == "user" else { return }

        // Create a new user message at the same branch point
        let newUserMessage = Message(role: "user", content: newText, parentId: message.parentId)
        newUserMessage.conversation = conversation
        modelContext.insert(newUserMessage)
        try? modelContext.save()

        // Now send (the active branch will pick up this new message)
        // Build payloads from root to this new message
        await sendFromMessage(newUserMessage)
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
                current = conversation.messages.first { $0.id == pid }
            } else {
                current = nil
            }
        }

        let payloads = chain.map { msg in
            MessagePayload(
                role: msg.role,
                text: msg.content,
                imageData: msg.imageData,
                imageMimeType: msg.imageMimeType
            )
        }

        let config = GenerationConfig(
            temperature: conversation.temperature,
            topP: conversation.topP,
            topK: conversation.topK,
            maxOutputTokens: conversation.maxOutputTokens,
            thinkingBudget: conversation.thinkingBudget
        )

        let tools: ToolsConfig? = {
            if conversation.googleSearchEnabled || conversation.codeExecutionEnabled || conversation.urlContextEnabled {
                return ToolsConfig(
                    googleSearch: conversation.googleSearchEnabled,
                    codeExecution: conversation.codeExecutionEnabled,
                    urlContext: conversation.urlContextEnabled
                )
            }
            return nil
        }()

        let responseMessage = Message(role: "model", content: "", parentId: userMessage.id)
        responseMessage.conversation = conversation
        responseMessage.isStreaming = true
        modelContext.insert(responseMessage)
        self.streamingMessage = responseMessage

        let stream = apiClient.streamContent(
            messages: payloads,
            config: config,
            tools: tools,
            systemInstruction: conversation.systemInstruction,
            model: conversation.modelName
        )

        streamTask = Task {
            for await event in stream {
                switch event {
                case .text(let text):
                    responseMessage.content += text
                case .thinking(let thought):
                    responseMessage.thinkingContent = (responseMessage.thinkingContent ?? "") + thought
                case .imageData(let data, let mimeType):
                    responseMessage.imageData = data
                    responseMessage.imageMimeType = mimeType
                case .usageMetadata(let input, let output, let cached):
                    responseMessage.inputTokens = input
                    responseMessage.outputTokens = output
                    responseMessage.cachedTokens = cached
                case .error(let error):
                    errorMessage = error
                case .done:
                    break
                }
            }

            responseMessage.isStreaming = false
            self.streamingMessage = nil
            self.isGenerating = false
            conversation.updatedAt = Date()
            try? modelContext.save()
        }
    }

    // Delete a message and all its descendants
    func deleteFromMessage(_ message: Message) {
        var toDelete: Set<UUID> = [message.id]
        var frontier: Set<UUID> = [message.id]

        while !frontier.isEmpty {
            let children = conversation.messages.filter { msg in
                if let pid = msg.parentId { return frontier.contains(pid) }
                return false
            }
            let childIds = Set(children.map { $0.id })
            frontier = childIds
            toDelete.formUnion(childIds)
        }

        for msg in conversation.messages where toDelete.contains(msg.id) {
            modelContext.delete(msg)
        }

        try? modelContext.save()
    }

    // Navigate to a sibling branch
    func switchBranch(for message: Message, direction: Int) {
        // This changes which message is "active" in the branch
        // The active branch computation uses the LAST sibling by createdAt
        // To switch branches, we adjust the createdAt of the target sibling to be the latest
        let siblings = conversation.siblings(of: message)
        guard siblings.count > 1 else { return }
        guard let currentIndex = siblings.firstIndex(where: { $0.id == message.id }) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < siblings.count else { return }

        // Make the target sibling the "latest" by setting its createdAt to now
        let target = siblings[newIndex]
        target.createdAt = Date()
        try? modelContext.save()

        Haptics.selection()
    }

    // Get branch info for a message
    func branchInfo(for message: Message) -> (current: Int, total: Int) {
        let siblings = conversation.siblings(of: message)
        guard let index = siblings.firstIndex(where: { $0.id == message.id }) else {
            return (1, 1)
        }
        return (index + 1, siblings.count)
    }
}
