//
//  LocalConversationTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
@testable import NexusAI

@available(iOS 17.0, *)
final class LocalConversationTests: XCTestCase {
    
    // MARK: - Test Data
    
    private var testParticipants: [String: Conversation.ParticipantInfo] {
        return [
            "user1": Conversation.ParticipantInfo(displayName: "Alice", profileImageUrl: "https://example.com/alice.jpg"),
            "user2": Conversation.ParticipantInfo(displayName: "Bob", profileImageUrl: nil)
        ]
    }
    
    private var testLastMessage: Conversation.LastMessage {
        return Conversation.LastMessage(
            text: "Hello",
            senderId: "user1",
            senderName: "Alice",
            timestamp: Date()
        )
    }
    
    // MARK: - Conversion Tests
    
    func testToConversation_DirectConversation() {
        // Given
        let localConversation = LocalConversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: testLastMessage,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let conversation = localConversation.toConversation()
        
        // Then
        XCTAssertEqual(conversation.id, "conv123")
        XCTAssertEqual(conversation.type, .direct)
        XCTAssertEqual(conversation.participantIds, ["user1", "user2"])
        XCTAssertEqual(conversation.participants.count, 2)
        XCTAssertEqual(conversation.participants["user1"]?.displayName, "Alice")
        XCTAssertEqual(conversation.participants["user2"]?.displayName, "Bob")
        XCTAssertNil(conversation.groupName)
        XCTAssertNotNil(conversation.lastMessage)
        XCTAssertEqual(conversation.lastMessage?.text, "Hello")
    }
    
    func testToConversation_GroupConversation() {
        // Given
        let localConversation = LocalConversation(
            id: "conv456",
            type: .group,
            participantIds: ["user1", "user2", "user3"],
            participants: testParticipants,
            groupName: "Team Chat",
            groupImageUrl: "https://example.com/group.jpg",
            createdBy: "user1",
            lastMessage: testLastMessage,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let conversation = localConversation.toConversation()
        
        // Then
        XCTAssertEqual(conversation.type, .group)
        XCTAssertEqual(conversation.groupName, "Team Chat")
        XCTAssertEqual(conversation.groupImageUrl, "https://example.com/group.jpg")
        XCTAssertEqual(conversation.participantIds.count, 3)
    }
    
    func testFromConversation_ConvertsAllFields() {
        // Given
        let conversation = Conversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            lastMessage: testLastMessage,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let localConversation = LocalConversation.from(conversation)
        
        // Then
        XCTAssertEqual(localConversation.id, "conv123")
        XCTAssertEqual(localConversation.type, .direct)
        XCTAssertEqual(localConversation.participantIds, ["user1", "user2"])
        XCTAssertEqual(localConversation.participants.count, 2)
        XCTAssertEqual(localConversation.syncStatus, .synced)
        XCTAssertEqual(localConversation.syncRetryCount, 0)
        XCTAssertNotNil(localConversation.lastMessageText)
        XCTAssertEqual(localConversation.lastMessageText, "Hello")
    }
    
    func testParticipantsComputedProperty() {
        // Given
        let localConversation = LocalConversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: nil,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let participants = localConversation.participants
        
        // Then
        XCTAssertEqual(participants.count, 2)
        XCTAssertEqual(participants["user1"]?.displayName, "Alice")
        XCTAssertEqual(participants["user2"]?.displayName, "Bob")
    }
    
    func testLastMessageComputedProperty() {
        // Given
        let localConversation = LocalConversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: testLastMessage,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let lastMessage = localConversation.lastMessage
        
        // Then
        XCTAssertNotNil(lastMessage)
        XCTAssertEqual(lastMessage?.text, "Hello")
        XCTAssertEqual(lastMessage?.senderId, "user1")
        XCTAssertEqual(lastMessage?.senderName, "Alice")
    }
    
    func testLastMessageComputedProperty_WhenNil() {
        // Given
        let localConversation = LocalConversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: nil,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let lastMessage = localConversation.lastMessage
        
        // Then
        XCTAssertNil(lastMessage)
    }
    
    func testUpdate_UpdatesAllModifiableFields() {
        // Given
        let localConversation = LocalConversation(
            id: "conv123",
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: nil,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let updatedConversation = Conversation(
            id: "conv123",
            type: .group,
            participantIds: ["user1", "user2", "user3"],
            participants: testParticipants,
            lastMessage: testLastMessage,
            groupName: "New Group",
            groupImageUrl: "https://example.com/new.jpg",
            createdBy: "user1",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        localConversation.update(from: updatedConversation)
        
        // Then
        XCTAssertEqual(localConversation.type, .group)
        XCTAssertEqual(localConversation.participantIds.count, 3)
        XCTAssertEqual(localConversation.groupName, "New Group")
        XCTAssertEqual(localConversation.groupImageUrl, "https://example.com/new.jpg")
        XCTAssertNotNil(localConversation.lastMessage)
    }
    
    func testRoundTripConversion() {
        // Given
        let originalConversation = Conversation(
            id: "conv123",
            type: .group,
            participantIds: ["user1", "user2"],
            participants: testParticipants,
            lastMessage: testLastMessage,
            groupName: "Test Group",
            groupImageUrl: "https://example.com/test.jpg",
            createdBy: "user1",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let localConversation = LocalConversation.from(originalConversation)
        let convertedConversation = localConversation.toConversation()
        
        // Then
        XCTAssertEqual(convertedConversation.id, originalConversation.id)
        XCTAssertEqual(convertedConversation.type, originalConversation.type)
        XCTAssertEqual(convertedConversation.participantIds, originalConversation.participantIds)
        XCTAssertEqual(convertedConversation.groupName, originalConversation.groupName)
        XCTAssertEqual(convertedConversation.groupImageUrl, originalConversation.groupImageUrl)
        XCTAssertEqual(convertedConversation.lastMessage?.text, originalConversation.lastMessage?.text)
    }
}

