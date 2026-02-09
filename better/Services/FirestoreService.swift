import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "FirestoreService")

final class FirestoreService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Collection References

    private func conversationsRef(userId: String) -> CollectionReference {
        db.collection(Constants.Firestore.usersCollection)
            .document(userId)
            .collection(Constants.Firestore.conversationsCollection)
    }

    private func messagesRef(userId: String, conversationId: String) -> CollectionReference {
        conversationsRef(userId: userId)
            .document(conversationId)
            .collection(Constants.Firestore.messagesCollection)
    }

    // MARK: - Conversation Methods

    func createConversation(_ conversation: Conversation, userId: String) async throws {
        try conversationsRef(userId: userId)
            .document(conversation.id)
            .setData(from: conversation)
    }

    func updateConversation(_ conversation: Conversation, userId: String) async throws {
        try conversationsRef(userId: userId)
            .document(conversation.id)
            .setData(from: conversation, merge: true)
    }

    func deleteConversation(_ conversationId: String, userId: String) async throws {
        // First, delete all messages in the subcollection
        let messagesSnapshot = try await messagesRef(userId: userId, conversationId: conversationId)
            .getDocuments()

        let messageDocuments = messagesSnapshot.documents
        // Batch delete in groups of 500 (Firestore limit)
        for chunk in stride(from: 0, to: messageDocuments.count, by: 500) {
            let batch = db.batch()
            let end = min(chunk + 500, messageDocuments.count)
            for i in chunk..<end {
                batch.deleteDocument(messageDocuments[i].reference)
            }
            try await batch.commit()
        }

        // Then delete the conversation document
        try await conversationsRef(userId: userId)
            .document(conversationId)
            .delete()
    }

    func listenToConversations(userId: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        conversationsRef(userId: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    if let error {
                        print("Error listening to conversations: \(error.localizedDescription)")
                    }
                    onChange([])
                    return
                }

                let conversations = documents.compactMap { document -> Conversation? in
                    try? document.data(as: Conversation.self)
                }
                onChange(conversations)
            }
    }

    // MARK: - Message Methods

    func addMessage(_ message: Message, conversationId: String, userId: String) async throws {
        try messagesRef(userId: userId, conversationId: conversationId)
            .document(message.id)
            .setData(from: message)
    }

    func updateMessage(_ message: Message, conversationId: String, userId: String) async throws {
        try messagesRef(userId: userId, conversationId: conversationId)
            .document(message.id)
            .setData(from: message, merge: true)
    }

    func deleteMessages(_ messageIds: [String], conversationId: String, userId: String) async throws {
        let ref = messagesRef(userId: userId, conversationId: conversationId)
        for chunk in stride(from: 0, to: messageIds.count, by: 500) {
            let batch = db.batch()
            let end = min(chunk + 500, messageIds.count)
            for i in chunk..<end {
                batch.deleteDocument(ref.document(messageIds[i]))
            }
            try await batch.commit()
        }
    }

    func listenToMessages(conversationId: String, userId: String, onChange: @escaping ([Message]) -> Void) -> ListenerRegistration {
        messagesRef(userId: userId, conversationId: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    if let error {
                        print("Error listening to messages: \(error.localizedDescription)")
                    }
                    onChange([])
                    return
                }

                let messages = documents.compactMap { document -> Message? in
                    try? document.data(as: Message.self)
                }
                onChange(messages)
            }
    }

    // MARK: - Media Methods

    func uploadMedia(data: Data, mimeType: String, userId: String, conversationId: String, messageId: String) async throws -> String {
        // Determine file extension from MIME type
        let ext: String
        switch mimeType {
        case "image/png":             ext = "png"
        case "image/jpeg":            ext = "jpg"
        case "image/webp":            ext = "webp"
        case "image/heic":            ext = "heic"
        case "image/heif":            ext = "heif"
        case "application/pdf":       ext = "pdf"
        case "video/mp4":             ext = "mp4"
        default:                      ext = "jpg"
        }
        
        let path = "\(Constants.Firestore.mediaStoragePath)/\(userId)/\(conversationId)/\(messageId).\(ext)"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = mimeType

        logger.info("uploading \(data.count) bytes to \(path) (mimeType: \(mimeType))")

        // Debug: check auth state and storage bucket
        let authUser = Auth.auth().currentUser
        logger.info("Auth state — uid: \(authUser?.uid ?? "nil"), bucket: \(self.storage.reference().bucket)")
        if let authUser {
            do {
                let token = try await authUser.getIDTokenResult()
                logger.info("Auth token valid, expires: \(token.expirationDate)")
            } catch {
                logger.error("Failed to get auth token: \(error.localizedDescription)")
            }
        }

        // Write to a temp file and use putFile — more reliable for larger uploads
        // and avoids StorageUploadTask deallocation issues with putData + continuations
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + "." + ext)
        try data.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let _: StorageMetadata = try await withCheckedThrowingContinuation { continuation in
            let task = ref.putFile(from: tempFile, metadata: metadata) { resultMetadata, error in
                if let error {
                    logger.error("putFile error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let resultMetadata {
                    logger.info("putFile success — size: \(resultMetadata.size)")
                    continuation.resume(returning: resultMetadata)
                } else {
                    continuation.resume(throwing: GeminiAPIError.invalidResponse(message: "Upload returned no metadata and no error"))
                }
            }
            // Prevent task from being deallocated before completion
            task.observe(.failure) { snapshot in
                logger.error("putFile task failure observed: \(snapshot.error?.localizedDescription ?? "unknown")")
            }
        }
        logger.info("upload completed — path: \(path), bytes: \(data.count)")

        // Return the storage path directly — MediaService already handles downloading
        // via Storage SDK for non-URL paths, avoiding the downloadURL() race condition.
        return path
    }

    // MARK: - Tree Deletion

    func deleteMessageSubtree(rootId: String, allMessages: [Message], conversationId: String, userId: String) async throws {
        // Walk the parentId tree to find all descendants
        var idsToDelete: Set<String> = [rootId]
        var frontier: Set<String> = [rootId]

        while !frontier.isEmpty {
            let children = allMessages.filter { msg in
                guard let parentId = msg.parentId else { return false }
                return frontier.contains(parentId)
            }
            let childIds = Set(children.map(\.id))
            frontier = childIds.subtracting(idsToDelete)
            idsToDelete.formUnion(childIds)
        }

        try await deleteMessages(Array(idsToDelete), conversationId: conversationId, userId: userId)
    }
}
