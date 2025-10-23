//
//  MessageRepository.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// Concrete implementation of MessageRepositoryProtocol
/// Currently reads/writes ONLY from LocalDatabase (no Firestore sync yet)
@MainActor
final class MessageRepository: MessageRepositoryProtocol {
    
    private let database: LocalDatabase
    
    init(database: LocalDatabase? = nil) {
        self.database = database ?? LocalDatabase.shared
    }
    
    // MARK: - Observation
    
    func observeMessages(conversationId: String) -> AsyncStream<[Message]> {
        let predicate = #Predicate<LocalMessage> { message in
            message.conversationId == conversationId
        }
        
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observe(
                    LocalMessage.self,
                    where: predicate,
                    sortBy: [SortDescriptor(\LocalMessage.timestamp, order: .forward)]
                )
                
                for await localMessages in stream {
                    let messages = localMessages.map { $0.toMessage() }
                    continuation.yield(messages)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func observeMessage(messageId: String) -> AsyncStream<Message?> {
        let predicate = #Predicate<LocalMessage> { message in
            message.id == messageId
        }
        
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observeOne(LocalMessage.self, where: predicate)
                
                for await localMessage in stream {
                    continuation.yield(localMessage?.toMessage())
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Read Operations
    
    func getMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        let predicate = #Predicate<LocalMessage> { message in
            message.conversationId == conversationId
        }
        
        let localMessages = try database.fetch(
            LocalMessage.self,
            where: predicate,
            sortBy: [SortDescriptor(\LocalMessage.timestamp, order: .reverse)],
            limit: limit
        )
        
        return localMessages.map { $0.toMessage() }.reversed() // Return in ascending order
    }
    
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int) async throws -> [Message] {
        let predicate = #Predicate<LocalMessage> { message in
            message.conversationId == conversationId && message.timestamp < beforeDate
        }
        
        let localMessages = try database.fetch(
            LocalMessage.self,
            where: predicate,
            sortBy: [SortDescriptor(\LocalMessage.timestamp, order: .reverse)],
            limit: limit
        )
        
        return localMessages.map { $0.toMessage() }.reversed() // Return in ascending order
    }
    
    func getMessage(messageId: String) async throws -> Message? {
        let predicate = #Predicate<LocalMessage> { message in
            message.id == messageId
        }
        
        let localMessage = try database.fetchOne(LocalMessage.self, where: predicate)
        return localMessage?.toMessage()
    }
    
    // MARK: - Write Operations
    
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String
    ) async throws -> Message {
        let localId = UUID().uuidString
        let timestamp = Date()
        
        // Create domain model
        let message = Message(
            id: localId, // Will be replaced with Firestore ID when synced
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: timestamp,
            status: .sending,
            readBy: [],
            deliveredTo: [],
            localId: localId
        )
        
        // Convert to local model with pending sync status
        let localMessage = LocalMessage.from(message, syncStatus: .pending)
        
        // Insert into local database
        try database.insert(localMessage)
        try database.save()
        
        return message
    }
    
    func markMessagesAsRead(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws {
        for messageId in messageIds {
            let predicate = #Predicate<LocalMessage> { message in
                message.id == messageId
            }
            
            if let localMessage = try database.fetchOne(LocalMessage.self, where: predicate) {
                // Add userId to readBy if not already present
                if !localMessage.readBy.contains(userId) {
                    localMessage.readBy.append(userId)
                }
                
                // Update status if sender is not current user
                if localMessage.senderId != userId {
                    localMessage.status = .read
                }
                
                // Mark as pending sync
                localMessage.syncStatus = .pending
                
                try database.update(localMessage)
            }
        }
        
        try database.save()
    }
    
    func markMessagesAsDelivered(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws {
        for messageId in messageIds {
            let predicate = #Predicate<LocalMessage> { message in
                message.id == messageId
            }
            
            if let localMessage = try database.fetchOne(LocalMessage.self, where: predicate) {
                // Add userId to deliveredTo if not already present
                if !localMessage.deliveredTo.contains(userId) {
                    localMessage.deliveredTo.append(userId)
                }
                
                // Update status if sender is not current user and not already read
                if localMessage.senderId != userId && localMessage.status != .read {
                    localMessage.status = .delivered
                }
                
                // Mark as pending sync
                localMessage.syncStatus = .pending
                
                try database.update(localMessage)
            }
        }
        
        try database.save()
    }
    
    func deleteMessage(messageId: String) async throws {
        let predicate = #Predicate<LocalMessage> { message in
            message.id == messageId
        }
        
        if let localMessage = try database.fetchOne(LocalMessage.self, where: predicate) {
            try database.delete(localMessage)
            try database.save()
        }
    }
    
    // MARK: - Utility
    
    func getUnreadCount(conversationId: String, userId: String) async throws -> Int {
        // Note: Fetch and filter in memory due to SwiftData predicate limitations with array contains()
        let predicate = #Predicate<LocalMessage> { message in
            message.conversationId == conversationId &&
            message.senderId != userId
        }
        
        let messages = try database.fetch(LocalMessage.self, where: predicate)
        return messages.filter { !$0.readBy.contains(userId) }.count
    }
}

