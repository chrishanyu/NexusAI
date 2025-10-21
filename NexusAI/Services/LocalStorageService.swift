//
//  LocalStorageService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import SwiftData

/// Service for local persistence using SwiftData
/// Handles offline message queue and cached data
@available(iOS 17.0, *)
class LocalStorageService {
    
    // MARK: - Singleton
    static let shared: LocalStorageService = {
        do {
            return try LocalStorageService()
        } catch {
            fatalError("Failed to initialize LocalStorageService: \(error.localizedDescription)")
        }
    }()
    
    // MARK: - Properties
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    private init() throws {
        // Define the schema
        let schema = Schema([
            CachedMessage.self,
            QueuedMessage.self,
            CachedConversation.self
        ])
        
        // Create model configuration
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        // Initialize container
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = ModelContext(modelContainer)
    }
    
    // MARK: - Message Queue (Offline Messages)
    
    /// Add message to offline queue
    func enqueueMessage(_ message: Message) throws {
        let queuedMessage = QueuedMessage(from: message)
        modelContext.insert(queuedMessage)
        try modelContext.save()
    }
    
    /// Get all queued messages
    func getQueuedMessages() throws -> [QueuedMessage] {
        let descriptor = FetchDescriptor<QueuedMessage>(sortBy: [SortDescriptor(\.timestamp)])
        return try modelContext.fetch(descriptor)
    }
    
    /// Remove message from queue
    func dequeueMessage(_ message: QueuedMessage) throws {
        modelContext.delete(message)
        try modelContext.save()
    }
    
    /// Clear all queued messages
    func clearMessageQueue() throws {
        let messages = try getQueuedMessages()
        messages.forEach { modelContext.delete($0) }
        try modelContext.save()
    }
    
    // MARK: - Cached Messages
    
    /// Cache messages locally
    func cacheMessages(_ messages: [Message]) throws {
        for message in messages {
            let cachedMessage = CachedMessage(from: message)
            modelContext.insert(cachedMessage)
        }
        try modelContext.save()
    }
    
    /// Get cached messages for a conversation
    func getCachedMessages(conversationId: String) throws -> [CachedMessage] {
        var descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = Constants.Pagination.messagesPerPage
        return try modelContext.fetch(descriptor)
    }
    
    /// Clear cached messages for a conversation
    func clearCachedMessages(conversationId: String) throws {
        let messages = try getCachedMessages(conversationId: conversationId)
        messages.forEach { modelContext.delete($0) }
        try modelContext.save()
    }
    
    // MARK: - Cached Conversations
    
    /// Cache conversations locally
    func cacheConversations(_ conversations: [Conversation]) throws {
        for conversation in conversations {
            let cachedConversation = CachedConversation(from: conversation)
            modelContext.insert(cachedConversation)
        }
        try modelContext.save()
    }
    
    /// Get cached conversations
    func getCachedConversations() throws -> [CachedConversation] {
        let descriptor = FetchDescriptor<CachedConversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }
    
    /// Clear all cached conversations
    func clearCachedConversations() throws {
        let conversations = try getCachedConversations()
        conversations.forEach { modelContext.delete($0) }
        try modelContext.save()
    }
    
    // MARK: - Clear All Cache
    
    /// Clear all local data
    func clearAllCache() throws {
        try clearMessageQueue()
        try clearCachedConversations()
        // Note: We don't clear individual conversation messages, as clearCachedConversations handles the parent
        try modelContext.save()
    }
}

// MARK: - SwiftData Models

/// Cached message for offline access
@available(iOS 17.0, *)
@Model
final class CachedMessage {
    var id: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var statusRaw: String
    var readBy: [String]
    var deliveredTo: [String]
    
    init(from message: Message) {
        self.id = message.id ?? UUID().uuidString
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.text = message.text
        self.timestamp = message.timestamp
        self.statusRaw = message.status.rawValue
        self.readBy = message.readBy
        self.deliveredTo = message.deliveredTo
    }
    
    var status: MessageStatus {
        MessageStatus(rawValue: statusRaw) ?? .sent
    }
    
    func toMessage() -> Message {
        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: timestamp,
            status: status,
            readBy: readBy,
            deliveredTo: deliveredTo,
            localId: nil
        )
    }
}

/// Local message model for queue management and offline support
@available(iOS 17.0, *)
@Model
final class QueuedMessage {
    var id: String
    var localId: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var statusRaw: String
    var isQueued: Bool
    var retryCount: Int
    
    init(from message: Message) {
        self.id = message.id ?? UUID().uuidString
        self.localId = message.localId ?? UUID().uuidString
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.text = message.text
        self.timestamp = message.timestamp
        self.statusRaw = message.status.rawValue
        self.isQueued = true
        self.retryCount = 0
    }
    
    var status: MessageStatus {
        get {
            MessageStatus(rawValue: statusRaw) ?? .sending
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    func toMessage() -> Message {
        return Message(
            id: id != localId ? id : nil, // Only use id if it's different from localId
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: timestamp,
            status: status,
            readBy: [senderId],
            deliveredTo: [],
            localId: localId
        )
    }
}

/// Cached conversation for offline access
@available(iOS 17.0, *)
@Model
final class CachedConversation {
    var id: String
    var typeRaw: String
    var participantIds: [String]
    var groupName: String?
    var lastMessageText: String?
    var lastMessageTimestamp: Date?
    var createdAt: Date
    var updatedAt: Date? // Optional to handle null values
    
    init(from conversation: Conversation) {
        self.id = conversation.id ?? UUID().uuidString
        self.typeRaw = conversation.type.rawValue
        self.participantIds = conversation.participantIds
        self.groupName = conversation.groupName
        self.lastMessageText = conversation.lastMessage?.text
        self.lastMessageTimestamp = conversation.lastMessage?.timestamp
        self.createdAt = conversation.createdAt
        self.updatedAt = conversation.updatedAt
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case saveFailed
    case fetchFailed
    case deleteFailed
    case containerInitFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save data locally"
        case .fetchFailed:
            return "Failed to fetch local data"
        case .deleteFailed:
            return "Failed to delete local data"
        case .containerInitFailed:
            return "Failed to initialize local storage"
        }
    }
}

