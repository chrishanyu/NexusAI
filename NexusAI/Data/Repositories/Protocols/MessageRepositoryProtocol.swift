//
//  MessageRepositoryProtocol.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Protocol defining message repository operations
/// ViewModels depend on this protocol, not the concrete implementation
@MainActor
protocol MessageRepositoryProtocol {
    
    // MARK: - Observation (Reactive Queries)
    
    /// Observe messages for a specific conversation with real-time updates
    /// - Parameter conversationId: The conversation ID to observe
    /// - Returns: AsyncStream that emits arrays of messages whenever they change
    func observeMessages(conversationId: String) -> AsyncStream<[Message]>
    
    /// Observe a single message with real-time updates
    /// - Parameter messageId: The message ID to observe
    /// - Returns: AsyncStream that emits the message whenever it changes
    func observeMessage(messageId: String) -> AsyncStream<Message?>
    
    // MARK: - Read Operations
    
    /// Get messages for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - limit: Maximum number of messages to fetch (default: 50)
    /// - Returns: Array of messages sorted by timestamp
    func getMessages(conversationId: String, limit: Int) async throws -> [Message]
    
    /// Get older messages before a specific date (for pagination)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - beforeDate: Only fetch messages before this date
    ///   - limit: Maximum number of messages to fetch
    /// - Returns: Array of older messages
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int) async throws -> [Message]
    
    /// Get a single message by ID
    /// - Parameter messageId: The message ID
    /// - Returns: The message, or nil if not found
    func getMessage(messageId: String) async throws -> Message?
    
    // MARK: - Write Operations
    
    /// Send a new message (writes to local DB with pending sync status)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - text: Message text content
    ///   - senderId: User ID of the sender
    ///   - senderName: Display name of the sender
    /// - Returns: The created message with local ID
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String
    ) async throws -> Message
    
    /// Mark messages as read by a user
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID marking messages as read
    func markMessagesAsRead(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws
    
    /// Mark messages as delivered to a user
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID to mark as delivered to
    func markMessagesAsDelivered(
        messageIds: [String],
        conversationId: String,
        userId: String
    ) async throws
    
    /// Delete a message
    /// - Parameter messageId: The message ID to delete
    func deleteMessage(messageId: String) async throws
    
    // MARK: - Utility
    
    /// Get unread message count for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID to check unread count for
    /// - Returns: Number of unread messages
    func getUnreadCount(conversationId: String, userId: String) async throws -> Int
}

