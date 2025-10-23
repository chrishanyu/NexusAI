//
//  LocalMessageTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
@testable import NexusAI

@available(iOS 17.0, *)
final class LocalMessageTests: XCTestCase {
    
    // MARK: - Conversion Tests
    
    func testToMessage_ConvertsAllFieldsCorrectly() {
        // Given
        let localMessage = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello World",
            timestamp: Date(),
            status: .sent,
            readBy: ["user1"],
            deliveredTo: ["user1", "user2"],
            syncStatus: .synced,
            lastSyncAttempt: Date(),
            syncRetryCount: 0,
            serverTimestamp: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let message = localMessage.toMessage()
        
        // Then
        XCTAssertEqual(message.id, "msg123")
        XCTAssertEqual(message.localId, "local456")
        XCTAssertEqual(message.conversationId, "conv789")
        XCTAssertEqual(message.senderId, "user1")
        XCTAssertEqual(message.senderName, "Alice")
        XCTAssertEqual(message.text, "Hello World")
        XCTAssertEqual(message.status, .sent)
        XCTAssertEqual(message.readBy, ["user1"])
        XCTAssertEqual(message.deliveredTo, ["user1", "user2"])
    }
    
    func testFromMessage_ConvertsAllFieldsCorrectly() {
        // Given
        let timestamp = Date()
        let message = Message(
            id: "msg123",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello World",
            timestamp: timestamp,
            status: .delivered,
            readBy: ["user1"],
            deliveredTo: ["user1", "user2"],
            localId: "local456"
        )
        
        // When
        let localMessage = LocalMessage.from(message)
        
        // Then
        XCTAssertEqual(localMessage.id, "msg123")
        XCTAssertEqual(localMessage.localId, "local456")
        XCTAssertEqual(localMessage.conversationId, "conv789")
        XCTAssertEqual(localMessage.senderId, "user1")
        XCTAssertEqual(localMessage.senderName, "Alice")
        XCTAssertEqual(localMessage.text, "Hello World")
        XCTAssertEqual(localMessage.status, .delivered)
        XCTAssertEqual(localMessage.readBy, ["user1"])
        XCTAssertEqual(localMessage.deliveredTo, ["user1", "user2"])
        XCTAssertEqual(localMessage.syncStatus, .synced)
        XCTAssertEqual(localMessage.syncRetryCount, 0)
        XCTAssertNil(localMessage.lastSyncAttempt)
    }
    
    func testFromMessage_WithPendingSyncStatus() {
        // Given
        let message = Message(
            id: nil,
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello",
            timestamp: Date(),
            status: .sending,
            readBy: ["user1"],
            deliveredTo: [],
            localId: "local123"
        )
        
        // When
        let localMessage = LocalMessage.from(message, syncStatus: .pending)
        
        // Then
        XCTAssertEqual(localMessage.syncStatus, .pending)
        XCTAssertEqual(localMessage.status, .sending)
        XCTAssertNotNil(localMessage.id) // Should generate UUID
        XCTAssertEqual(localMessage.localId, "local123")
    }
    
    func testUpdate_UpdatesOnlyModifiableFields() {
        // Given
        let originalTimestamp = Date()
        let localMessage = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Original",
            timestamp: originalTimestamp,
            status: .sent,
            readBy: ["user1"],
            deliveredTo: ["user1"],
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let updatedMessage = Message(
            id: "msg123",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Updated", // Text doesn't update (immutable)
            timestamp: Date(),
            status: .read,
            readBy: ["user1", "user2"],
            deliveredTo: ["user1", "user2"],
            localId: "local456"
        )
        
        // When
        localMessage.update(from: updatedMessage)
        
        // Then
        XCTAssertEqual(localMessage.id, "msg123") // Unchanged
        XCTAssertEqual(localMessage.localId, "local456") // Unchanged
        XCTAssertEqual(localMessage.status, .read) // Updated
        XCTAssertEqual(localMessage.readBy, ["user1", "user2"]) // Updated
        XCTAssertEqual(localMessage.deliveredTo, ["user1", "user2"]) // Updated
    }
    
    func testSyncStatusComputedProperty() {
        // Given
        let localMessage = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Test",
            timestamp: Date(),
            status: .sent,
            readBy: [],
            deliveredTo: [],
            syncStatus: .pending,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When/Then
        XCTAssertEqual(localMessage.syncStatus, .pending)
        
        // When - Update sync status
        localMessage.syncStatus = .synced
        
        // Then
        XCTAssertEqual(localMessage.syncStatus, .synced)
        XCTAssertEqual(localMessage.syncStatusRaw, "synced")
    }
    
    func testStatusComputedProperty() {
        // Given
        let localMessage = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Test",
            timestamp: Date(),
            status: .sending,
            readBy: [],
            deliveredTo: [],
            syncStatus: .pending,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When/Then
        XCTAssertEqual(localMessage.status, .sending)
        
        // When - Update status
        localMessage.status = .delivered
        
        // Then
        XCTAssertEqual(localMessage.status, .delivered)
        XCTAssertEqual(localMessage.statusRaw, "delivered")
    }
    
    func testRoundTripConversion() {
        // Given
        let originalMessage = Message(
            id: "msg123",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello World",
            timestamp: Date(),
            status: .delivered,
            readBy: ["user1"],
            deliveredTo: ["user1", "user2"],
            localId: "local456"
        )
        
        // When - Convert to LocalMessage and back
        let localMessage = LocalMessage.from(originalMessage)
        let convertedMessage = localMessage.toMessage()
        
        // Then - Should match original
        XCTAssertEqual(convertedMessage.id, originalMessage.id)
        XCTAssertEqual(convertedMessage.conversationId, originalMessage.conversationId)
        XCTAssertEqual(convertedMessage.senderId, originalMessage.senderId)
        XCTAssertEqual(convertedMessage.senderName, originalMessage.senderName)
        XCTAssertEqual(convertedMessage.text, originalMessage.text)
        XCTAssertEqual(convertedMessage.status, originalMessage.status)
        XCTAssertEqual(convertedMessage.readBy, originalMessage.readBy)
        XCTAssertEqual(convertedMessage.deliveredTo, originalMessage.deliveredTo)
        XCTAssertEqual(convertedMessage.localId, originalMessage.localId)
    }
}

