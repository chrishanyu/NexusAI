//
//  ConversationRepository.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// Concrete implementation of ConversationRepositoryProtocol
/// Currently reads/writes ONLY from LocalDatabase (no Firestore sync yet)
@MainActor
final class ConversationRepository: ConversationRepositoryProtocol {
    
    private let database: LocalDatabase
    
    init(database: LocalDatabase? = nil) {
        self.database = database ?? LocalDatabase.shared
    }
    
    // MARK: - Observation
    
    func observeConversations(userId: String) -> AsyncStream<[Conversation]> {
        // Note: Fetch all conversations and filter in memory due to SwiftData predicate limitations
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observe(
                    LocalConversation.self,
                    where: nil,
                    sortBy: [SortDescriptor(\LocalConversation.updatedAt, order: .reverse)]
                )
                
                for await localConversations in stream {
                    let filteredConversations = localConversations
                        .filter { $0.participantIds.contains(userId) }
                        .map { $0.toConversation() }
                    continuation.yield(filteredConversations)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func observeConversation(conversationId: String) -> AsyncStream<Conversation?> {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observeOne(LocalConversation.self, where: predicate)
                
                for await localConversation in stream {
                    continuation.yield(localConversation?.toConversation())
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Read Operations
    
    func getConversations(userId: String) async throws -> [Conversation] {
        // Note: Fetch all conversations and filter in memory due to SwiftData predicate limitations
        let localConversations = try database.fetch(
            LocalConversation.self,
            sortBy: [SortDescriptor(\LocalConversation.updatedAt, order: .reverse)]
        )
        
        return localConversations
            .filter { $0.participantIds.contains(userId) }
            .map { $0.toConversation() }
    }
    
    func getConversation(conversationId: String) async throws -> Conversation? {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        let localConversation = try database.fetchOne(LocalConversation.self, where: predicate)
        return localConversation?.toConversation()
    }
    
    // MARK: - Write Operations
    
    func createDirectConversation(
        userId: String,
        otherUserId: String,
        otherUserInfo: Conversation.ParticipantInfo
    ) async throws -> Conversation {
        // Check if direct conversation already exists
        // Note: Fetch all direct conversations and filter in memory due to SwiftData predicate limitations
        let participantIds = [userId, otherUserId].sorted()
        let existingPredicate = #Predicate<LocalConversation> { conversation in
            conversation.typeRaw == "direct"
        }
        
        let directConversations = try database.fetch(LocalConversation.self, where: existingPredicate)
        let existing = directConversations.first { conversation in
            conversation.participantIds.contains(userId) &&
            conversation.participantIds.contains(otherUserId) &&
            conversation.participantIds.count == 2
        }
        
        if let existing = existing {
            return existing.toConversation()
        }
        
        // Create new conversation
        let conversationId = UUID().uuidString
        let currentUserInfo = Conversation.ParticipantInfo(
            displayName: "You", // Should be passed from caller
            profileImageUrl: nil
        )
        
        let participants: [String: Conversation.ParticipantInfo] = [
            userId: currentUserInfo,
            otherUserId: otherUserInfo
        ]
        
        let conversation = Conversation(
            id: conversationId,
            type: .direct,
            participantIds: participantIds,
            participants: participants,
            lastMessage: nil,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: nil
        )
        
        let localConversation = LocalConversation.from(conversation, syncStatus: .pending)
        try database.insert(localConversation)
        try database.save()
        
        return conversation
    }
    
    func createGroupConversation(
        creatorId: String,
        participantIds: [String],
        participantsInfo: [String: Conversation.ParticipantInfo],
        groupName: String?,
        groupImageUrl: String?
    ) async throws -> Conversation {
        let conversationId = UUID().uuidString
        
        let conversation = Conversation(
            id: conversationId,
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
        
        let localConversation = LocalConversation.from(conversation, syncStatus: .pending)
        try database.insert(localConversation)
        try database.save()
        
        return conversation
    }
    
    func updateLastMessage(conversationId: String, message: Message) async throws {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        guard let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        // Update denormalized last message fields
        localConversation.lastMessageText = message.text
        localConversation.lastMessageSenderId = message.senderId
        localConversation.lastMessageSenderName = message.senderName
        localConversation.lastMessageTimestamp = message.timestamp
        localConversation.updatedAt = Date()
        localConversation.syncStatus = .pending
        
        try database.update(localConversation)
        try database.save()
    }
    
    func updateGroupName(conversationId: String, groupName: String) async throws {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        guard let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        localConversation.groupName = groupName
        localConversation.updatedAt = Date()
        localConversation.syncStatus = .pending
        
        try database.update(localConversation)
        try database.save()
    }
    
    func addParticipant(
        conversationId: String,
        userId: String,
        userInfo: Conversation.ParticipantInfo
    ) async throws {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        guard let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        // Add participant ID if not already present
        if !localConversation.participantIds.contains(userId) {
            localConversation.participantIds.append(userId)
            localConversation.participantIds.sort()
        }
        
        // Add participant info
        var participants = localConversation.participants
        participants[userId] = userInfo
        
        // Re-encode participants
        if let encoded = try? JSONEncoder().encode(participants) {
            localConversation.participantsData = encoded
        }
        
        localConversation.updatedAt = Date()
        localConversation.syncStatus = .pending
        
        try database.update(localConversation)
        try database.save()
    }
    
    func removeParticipant(conversationId: String, userId: String) async throws {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        guard let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        // Remove participant ID
        localConversation.participantIds.removeAll { $0 == userId }
        
        // Remove participant info
        var participants = localConversation.participants
        participants.removeValue(forKey: userId)
        
        // Re-encode participants
        if let encoded = try? JSONEncoder().encode(participants) {
            localConversation.participantsData = encoded
        }
        
        localConversation.updatedAt = Date()
        localConversation.syncStatus = .pending
        
        try database.update(localConversation)
        try database.save()
    }
    
    func deleteConversation(conversationId: String) async throws {
        let predicate = #Predicate<LocalConversation> { conversation in
            conversation.id == conversationId
        }
        
        if let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) {
            try database.delete(localConversation)
            try database.save()
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: Error, LocalizedError {
    case notFound
    case invalidData
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Resource not found"
        case .invalidData:
            return "Invalid data"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}

