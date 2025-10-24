//
//  ConflictResolverTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
@testable import NexusAI

@available(iOS 17.0, *)
final class ConflictResolverTests: XCTestCase {
    
    var resolver: ConflictResolver!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        resolver = ConflictResolver()
    }
    
    @MainActor
    override func tearDown() async throws {
        resolver = nil
        try await super.tearDown()
    }
    
    // MARK: - Message Resolution Tests
    
    func testResolveMessage_RemoteNewer_UsesRemote() {
        // Given: Local message is older
        let localMessage = createLocalMessage(
            id: "msg1",
            text: "Local version",
            timestamp: Date(timeIntervalSince1970: 1000),
            serverTimestamp: Date(timeIntervalSince1970: 1000)
        )
        
        let remoteMessage = createRemoteMessage(
            id: "msg1",
            text: "Remote version",
            timestamp: Date(timeIntervalSince1970: 2000)
        )
        
        // When
        let result = resolver.resolveMessage(local: localMessage, remote: remoteMessage)
        
        // Then
        XCTAssertTrue(result.isRemoteWinner)
        XCTAssertEqual(result.resolved.text, "Remote version")
        XCTAssertEqual(result.resolved.syncStatus, .synced)
    }
    
    func testResolveMessage_LocalNewer_UsesLocal() {
        // Given: Local message is newer
        let localMessage = createLocalMessage(
            id: "msg1",
            text: "Local version",
            timestamp: Date(timeIntervalSince1970: 2000),
            serverTimestamp: Date(timeIntervalSince1970: 2000)
        )
        
        let remoteMessage = createRemoteMessage(
            id: "msg1",
            text: "Remote version",
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        
        // When
        let result = resolver.resolveMessage(local: localMessage, remote: remoteMessage)
        
        // Then
        XCTAssertTrue(result.isLocalWinner)
        XCTAssertEqual(result.resolved.text, "Local version")
        XCTAssertEqual(result.resolved.syncStatus, .pending) // Marked for sync back
    }
    
    func testResolveMessage_EqualTimestamps_UsesRemote() {
        // Given: Same timestamps
        let timestamp = Date(timeIntervalSince1970: 1000)
        let localMessage = createLocalMessage(
            id: "msg1",
            text: "Local version",
            timestamp: timestamp,
            serverTimestamp: timestamp
        )
        
        let remoteMessage = createRemoteMessage(
            id: "msg1",
            text: "Remote version",
            timestamp: timestamp
        )
        
        // When
        let result = resolver.resolveMessage(local: localMessage, remote: remoteMessage)
        
        // Then
        XCTAssertTrue(result.isRemoteWinner) // Remote wins on tie
        XCTAssertEqual(result.resolved.text, "Remote version")
        XCTAssertEqual(result.resolved.syncStatus, .synced)
    }
    
    func testResolveMessage_NoServerTimestamp_UsesLocalTimestamp() {
        // Given: Local has no serverTimestamp yet (newly created)
        let localMessage = createLocalMessage(
            id: "msg1",
            text: "Local version",
            timestamp: Date(timeIntervalSince1970: 2000),
            serverTimestamp: nil
        )
        
        let remoteMessage = createRemoteMessage(
            id: "msg1",
            text: "Remote version",
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        
        // When
        let result = resolver.resolveMessage(local: localMessage, remote: remoteMessage)
        
        // Then
        XCTAssertTrue(result.isLocalWinner)
        XCTAssertEqual(result.resolved.text, "Local version")
    }
    
    // MARK: - Conversation Resolution Tests
    
    func testResolveConversation_RemoteNewer_UsesRemote() {
        // Given: Remote conversation is newer
        let localConversation = createLocalConversation(
            id: "conv1",
            lastMessageText: "Local last message",
            updatedAt: Date(timeIntervalSince1970: 1000),
            serverTimestamp: Date(timeIntervalSince1970: 1000)
        )
        
        let remoteConversation = createRemoteConversation(
            id: "conv1",
            lastMessageText: "Remote last message",
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
        
        // When
        let result = resolver.resolveConversation(local: localConversation, remote: remoteConversation)
        
        // Then
        XCTAssertTrue(result.isRemoteWinner)
        XCTAssertEqual(result.resolved.lastMessageText, "Remote last message")
        XCTAssertEqual(result.resolved.syncStatus, .synced)
    }
    
    func testResolveConversation_LocalNewer_UsesLocal() {
        // Given: Local conversation is newer
        let localConversation = createLocalConversation(
            id: "conv1",
            lastMessageText: "Local last message",
            updatedAt: Date(timeIntervalSince1970: 2000),
            serverTimestamp: Date(timeIntervalSince1970: 2000)
        )
        
        let remoteConversation = createRemoteConversation(
            id: "conv1",
            lastMessageText: "Remote last message",
            updatedAt: Date(timeIntervalSince1970: 1000)
        )
        
        // When
        let result = resolver.resolveConversation(local: localConversation, remote: remoteConversation)
        
        // Then
        XCTAssertTrue(result.isLocalWinner)
        XCTAssertEqual(result.resolved.lastMessageText, "Local last message")
        XCTAssertEqual(result.resolved.syncStatus, .pending)
    }
    
    func testResolveConversation_NoUpdatedAt_FallsBackToCreatedAt() {
        // Given: No updatedAt, compare createdAt
        let localConversation = createLocalConversation(
            id: "conv1",
            lastMessageText: "Local",
            createdAt: Date(timeIntervalSince1970: 2000),
            updatedAt: nil,
            serverTimestamp: nil
        )
        
        let remoteConversation = createRemoteConversation(
            id: "conv1",
            lastMessageText: "Remote",
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: nil
        )
        
        // When
        let result = resolver.resolveConversation(local: localConversation, remote: remoteConversation)
        
        // Then
        XCTAssertTrue(result.isLocalWinner)
        XCTAssertEqual(result.resolved.lastMessageText, "Local")
    }
    
    // MARK: - User Resolution Tests
    
    func testResolveUser_AlwaysUsesRemotePresence() {
        // Given: Different presence states
        let localUser = createLocalUser(
            id: "user1",
            displayName: "Local Name",
            isOnline: false,
            lastSeen: Date(timeIntervalSince1970: 1000)
        )
        
        let remoteUser = createRemoteUser(
            id: "user1",
            displayName: "Remote Name",
            isOnline: true,
            lastSeen: Date(timeIntervalSince1970: 2000)
        )
        
        // When
        let result = resolver.resolveUser(local: localUser, remote: remoteUser)
        
        // Then
        XCTAssertTrue(result.resolved.isOnline) // Always use remote presence
        XCTAssertEqual(result.resolved.lastSeen.timeIntervalSince1970, 2000)
    }
    
    func testResolveUser_LocalProfileNewer_KeepsLocalProfile() {
        // Given: Local profile is newer
        let localUser = createLocalUser(
            id: "user1",
            displayName: "New Local Name",
            createdAt: Date(timeIntervalSince1970: 1000),
            serverTimestamp: Date(timeIntervalSince1970: 2000)
        )
        localUser.profileImageUrl = "local-image.jpg"
        
        let remoteUser = createRemoteUser(
            id: "user1",
            displayName: "Old Remote Name",
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        
        // When
        let result = resolver.resolveUser(local: localUser, remote: remoteUser)
        
        // Then
        XCTAssertTrue(result.isLocalWinner)
        XCTAssertEqual(result.resolved.displayName, "New Local Name") // Local profile wins
        XCTAssertEqual(result.resolved.profileImageUrl, "local-image.jpg")
        XCTAssertEqual(result.resolved.syncStatus, .pending) // Need to sync back
    }
    
    func testResolveUser_RemoteProfileNewer_UsesRemoteProfile() {
        // Given: Remote profile is newer
        let localUser = createLocalUser(
            id: "user1",
            displayName: "Old Local Name",
            createdAt: Date(timeIntervalSince1970: 1000),
            serverTimestamp: Date(timeIntervalSince1970: 1000)
        )
        
        let remoteUser = createRemoteUser(
            id: "user1",
            displayName: "New Remote Name",
            createdAt: Date(timeIntervalSince1970: 2000)
        )
        
        // When
        let result = resolver.resolveUser(local: localUser, remote: remoteUser)
        
        // Then
        XCTAssertTrue(result.isRemoteWinner)
        XCTAssertEqual(result.resolved.displayName, "New Remote Name")
        XCTAssertEqual(result.resolved.syncStatus, .synced)
    }
    
    // MARK: - Helper Methods
    
    private func createLocalMessage(
        id: String,
        text: String,
        timestamp: Date,
        serverTimestamp: Date?
    ) -> LocalMessage {
        let message = LocalMessage(
            id: id,
            localId: UUID().uuidString,
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Test User",
            text: text,
            timestamp: timestamp,
            status: .sent,
            readBy: [],
            deliveredTo: [],
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: serverTimestamp,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return message
    }
    
    private func createRemoteMessage(
        id: String,
        text: String,
        timestamp: Date
    ) -> Message {
        return Message(
            id: id,
            conversationId: "conv1",
            senderId: "user1",
            senderName: "Test User",
            text: text,
            timestamp: timestamp,
            status: .sent,
            readBy: [],
            deliveredTo: [],
            localId: nil
        )
    }
    
    private func createLocalConversation(
        id: String,
        lastMessageText: String,
        createdAt: Date = Date(),
        updatedAt: Date?,
        serverTimestamp: Date?
    ) -> LocalConversation {
        let participants: [String: Conversation.ParticipantInfo] = [
            "user1": Conversation.ParticipantInfo(displayName: "User 1", profileImageUrl: nil),
            "user2": Conversation.ParticipantInfo(displayName: "User 2", profileImageUrl: nil)
        ]
        
        let lastMessage = Conversation.LastMessage(
            text: lastMessageText,
            senderId: "user1",
            senderName: "User 1",
            timestamp: updatedAt ?? createdAt
        )
        
        return LocalConversation(
            id: id,
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: participants,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            lastMessage: lastMessage,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: serverTimestamp,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }
    
    private func createRemoteConversation(
        id: String,
        lastMessageText: String,
        createdAt: Date = Date(),
        updatedAt: Date?
    ) -> Conversation {
        let participants: [String: Conversation.ParticipantInfo] = [
            "user1": Conversation.ParticipantInfo(displayName: "User 1", profileImageUrl: nil),
            "user2": Conversation.ParticipantInfo(displayName: "User 2", profileImageUrl: nil)
        ]
        
        let lastMessage = Conversation.LastMessage(
            text: lastMessageText,
            senderId: "user1",
            senderName: "User 1",
            timestamp: updatedAt ?? createdAt
        )
        
        return Conversation(
            id: id,
            type: .direct,
            participantIds: ["user1", "user2"],
            participants: participants,
            lastMessage: lastMessage,
            groupName: nil,
            groupImageUrl: nil,
            createdBy: "user1",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func createLocalUser(
        id: String,
        displayName: String,
        isOnline: Bool = false,
        lastSeen: Date = Date(),
        createdAt: Date = Date(),
        serverTimestamp: Date? = nil
    ) -> LocalUser {
        return LocalUser(
            id: id,
            googleId: "google123",
            email: "test@example.com",
            displayName: displayName,
            profileImageUrl: nil,
            isOnline: isOnline,
            lastSeen: lastSeen,
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: serverTimestamp,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
    
    private func createRemoteUser(
        id: String,
        displayName: String,
        isOnline: Bool = false,
        lastSeen: Date = Date(),
        createdAt: Date = Date()
    ) -> User {
        return User(
            id: id,
            googleId: "google123",
            email: "test@example.com",
            displayName: displayName,
            profileImageUrl: nil,
            isOnline: isOnline,
            lastSeen: lastSeen,
            createdAt: createdAt
        )
    }
}

