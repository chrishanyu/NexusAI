//
//  LocalUserTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
@testable import NexusAI

@available(iOS 17.0, *)
final class LocalUserTests: XCTestCase {
    
    // MARK: - Conversion Tests
    
    func testToUser_ConvertsAllFieldsCorrectly() {
        // Given
        let localUser = LocalUser(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: "https://example.com/alice.jpg",
            isOnline: true,
            lastSeen: Date(),
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        let user = localUser.toUser()
        
        // Then
        XCTAssertEqual(user.id, "user123")
        XCTAssertEqual(user.googleId, "google456")
        XCTAssertEqual(user.email, "alice@example.com")
        XCTAssertEqual(user.displayName, "Alice")
        XCTAssertEqual(user.profileImageUrl, "https://example.com/alice.jpg")
        XCTAssertEqual(user.isOnline, true)
    }
    
    func testFromUser_ConvertsAllFieldsCorrectly() {
        // Given
        let user = User(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: "https://example.com/alice.jpg",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When
        let localUser = LocalUser.from(user)
        
        // Then
        XCTAssertEqual(localUser.id, "user123")
        XCTAssertEqual(localUser.googleId, "google456")
        XCTAssertEqual(localUser.email, "alice@example.com")
        XCTAssertEqual(localUser.displayName, "Alice")
        XCTAssertEqual(localUser.profileImageUrl, "https://example.com/alice.jpg")
        XCTAssertEqual(localUser.isOnline, true)
        XCTAssertEqual(localUser.syncStatus, .synced)
        XCTAssertEqual(localUser.syncRetryCount, 0)
        XCTAssertNil(localUser.lastSyncAttempt)
    }
    
    func testFromUser_WithPendingSyncStatus() {
        // Given
        let user = User(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: nil,
            isOnline: false,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When
        let localUser = LocalUser.from(user, syncStatus: .pending)
        
        // Then
        XCTAssertEqual(localUser.syncStatus, .pending)
        XCTAssertNil(localUser.profileImageUrl)
        XCTAssertFalse(localUser.isOnline)
    }
    
    func testUpdate_UpdatesProfileFields() {
        // Given
        let localUser = LocalUser(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: nil,
            isOnline: false,
            lastSeen: Date(),
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let updatedUser = User(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice Smith",
            profileImageUrl: "https://example.com/new.jpg",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When
        localUser.update(from: updatedUser)
        
        // Then
        XCTAssertEqual(localUser.displayName, "Alice Smith")
        XCTAssertEqual(localUser.profileImageUrl, "https://example.com/new.jpg")
        XCTAssertTrue(localUser.isOnline)
        XCTAssertEqual(localUser.id, "user123") // Unchanged
    }
    
    func testSyncStatusComputedProperty() {
        // Given
        let localUser = LocalUser(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            syncStatus: .failed,
            lastSyncAttempt: Date(),
            syncRetryCount: 2,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When/Then
        XCTAssertEqual(localUser.syncStatus, .failed)
        XCTAssertEqual(localUser.syncRetryCount, 2)
        
        // When - Update sync status
        localUser.syncStatus = .synced
        
        // Then
        XCTAssertEqual(localUser.syncStatus, .synced)
        XCTAssertEqual(localUser.syncStatusRaw, "synced")
    }
    
    func testRoundTripConversion() {
        // Given
        let originalUser = User(
            id: "user123",
            googleId: "google456",
            email: "alice@example.com",
            displayName: "Alice",
            profileImageUrl: "https://example.com/alice.jpg",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When
        let localUser = LocalUser.from(originalUser)
        let convertedUser = localUser.toUser()
        
        // Then
        XCTAssertEqual(convertedUser.id, originalUser.id)
        XCTAssertEqual(convertedUser.googleId, originalUser.googleId)
        XCTAssertEqual(convertedUser.email, originalUser.email)
        XCTAssertEqual(convertedUser.displayName, originalUser.displayName)
        XCTAssertEqual(convertedUser.profileImageUrl, originalUser.profileImageUrl)
        XCTAssertEqual(convertedUser.isOnline, originalUser.isOnline)
    }
}

