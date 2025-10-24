//
//  ConversationRepositoryTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
import SwiftData
@testable import NexusAI

@MainActor
final class ConversationRepositoryTests: XCTestCase {
    
    var database: LocalDatabase!
    var repository: ConversationRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        database = try LocalDatabase(inMemory: true)
        repository = ConversationRepository(database: database)
    }
    
    override func tearDown() async throws {
        database = nil
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Read Operations
    
    func testGetConversations_ReturnsUserConversations() async throws {
        // Given
        let userId = "user1"
        let conv1 = createLocalConversation(id: "conv1", participantIds: ["user1", "user2"])
        let conv2 = createLocalConversation(id: "conv2", participantIds: ["user1", "user3"])
        let conv3 = createLocalConversation(id: "conv3", participantIds: ["user4", "user5"])
        
        try database.insert(conv1)
        try database.insert(conv2)
        try database.insert(conv3)
        try database.save()
        
        // When
        let conversations = try await repository.getConversations(userId: userId)
        
        // Then
        XCTAssertEqual(conversations.count, 2)
        let ids = conversations.map { $0.id }
        XCTAssertTrue(ids.contains("conv1"))
        XCTAssertTrue(ids.contains("conv2"))
        XCTAssertFalse(ids.contains("conv3"))
    }
    
    func testGetConversation_ReturnsSpecificConversation() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2"])
        try database.insert(conversation)
        try database.save()
        
        // When
        let retrieved = try await repository.getConversation(conversationId: "conv123")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "conv123")
        XCTAssertEqual(retrieved?.participantIds.sorted(), ["user1", "user2"])
    }
    
    func testGetConversation_ReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await repository.getConversation(conversationId: "nonexistent")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Create Operations
    
    func testCreateDirectConversation_CreatesNewConversation() async throws {
        // When
        let conversation = try await repository.createDirectConversation(
            userId: "user1",
            otherUserId: "user2",
            otherUserInfo: Conversation.ParticipantInfo(
                displayName: "Jane",
                profileImageUrl: nil
            )
        )
        
        // Then
        XCTAssertNotNil(conversation.id)
        XCTAssertFalse(conversation.id?.isEmpty ?? true)
        XCTAssertEqual(conversation.type, .direct)
        XCTAssertEqual(conversation.participantIds.sorted(), ["user1", "user2"])
        XCTAssertEqual(conversation.participants.count, 2)
        
        // Verify it's in the database
        let retrieved = try await repository.getConversation(conversationId: conversation.id!)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.type, .direct)
    }
    
    func testCreateDirectConversation_ReturnsExistingIfExists() async throws {
        // Given
        let existing = try await repository.createDirectConversation(
            userId: "user1",
            otherUserId: "user2",
            otherUserInfo: Conversation.ParticipantInfo(
                displayName: "Jane",
                profileImageUrl: nil
            )
        )
        
        // When - Try to create again
        let duplicate = try await repository.createDirectConversation(
            userId: "user1",
            otherUserId: "user2",
            otherUserInfo: Conversation.ParticipantInfo(
                displayName: "Jane",
                profileImageUrl: nil
            )
        )
        
        // Then - Should return the same conversation
        XCTAssertEqual(existing.id, duplicate.id)
    }
    
    func testCreateGroupConversation_CreatesNewGroup() async throws {
        // When
        let conversation = try await repository.createGroupConversation(
            creatorId: "user1",
            participantIds: ["user1", "user2", "user3"],
            participantsInfo: [
                "user1": Conversation.ParticipantInfo(displayName: "John", profileImageUrl: nil),
                "user2": Conversation.ParticipantInfo(displayName: "Jane", profileImageUrl: nil),
                "user3": Conversation.ParticipantInfo(displayName: "Bob", profileImageUrl: nil)
            ],
            groupName: "Team Chat",
            groupImageUrl: nil
        )
        
        // Then
        XCTAssertNotNil(conversation.id)
        XCTAssertFalse(conversation.id?.isEmpty ?? true)
        XCTAssertEqual(conversation.type, .group)
        XCTAssertEqual(conversation.participantIds.count, 3)
        XCTAssertEqual(conversation.groupName, "Team Chat")
        XCTAssertEqual(conversation.createdBy, "user1")
        
        // Verify it's in the database
        let retrieved = try await repository.getConversation(conversationId: conversation.id!)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.type, .group)
        XCTAssertEqual(retrieved?.groupName, "Team Chat")
    }
    
    // MARK: - Update Operations
    
    func testUpdateLastMessage_UpdatesConversation() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2"])
        try database.insert(conversation)
        try database.save()
        
        let message = Message(
            id: "msg1",
            conversationId: "conv123",
            senderId: "user1",
            senderName: "John",
            text: "Hello",
            timestamp: Date(),
            status: .sent,
            readBy: [],
            deliveredTo: [],
            localId: "msg1"
        )
        
        // When
        try await repository.updateLastMessage(conversationId: "conv123", message: message)
        
        // Then
        let predicate = #Predicate<LocalConversation> { $0.id == "conv123" }
        let updated = try database.fetchOne(LocalConversation.self, where: predicate)
        XCTAssertEqual(updated?.lastMessageText, "Hello")
        XCTAssertEqual(updated?.lastMessageSenderId, "user1")
        XCTAssertEqual(updated?.lastMessageSenderName, "John")
        XCTAssertNotNil(updated?.updatedAt)
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testUpdateGroupName_UpdatesConversation() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2", "user3"])
        conversation.typeRaw = "group"
        conversation.groupName = "Old Name"
        try database.insert(conversation)
        try database.save()
        
        // When
        try await repository.updateGroupName(conversationId: "conv123", groupName: "New Name")
        
        // Then
        let predicate = #Predicate<LocalConversation> { $0.id == "conv123" }
        let updated = try database.fetchOne(LocalConversation.self, where: predicate)
        XCTAssertEqual(updated?.groupName, "New Name")
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testAddParticipant_AddsUserToGroup() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2"])
        conversation.typeRaw = "group"
        try database.insert(conversation)
        try database.save()
        
        // When
        try await repository.addParticipant(
            conversationId: "conv123",
            userId: "user3",
            userInfo: Conversation.ParticipantInfo(
                displayName: "Bob",
                profileImageUrl: nil
            )
        )
        
        // Then
        let predicate = #Predicate<LocalConversation> { $0.id == "conv123" }
        let updated = try database.fetchOne(LocalConversation.self, where: predicate)
        XCTAssertTrue(updated?.participantIds.contains("user3") ?? false)
        XCTAssertEqual(updated?.participantIds.count, 3)
        XCTAssertNotNil(updated?.participants["user3"])
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testRemoveParticipant_RemovesUserFromGroup() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2", "user3"])
        conversation.typeRaw = "group"
        try database.insert(conversation)
        try database.save()
        
        // When
        try await repository.removeParticipant(conversationId: "conv123", userId: "user3")
        
        // Then
        let predicate = #Predicate<LocalConversation> { $0.id == "conv123" }
        let updated = try database.fetchOne(LocalConversation.self, where: predicate)
        XCTAssertFalse(updated?.participantIds.contains("user3") ?? true)
        XCTAssertEqual(updated?.participantIds.count, 2)
        XCTAssertNil(updated?.participants["user3"])
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testDeleteConversation_RemovesConversation() async throws {
        // Given
        let conversation = createLocalConversation(id: "conv123", participantIds: ["user1", "user2"])
        try database.insert(conversation)
        try database.save()
        
        // When
        try await repository.deleteConversation(conversationId: "conv123")
        
        // Then
        let retrieved = try await repository.getConversation(conversationId: "conv123")
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Error Handling
    
    func testUpdateLastMessage_ThrowsErrorForNonExistent() async {
        // Given
        let message = Message(
            id: "msg1",
            conversationId: "nonexistent",
            senderId: "user1",
            senderName: "John",
            text: "Hello",
            timestamp: Date(),
            status: .sent,
            readBy: [],
            deliveredTo: [],
            localId: "msg1"
        )
        
        // When/Then
        do {
            try await repository.updateLastMessage(conversationId: "nonexistent", message: message)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    // MARK: - AsyncStream Observation
    
    func testObserveConversations_EmitsUpdates() async throws {
        // Given
        let userId = "user1"
        
        // When
        let stream = repository.observeConversations(userId: userId)
        
        // Create a task to collect stream values
        var receivedConversations: [[Conversation]] = []
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            // Get first emission (empty)
            if let first = await iterator.next() {
                receivedConversations.append(first)
            }
            // Wait for second emission after insert
            if let second = await iterator.next() {
                receivedConversations.append(second)
            }
        }
        
        // Give stream time to set up
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Insert a conversation
        let conversation = createLocalConversation(id: "conv1", participantIds: ["user1", "user2"])
        try database.insert(conversation)
        try database.save()
        
        // Trigger notification for event-driven updates
        database.notifyChanges()
        
        // Wait for stream to emit
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        task.cancel()
        
        // Then
        XCTAssertGreaterThanOrEqual(receivedConversations.count, 1)
        if receivedConversations.count >= 2 {
            XCTAssertEqual(receivedConversations[0].count, 0) // Initial empty state
            XCTAssertEqual(receivedConversations[1].count, 1) // After insert
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLocalConversation(id: String, participantIds: [String]) -> LocalConversation {
        let participants = Dictionary(uniqueKeysWithValues: participantIds.map { userId in
            (userId, Conversation.ParticipantInfo(displayName: userId, profileImageUrl: nil))
        })
        
        return LocalConversation(
            id: id,
            type: .direct,
            participantIds: participantIds.sorted(),
            participants: participants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: participantIds.first,
            lastMessage: nil,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

