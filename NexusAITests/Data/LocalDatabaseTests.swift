//
//  LocalDatabaseTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
import SwiftData
@testable import NexusAI

@available(iOS 17.0, *)
@MainActor
final class LocalDatabaseTests: XCTestCase {
    
    var database: LocalDatabase!
    
    override func setUp() async throws {
        // Create in-memory database for testing
        database = try LocalDatabase(inMemory: true)
    }
    
    override func tearDown() async throws {
        database = nil
    }
    
    // MARK: - Insert Tests
    
    func testInsert_Message() throws {
        // Given
        let message = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello",
            timestamp: Date(),
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
        
        // When
        try database.insert(message)
        
        // Then
        let fetched = try database.fetch(LocalMessage.self)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, "msg123")
        XCTAssertEqual(fetched.first?.text, "Hello")
    }
    
    func testInsertBatch_MultipleMessages() throws {
        // Given
        let messages = [
            LocalMessage(
                id: "msg1",
                localId: "local1",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message 1",
                timestamp: Date(),
                status: .sent,
                readBy: [],
                deliveredTo: [],
                syncStatus: .synced,
                lastSyncAttempt: nil,
                syncRetryCount: 0,
                serverTimestamp: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            LocalMessage(
                id: "msg2",
                localId: "local2",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message 2",
                timestamp: Date(),
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
        ]
        
        // When
        try database.insertBatch(messages)
        
        // Then
        let fetched = try database.fetch(LocalMessage.self)
        XCTAssertEqual(fetched.count, 2)
    }
    
    // MARK: - Fetch Tests
    
    func testFetch_WithLimit() throws {
        // Given - Insert 5 messages
        for i in 1...5 {
            let message = LocalMessage(
                id: "msg\(i)",
                localId: "local\(i)",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message \(i)",
                timestamp: Date(),
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
            try database.insert(message)
        }
        
        // When
        let fetched = try database.fetch(LocalMessage.self, limit: 3)
        
        // Then
        XCTAssertEqual(fetched.count, 3)
    }
    
    func testFetch_WithPredicate() throws {
        // Given - Insert messages for different conversations
        let message1 = LocalMessage(
            id: "msg1",
            localId: "local1",
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 1",
            timestamp: Date(),
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
        
        let message2 = LocalMessage(
            id: "msg2",
            localId: "local2",
            conversationId: "conv2",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 2",
            timestamp: Date(),
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
        
        try database.insert(message1)
        try database.insert(message2)
        
        // When
        let fetched = try database.fetch(
            LocalMessage.self,
            where: #Predicate { $0.conversationId == "conv1" }
        )
        
        // Then
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.conversationId, "conv1")
    }
    
    func testFetchOne() throws {
        // Given
        let message = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello",
            timestamp: Date(),
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
        try database.insert(message)
        
        // When
        let fetched = try database.fetchOne(
            LocalMessage.self,
            where: #Predicate { $0.id == "msg123" }
        )
        
        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, "msg123")
    }
    
    func testFetchOne_NotFound() throws {
        // When
        let fetched = try database.fetchOne(
            LocalMessage.self,
            where: #Predicate { $0.id == "nonexistent" }
        )
        
        // Then
        XCTAssertNil(fetched)
    }
    
    // MARK: - Update Tests
    
    func testUpdate_Message() throws {
        // Given
        let message = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello",
            timestamp: Date(),
            status: .sent,
            readBy: ["user1"],
            deliveredTo: ["user1"],
            syncStatus: .pending,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try database.insert(message)
        
        // When - Update sync status
        message.syncStatus = .synced
        try database.update(message)
        
        // Then
        let fetched = try database.fetchOne(
            LocalMessage.self,
            where: #Predicate { $0.id == "msg123" }
        )
        XCTAssertEqual(fetched?.syncStatus, .synced)
    }
    
    // MARK: - Delete Tests
    
    func testDelete_Message() throws {
        // Given
        let message = LocalMessage(
            id: "msg123",
            localId: "local456",
            conversationId: "conv789",
            senderId: "user1",
            senderName: "Alice",
            text: "Hello",
            timestamp: Date(),
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
        try database.insert(message)
        
        // When
        try database.delete(message)
        
        // Then
        let fetched = try database.fetch(LocalMessage.self)
        XCTAssertEqual(fetched.count, 0)
    }
    
    func testDeleteBatch() throws {
        // Given
        let messages = [
            LocalMessage(
                id: "msg1",
                localId: "local1",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message 1",
                timestamp: Date(),
                status: .sent,
                readBy: [],
                deliveredTo: [],
                syncStatus: .synced,
                lastSyncAttempt: nil,
                syncRetryCount: 0,
                serverTimestamp: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            LocalMessage(
                id: "msg2",
                localId: "local2",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message 2",
                timestamp: Date(),
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
        ]
        try database.insertBatch(messages)
        
        // When
        try database.deleteBatch(messages)
        
        // Then
        let fetched = try database.fetch(LocalMessage.self)
        XCTAssertEqual(fetched.count, 0)
    }
    
    func testDeleteAll_WithPredicate() throws {
        // Given
        let message1 = LocalMessage(
            id: "msg1",
            localId: "local1",
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 1",
            timestamp: Date(),
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
        
        let message2 = LocalMessage(
            id: "msg2",
            localId: "local2",
            conversationId: "conv2",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 2",
            timestamp: Date(),
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
        
        try database.insert(message1)
        try database.insert(message2)
        
        // When
        try database.deleteAll(
            LocalMessage.self,
            where: #Predicate { $0.conversationId == "conv1" }
        )
        
        // Then
        let fetched = try database.fetch(LocalMessage.self)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.conversationId, "conv2")
    }
    
    // MARK: - Count Tests
    
    func testCount_AllEntities() throws {
        // Given
        for i in 1...5 {
            let message = LocalMessage(
                id: "msg\(i)",
                localId: "local\(i)",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Alice",
                text: "Message \(i)",
                timestamp: Date(),
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
            try database.insert(message)
        }
        
        // When
        let count = try database.count(LocalMessage.self)
        
        // Then
        XCTAssertEqual(count, 5)
    }
    
    func testCount_WithPredicate() throws {
        // Given
        let message1 = LocalMessage(
            id: "msg1",
            localId: "local1",
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 1",
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
        
        let message2 = LocalMessage(
            id: "msg2",
            localId: "local2",
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Alice",
            text: "Message 2",
            timestamp: Date(),
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
        
        try database.insert(message1)
        try database.insert(message2)
        
        // When
        let count = try database.count(
            LocalMessage.self,
            where: #Predicate { $0.syncStatusRaw == "pending" }
        )
        
        // Then
        XCTAssertEqual(count, 1)
    }
}

