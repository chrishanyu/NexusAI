//
//  MockMessageRepository.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import Foundation
@testable import NexusAI

/// Mock implementation of MessageRepositoryProtocol for testing
@MainActor
final class MockMessageRepository: MessageRepositoryProtocol {
    
    // Storage
    private var messages: [Message] = []
    
    // Mock control flags
    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic
    
    // Call tracking
    var sendMessageCallCount = 0
    var markAsReadCallCount = 0
    var markAsDeliveredCallCount = 0
    var deleteMessageCallCount = 0
    var lastSentMessage: Message?
    var lastMarkedReadMessageIds: [String]?
    var lastMarkedDeliveredMessageIds: [String]?
    
    // MARK: - Observation
    
    func observeMessages(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let filtered = self.messages.filter { $0.conversationId == conversationId }
                .sorted { $0.timestamp < $1.timestamp }
            continuation.yield(filtered)
            continuation.finish()
        }
    }
    
    func observeMessage(messageId: String) -> AsyncStream<Message?> {
        AsyncStream { continuation in
            // Compare optional id with messageId
            let message = self.messages.first { $0.id == messageId }
            continuation.yield(message)
            continuation.finish()
        }
    }
    
    // MARK: - Read Operations
    
    func getMessages(conversationId: String, limit: Int) async throws -> [Message] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return messages
            .filter { $0.conversationId == conversationId }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(limit)
            .reversed()
    }
    
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int) async throws -> [Message] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return messages
            .filter { $0.conversationId == conversationId && $0.timestamp < beforeDate }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .reversed()
    }
    
    func getMessage(messageId: String) async throws -> Message? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Compare optional id with messageId
        return messages.first { $0.id == messageId }
    }
    
    // MARK: - Write Operations
    
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String
    ) async throws -> Message {
        sendMessageCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            status: .sending,
            readBy: [],
            deliveredTo: [],
            localId: UUID().uuidString
        )
        
        messages.append(message)
        lastSentMessage = message
        
        return message
    }
    
    func markMessagesAsRead(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws {
        markAsReadCallCount += 1
        lastMarkedReadMessageIds = messageIds
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        for i in 0..<messages.count {
            // Unwrap optional id
            guard let messageId = messages[i].id else { continue }
            if messageIds.contains(messageId) {
                var updatedMessage = messages[i]
                if !updatedMessage.readBy.contains(userId) {
                    updatedMessage.readBy.append(userId)
                }
                if updatedMessage.senderId != userId {
                    updatedMessage.status = .read
                }
                messages[i] = updatedMessage
            }
        }
    }
    
    func markMessagesAsDelivered(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws {
        markAsDeliveredCallCount += 1
        lastMarkedDeliveredMessageIds = messageIds
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        for i in 0..<messages.count {
            // Unwrap optional id
            guard let messageId = messages[i].id else { continue }
            if messageIds.contains(messageId) {
                var updatedMessage = messages[i]
                if !updatedMessage.deliveredTo.contains(userId) {
                    updatedMessage.deliveredTo.append(userId)
                }
                if updatedMessage.senderId != userId && updatedMessage.status != .read {
                    updatedMessage.status = .delivered
                }
                messages[i] = updatedMessage
            }
        }
    }
    
    func deleteMessage(messageId: String) async throws {
        deleteMessageCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Compare optional id with messageId
        messages.removeAll { $0.id == messageId }
    }
    
    // MARK: - Utility
    
    func getUnreadCount(conversationId: String, userId: String) async throws -> Int {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return messages.filter { message in
            message.conversationId == conversationId &&
            message.senderId != userId &&
            !message.readBy.contains(userId)
        }.count
    }
    
    // MARK: - Test Helpers
    
    func setMessages(_ messages: [Message]) {
        self.messages = messages
    }
    
    func reset() {
        messages = []
        shouldThrowError = false
        sendMessageCallCount = 0
        markAsReadCallCount = 0
        markAsDeliveredCallCount = 0
        deleteMessageCallCount = 0
        lastSentMessage = nil
        lastMarkedReadMessageIds = nil
        lastMarkedDeliveredMessageIds = nil
    }
}

enum MockError: Error {
    case generic
    case notFound
}

