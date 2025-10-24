//
//  ConversationRepositoryProtocol.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Protocol defining conversation repository operations
/// ViewModels depend on this protocol, not the concrete implementation
@MainActor
protocol ConversationRepositoryProtocol {
    
    // MARK: - Observation (Reactive Queries)
    
    /// Observe all conversations for a user with real-time updates
    /// - Parameter userId: The user ID to observe conversations for
    /// - Returns: AsyncStream that emits arrays of conversations whenever they change
    func observeConversations(userId: String) -> AsyncStream<[Conversation]>
    
    /// Observe a single conversation with real-time updates
    /// - Parameter conversationId: The conversation ID to observe
    /// - Returns: AsyncStream that emits the conversation whenever it changes
    func observeConversation(conversationId: String) -> AsyncStream<Conversation?>
    
    // MARK: - Read Operations
    
    /// Get all conversations for a user
    /// - Parameter userId: The user ID
    /// - Returns: Array of conversations sorted by updatedAt
    func getConversations(userId: String) async throws -> [Conversation]
    
    /// Get a single conversation by ID
    /// - Parameter conversationId: The conversation ID
    /// - Returns: The conversation, or nil if not found
    func getConversation(conversationId: String) async throws -> Conversation?
    
    // MARK: - Write Operations
    
    /// Create a new direct conversation between two users
    /// - Parameters:
    ///   - userId: The current user's ID
    ///   - otherUserId: The other user's ID
    ///   - otherUserInfo: Participant info for the other user
    /// - Returns: The created conversation (or existing if already exists)
    func createDirectConversation(
        userId: String,
        otherUserId: String,
        otherUserInfo: Conversation.ParticipantInfo
    ) async throws -> Conversation
    
    /// Create a new group conversation
    /// - Parameters:
    ///   - creatorId: The user ID of the creator
    ///   - participantIds: Array of participant user IDs
    ///   - participantsInfo: Dictionary of participant info (userId -> info)
    ///   - groupName: Optional group name
    ///   - groupImageUrl: Optional group image URL
    /// - Returns: The created conversation
    func createGroupConversation(
        creatorId: String,
        participantIds: [String],
        participantsInfo: [String: Conversation.ParticipantInfo],
        groupName: String?,
        groupImageUrl: String?
    ) async throws -> Conversation
    
    /// Update the last message for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - message: The message to set as last message
    func updateLastMessage(conversationId: String, message: Message) async throws
    
    /// Update group name
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - groupName: The new group name
    func updateGroupName(conversationId: String, groupName: String) async throws
    
    /// Add a participant to a group conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID to add
    ///   - userInfo: Participant info for the user
    func addParticipant(
        conversationId: String,
        userId: String,
        userInfo: Conversation.ParticipantInfo
    ) async throws
    
    /// Remove a participant from a group conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID to remove
    func removeParticipant(conversationId: String, userId: String) async throws
    
    /// Delete a conversation
    /// - Parameter conversationId: The conversation ID to delete
    func deleteConversation(conversationId: String) async throws
}

