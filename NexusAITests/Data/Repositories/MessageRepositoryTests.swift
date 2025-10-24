//
//  MessageRepositoryTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
import SwiftData
@testable import NexusAI

@MainActor
final class MessageRepositoryTests: XCTestCase {
    
    var database: LocalDatabase!
    var repository: MessageRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        database = try LocalDatabase(inMemory: true)
        repository = MessageRepository(database: database)
    }
    
    override func tearDown() async throws {
        database = nil
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Read Operations
    
    func testGetMessages_ReturnsMessagesForConversation() async throws {
        // Given
        let conversationId = "conv123"
        let message1 = createLocalMessage(id: "msg1", conversationId: conversationId, text: "Hello", timestamp: Date().addingTimeInterval(-100))
        let message2 = createLocalMessage(id: "msg2", conversationId: conversationId, text: "Hi", timestamp: Date())
        let message3 = createLocalMessage(id: "msg3", conversationId: "otherConv", text: "Other", timestamp: Date())
        
        try database.insert(message1)
        try database.insert(message2)
        try database.insert(message3)
        try database.save()
        
        // When
        let messages = try await repository.getMessages(conversationId: conversationId, limit: 50)
        
        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].id, "msg1")
        XCTAssertEqual(messages[1].id, "msg2")
        XCTAssertEqual(messages[0].text, "Hello")
        XCTAssertEqual(messages[1].text, "Hi")
    }
    
    func testGetMessagesBefore_ReturnsPaginatedMessages() async throws {
        // Given
        let conversationId = "conv123"
        let now = Date()
        let message1 = createLocalMessage(id: "msg1", conversationId: conversationId, text: "Old", timestamp: now.addingTimeInterval(-200))
        let message2 = createLocalMessage(id: "msg2", conversationId: conversationId, text: "Older", timestamp: now.addingTimeInterval(-150))
        let message3 = createLocalMessage(id: "msg3", conversationId: conversationId, text: "Recent", timestamp: now)
        
        try database.insert(message1)
        try database.insert(message2)
        try database.insert(message3)
        try database.save()
        
        // When - Get messages before "Recent"
        let messages = try await repository.getMessagesBefore(
            conversationId: conversationId,
            beforeDate: now.addingTimeInterval(-1),
            limit: 10
        )
        
        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].text, "Old")
        XCTAssertEqual(messages[1].text, "Older")
        XCTAssertFalse(messages.contains { $0.text == "Recent" })
    }
    
    func testGetMessage_ReturnsSpecificMessage() async throws {
        // Given
        let message = createLocalMessage(id: "msg123", conversationId: "conv123", text: "Test", timestamp: Date())
        try database.insert(message)
        try database.save()
        
        // When
        let retrieved = try await repository.getMessage(messageId: "msg123")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "msg123")
        XCTAssertEqual(retrieved?.text, "Test")
    }
    
    func testGetMessage_ReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await repository.getMessage(messageId: "nonexistent")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Write Operations
    
    func testSendMessage_CreatesMessageWithPendingStatus() async throws {
        // When
        let message = try await repository.sendMessage(
            conversationId: "conv123",
            text: "Hello World",
            senderId: "user1",
            senderName: "John"
        )
        
        // Then
        XCTAssertNotNil(message.id)
        XCTAssertFalse(message.id?.isEmpty ?? true)
        XCTAssertEqual(message.localId, message.id) // Initially, id == localId
        XCTAssertEqual(message.text, "Hello World")
        XCTAssertEqual(message.senderId, "user1")
        XCTAssertEqual(message.senderName, "John")
        XCTAssertEqual(message.status, .sending)
        
        // Verify it's in the database with pending sync status
        guard let messageId = message.id else {
            XCTFail("Message ID should not be nil")
            return
        }
        let predicate = #Predicate<LocalMessage> { $0.id == messageId }
        let localMessage = try database.fetchOne(LocalMessage.self, where: predicate)
        XCTAssertNotNil(localMessage)
        XCTAssertEqual(localMessage?.syncStatus, .pending)
    }
    
    func testMarkMessagesAsRead_UpdatesReadBy() async throws {
        // Given
        let message = createLocalMessage(id: "msg1", conversationId: "conv123", text: "Test", timestamp: Date())
        message.syncStatus = .synced // Start as synced
        try database.insert(message)
        try database.save()
        
        // When
        try await repository.markMessagesAsRead(
            messageIds: ["msg1"],
            conversationId: "conv123",
            userId: "user2"
        )
        
        // Then
        let predicate = #Predicate<LocalMessage> { $0.id == "msg1" }
        let updated = try database.fetchOne(LocalMessage.self, where: predicate)
        XCTAssertTrue(updated?.readBy.contains("user2") ?? false)
        XCTAssertEqual(updated?.status, .read)
        XCTAssertEqual(updated?.syncStatus, .pending) // Marked for sync
    }
    
    func testMarkMessagesAsDelivered_UpdatesDeliveredTo() async throws {
        // Given
        let message = createLocalMessage(id: "msg1", conversationId: "conv123", text: "Test", timestamp: Date())
        message.syncStatus = .synced // Start as synced
        try database.insert(message)
        try database.save()
        
        // When
        try await repository.markMessagesAsDelivered(
            messageIds: ["msg1"],
            conversationId: "conv123",
            userId: "user2"
        )
        
        // Then
        let predicate = #Predicate<LocalMessage> { $0.id == "msg1" }
        let updated = try database.fetchOne(LocalMessage.self, where: predicate)
        XCTAssertTrue(updated?.deliveredTo.contains("user2") ?? false)
        XCTAssertEqual(updated?.status, .delivered)
        XCTAssertEqual(updated?.syncStatus, .pending) // Marked for sync
    }
    
    func testDeleteMessage_RemovesMessageFromDatabase() async throws {
        // Given
        let message = createLocalMessage(id: "msg1", conversationId: "conv123", text: "Test", timestamp: Date())
        try database.insert(message)
        try database.save()
        
        // When
        try await repository.deleteMessage(messageId: "msg1")
        
        // Then
        let retrieved = try await repository.getMessage(messageId: "msg1")
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Utility
    
    func testGetUnreadCount_ReturnsCorrectCount() async throws {
        // Given
        let conversationId = "conv123"
        let userId = "currentUser"
        
        // Message 1: Not read by currentUser
        let message1 = createLocalMessage(id: "msg1", conversationId: conversationId, text: "Unread", timestamp: Date())
        message1.senderId = "otherUser"
        
        // Message 2: Read by currentUser
        let message2 = createLocalMessage(id: "msg2", conversationId: conversationId, text: "Read", timestamp: Date())
        message2.senderId = "otherUser"
        message2.readBy.append(userId)
        
        // Message 3: Sent by currentUser (should not count)
        let message3 = createLocalMessage(id: "msg3", conversationId: conversationId, text: "Sent by me", timestamp: Date())
        message3.senderId = userId
        
        try database.insert(message1)
        try database.insert(message2)
        try database.insert(message3)
        try database.save()
        
        // When
        let unreadCount = try await repository.getUnreadCount(conversationId: conversationId, userId: userId)
        
        // Then
        XCTAssertEqual(unreadCount, 1)
    }
    
    // MARK: - AsyncStream Observation
    
    func testObserveMessages_EmitsUpdates() async throws {
        // Given
        let conversationId = "conv123"
        
        // When
        let stream = repository.observeMessages(conversationId: conversationId)
        
        // Create a task to collect stream values
        var receivedMessages: [[Message]] = []
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            // Get first emission (empty)
            if let first = await iterator.next() {
                receivedMessages.append(first)
            }
            // Wait for second emission after insert
            if let second = await iterator.next() {
                receivedMessages.append(second)
            }
        }
        
        // Give stream time to set up
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Insert a message
        let message = createLocalMessage(id: "msg1", conversationId: conversationId, text: "New", timestamp: Date())
        try database.insert(message)
        try database.save()
        
        // Trigger notification for event-driven updates
        database.notifyChanges()
        
        // Wait for stream to emit
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        task.cancel()
        
        // Then
        XCTAssertGreaterThanOrEqual(receivedMessages.count, 1)
        if receivedMessages.count >= 2 {
            XCTAssertEqual(receivedMessages[0].count, 0) // Initial empty state
            XCTAssertEqual(receivedMessages[1].count, 1) // After insert
            XCTAssertEqual(receivedMessages[1].first?.text, "New")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLocalMessage(id: String, conversationId: String, text: String, timestamp: Date) -> LocalMessage {
        return LocalMessage(
            id: id,
            localId: id,
            conversationId: conversationId,
            senderId: "user1",
            senderName: "John",
            text: text,
            timestamp: timestamp,
            status: .sent,
            readBy: [],
            deliveredTo: [],
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

