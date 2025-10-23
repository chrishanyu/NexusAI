//
//  MockConversationRepository.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import Foundation
@testable import NexusAI

/// Mock implementation of ConversationRepositoryProtocol for testing
@MainActor
final class MockConversationRepository: ConversationRepositoryProtocol {
    
    // Storage
    private var conversations: [Conversation] = []
    
    // Mock control flags
    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic
    
    // Call tracking
    var createDirectConversationCallCount = 0
    var createGroupConversationCallCount = 0
    var updateLastMessageCallCount = 0
    var updateGroupNameCallCount = 0
    var addParticipantCallCount = 0
    var removeParticipantCallCount = 0
    var deleteConversationCallCount = 0
    var lastCreatedConversation: Conversation?
    var lastUpdatedConversationId: String?
    
    // MARK: - Observation
    
    func observeConversations(userId: String) -> AsyncStream<[Conversation]> {
        AsyncStream { continuation in
            let filtered = self.conversations.filter { $0.participantIds.contains(userId) }
                .sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
            continuation.yield(filtered)
            continuation.finish()
        }
    }
    
    func observeConversation(conversationId: String) -> AsyncStream<Conversation?> {
        AsyncStream { continuation in
            let conversation = self.conversations.first { $0.id == conversationId }
            continuation.yield(conversation)
            continuation.finish()
        }
    }
    
    // MARK: - Read Operations
    
    func getConversations(userId: String) async throws -> [Conversation] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return conversations
            .filter { $0.participantIds.contains(userId) }
            .sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
    }
    
    func getConversation(conversationId: String) async throws -> Conversation? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return conversations.first { $0.id == conversationId }
    }
    
    // MARK: - Write Operations
    
    func createDirectConversation(
        userId: String,
        otherUserId: String,
        otherUserInfo: Conversation.ParticipantInfo
    ) async throws -> Conversation {
        createDirectConversationCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Check if exists
        if let existing = conversations.first(where: {
            $0.type == .direct &&
            $0.participantIds.contains(userId) &&
            $0.participantIds.contains(otherUserId)
        }) {
            return existing
        }
        
        let currentUserInfo = Conversation.ParticipantInfo(
            displayName: "Current User",
            profileImageUrl: nil
        )
        
        let conversation = Conversation(
            id: UUID().uuidString,
            type: .direct,
            participantIds: [userId, otherUserId].sorted(),
            participants: [
                userId: currentUserInfo,
                otherUserId: otherUserInfo
            ],
            lastMessage: nil,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: nil
        )
        
        conversations.append(conversation)
        lastCreatedConversation = conversation
        
        return conversation
    }
    
    func createGroupConversation(
        creatorId: String,
        participantIds: [String],
        participantsInfo: [String: Conversation.ParticipantInfo],
        groupName: String?,
        groupImageUrl: String?
    ) async throws -> Conversation {
        createGroupConversationCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let conversation = Conversation(
            id: UUID().uuidString,
            type: .group,
            participantIds: participantIds.sorted(),
            participants: participantsInfo,
            lastMessage: nil,
            groupName: groupName,
            groupImageUrl: groupImageUrl,
            createdBy: creatorId,
            createdAt: Date(),
            updatedAt: nil
        )
        
        conversations.append(conversation)
        lastCreatedConversation = conversation
        
        return conversation
    }
    
    func updateLastMessage(conversationId: String, message: Message) async throws {
        updateLastMessageCallCount += 1
        lastUpdatedConversationId = conversationId
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            throw MockError.notFound
        }
        
        var conversation = conversations[index]
        conversation.lastMessage = Conversation.LastMessage(
            text: message.text,
            senderId: message.senderId,
            senderName: message.senderName,
            timestamp: message.timestamp
        )
        conversation.updatedAt = Date()
        conversations[index] = conversation
    }
    
    func updateGroupName(conversationId: String, groupName: String) async throws {
        updateGroupNameCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            throw MockError.notFound
        }
        
        var conversation = conversations[index]
        conversation.groupName = groupName
        conversation.updatedAt = Date()
        conversations[index] = conversation
    }
    
    func addParticipant(
        conversationId: String,
        userId: String,
        userInfo: Conversation.ParticipantInfo
    ) async throws {
        addParticipantCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            throw MockError.notFound
        }
        
        let conversation = conversations[index]
        // participantIds is immutable, need to create new array
        var updatedParticipantIds = conversation.participantIds
        if !updatedParticipantIds.contains(userId) {
            updatedParticipantIds.append(userId)
            updatedParticipantIds.sort()
        }
        var updatedParticipants = conversation.participants
        updatedParticipants[userId] = userInfo
        
        // Recreate conversation with updated values
        conversations[index] = Conversation(
            id: conversation.id,
            type: conversation.type,
            participantIds: updatedParticipantIds,
            participants: updatedParticipants,
            lastMessage: conversation.lastMessage,
            groupName: conversation.groupName,
            groupImageUrl: conversation.groupImageUrl,
            createdBy: conversation.createdBy,
            createdAt: conversation.createdAt,
            updatedAt: Date()
        )
    }
    
    func removeParticipant(conversationId: String, userId: String) async throws {
        removeParticipantCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            throw MockError.notFound
        }
        
        let conversation = conversations[index]
        // participantIds is immutable, need to create new array
        var updatedParticipantIds = conversation.participantIds
        updatedParticipantIds.removeAll { $0 == userId }
        var updatedParticipants = conversation.participants
        updatedParticipants.removeValue(forKey: userId)
        
        // Recreate conversation with updated values
        conversations[index] = Conversation(
            id: conversation.id,
            type: conversation.type,
            participantIds: updatedParticipantIds,
            participants: updatedParticipants,
            lastMessage: conversation.lastMessage,
            groupName: conversation.groupName,
            groupImageUrl: conversation.groupImageUrl,
            createdBy: conversation.createdBy,
            createdAt: conversation.createdAt,
            updatedAt: Date()
        )
    }
    
    func deleteConversation(conversationId: String) async throws {
        deleteConversationCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        conversations.removeAll { $0.id == conversationId }
    }
    
    // MARK: - Test Helpers
    
    func setConversations(_ conversations: [Conversation]) {
        self.conversations = conversations
    }
    
    func reset() {
        conversations = []
        shouldThrowError = false
        createDirectConversationCallCount = 0
        createGroupConversationCallCount = 0
        updateLastMessageCallCount = 0
        updateGroupNameCallCount = 0
        addParticipantCallCount = 0
        removeParticipantCallCount = 0
        deleteConversationCallCount = 0
        lastCreatedConversation = nil
        lastUpdatedConversationId = nil
    }
}

