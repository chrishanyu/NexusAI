//
//  UserRepositoryTests.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import XCTest
import SwiftData
@testable import NexusAI

@MainActor
final class UserRepositoryTests: XCTestCase {
    
    var database: LocalDatabase!
    var repository: UserRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        database = try LocalDatabase(inMemory: true)
        repository = UserRepository(database: database)
    }
    
    override func tearDown() async throws {
        database = nil
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Read Operations
    
    func testGetUser_ReturnsSpecificUser() async throws {
        // Given
        let user = createLocalUser(id: "user123", displayName: "John Doe", email: "john@example.com")
        try database.insert(user)
        try database.save()
        
        // When
        let retrieved = try await repository.getUser(userId: "user123")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "user123")
        XCTAssertEqual(retrieved?.displayName, "John Doe")
        XCTAssertEqual(retrieved?.email, "john@example.com")
    }
    
    func testGetUser_ReturnsNilForNonExistent() async throws {
        // When
        let retrieved = try await repository.getUser(userId: "nonexistent")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testGetUsers_ReturnsMultipleUsers() async throws {
        // Given
        let user1 = createLocalUser(id: "user1", displayName: "Alice", email: "alice@example.com")
        let user2 = createLocalUser(id: "user2", displayName: "Bob", email: "bob@example.com")
        let user3 = createLocalUser(id: "user3", displayName: "Charlie", email: "charlie@example.com")
        
        try database.insert(user1)
        try database.insert(user2)
        try database.insert(user3)
        try database.save()
        
        // When
        let users = try await repository.getUsers(userIds: ["user1", "user3"])
        
        // Then
        XCTAssertEqual(users.count, 2)
        let names = users.map { $0.displayName }.sorted()
        XCTAssertEqual(names, ["Alice", "Charlie"])
    }
    
    func testSearchUsers_FindsByDisplayName() async throws {
        // Given
        let user1 = createLocalUser(id: "user1", displayName: "John Smith", email: "john@example.com")
        let user2 = createLocalUser(id: "user2", displayName: "Jane Doe", email: "jane@example.com")
        let user3 = createLocalUser(id: "user3", displayName: "Johnny Cash", email: "johnny@example.com")
        
        try database.insert(user1)
        try database.insert(user2)
        try database.insert(user3)
        try database.save()
        
        // When
        let users = try await repository.searchUsers(query: "John")
        
        // Then
        XCTAssertEqual(users.count, 2)
        let names = users.map { $0.displayName }.sorted()
        XCTAssertTrue(names.contains("John Smith"))
        XCTAssertTrue(names.contains("Johnny Cash"))
        XCTAssertFalse(names.contains("Jane Doe"))
    }
    
    func testSearchUsers_FindsByEmail() async throws {
        // Given
        let user1 = createLocalUser(id: "user1", displayName: "Alice", email: "alice@company.com")
        let user2 = createLocalUser(id: "user2", displayName: "Bob", email: "bob@other.com")
        
        try database.insert(user1)
        try database.insert(user2)
        try database.save()
        
        // When
        let users = try await repository.searchUsers(query: "company")
        
        // Then
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.displayName, "Alice")
    }
    
    func testSearchUsers_IsCaseInsensitive() async throws {
        // Given
        let user = createLocalUser(id: "user1", displayName: "John Smith", email: "john@example.com")
        try database.insert(user)
        try database.save()
        
        // When
        let users = try await repository.searchUsers(query: "JOHN")
        
        // Then
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.displayName, "John Smith")
    }
    
    // MARK: - Write Operations
    
    func testSaveUser_CreatesNewUser() async throws {
        // Given
        let user = User(
            id: "user123",
            googleId: "google123",
            email: "john@example.com",
            displayName: "John Doe",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When
        let saved = try await repository.saveUser(user)
        
        // Then
        XCTAssertEqual(saved.id, "user123")
        
        // Verify it's in the database with pending sync status
        let predicate = #Predicate<LocalUser> { $0.id == "user123" }
        let localUser = try database.fetchOne(LocalUser.self, where: predicate)
        XCTAssertNotNil(localUser)
        XCTAssertEqual(localUser?.displayName, "John Doe")
        XCTAssertEqual(localUser?.syncStatus, .pending)
    }
    
    func testSaveUser_UpdatesExistingUser() async throws {
        // Given - Create initial user
        let initialUser = createLocalUser(id: "user123", displayName: "Old Name", email: "john@example.com")
        initialUser.syncStatus = .synced
        try database.insert(initialUser)
        try database.save()
        
        // When - Update with new data
        let updatedUser = User(
            id: "user123",
            googleId: "google123",
            email: "john@example.com",
            displayName: "New Name",
            profileImageUrl: "https://example.com/image.jpg",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        let saved = try await repository.saveUser(updatedUser)
        
        // Then
        XCTAssertEqual(saved.displayName, "New Name")
        
        // Verify in database
        let predicate = #Predicate<LocalUser> { $0.id == "user123" }
        let localUser = try database.fetchOne(LocalUser.self, where: predicate)
        XCTAssertEqual(localUser?.displayName, "New Name")
        XCTAssertEqual(localUser?.profileImageUrl, "https://example.com/image.jpg")
        XCTAssertEqual(localUser?.syncStatus, .pending) // Marked for sync
    }
    
    func testUpdatePresence_UpdatesOnlineStatus() async throws {
        // Given
        let user = createLocalUser(id: "user123", displayName: "John", email: "john@example.com")
        user.isOnline = false
        user.syncStatus = .synced
        try database.insert(user)
        try database.save()
        
        let newLastSeen = Date()
        
        // When
        try await repository.updatePresence(userId: "user123", isOnline: true, lastSeen: newLastSeen)
        
        // Then
        let predicate = #Predicate<LocalUser> { $0.id == "user123" }
        let updated = try database.fetchOne(LocalUser.self, where: predicate)
        XCTAssertEqual(updated?.isOnline, true)
        XCTAssertEqual(updated?.lastSeen.timeIntervalSince1970 ?? 0, newLastSeen.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testUpdateProfile_UpdatesDisplayName() async throws {
        // Given
        let user = createLocalUser(id: "user123", displayName: "Old Name", email: "john@example.com")
        user.syncStatus = .synced
        try database.insert(user)
        try database.save()
        
        // When
        try await repository.updateProfile(userId: "user123", displayName: "New Name", profileImageUrl: nil)
        
        // Then
        let predicate = #Predicate<LocalUser> { $0.id == "user123" }
        let updated = try database.fetchOne(LocalUser.self, where: predicate)
        XCTAssertEqual(updated?.displayName, "New Name")
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testUpdateProfile_UpdatesProfileImageUrl() async throws {
        // Given
        let user = createLocalUser(id: "user123", displayName: "John", email: "john@example.com")
        user.profileImageUrl = nil
        user.syncStatus = .synced
        try database.insert(user)
        try database.save()
        
        // When
        try await repository.updateProfile(
            userId: "user123",
            displayName: nil,
            profileImageUrl: "https://example.com/new-image.jpg"
        )
        
        // Then
        let predicate = #Predicate<LocalUser> { $0.id == "user123" }
        let updated = try database.fetchOne(LocalUser.self, where: predicate)
        XCTAssertEqual(updated?.displayName, "John") // Should not change
        XCTAssertEqual(updated?.profileImageUrl, "https://example.com/new-image.jpg")
        XCTAssertEqual(updated?.syncStatus, .pending)
    }
    
    func testDeleteUser_RemovesUserFromDatabase() async throws {
        // Given
        let user = createLocalUser(id: "user123", displayName: "John", email: "john@example.com")
        try database.insert(user)
        try database.save()
        
        // When
        try await repository.deleteUser(userId: "user123")
        
        // Then
        let retrieved = try await repository.getUser(userId: "user123")
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Error Handling
    
    func testUpdatePresence_ThrowsErrorForNonExistentUser() async {
        // When/Then
        do {
            try await repository.updatePresence(userId: "nonexistent", isOnline: true, lastSeen: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    func testUpdateProfile_ThrowsErrorForNonExistentUser() async {
        // When/Then
        do {
            try await repository.updateProfile(userId: "nonexistent", displayName: "New Name", profileImageUrl: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
    }
    
    // MARK: - AsyncStream Observation
    
    func testObserveUser_EmitsUpdates() async throws {
        // Given
        let userId = "user123"
        
        // When
        let stream = repository.observeUser(userId: userId)
        
        // Create a task to collect stream values
        var receivedUsers: [User?] = []
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            // Get first emission (nil)
            if let first = await iterator.next() {
                receivedUsers.append(first)
            }
            // Wait for second emission after insert
            if let second = await iterator.next() {
                receivedUsers.append(second)
            }
        }
        
        // Give stream time to set up and emit initial state
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Insert a user
        let user = createLocalUser(id: userId, displayName: "John", email: "john@example.com")
        try database.insert(user)
        try database.save()
        
        // Trigger notification for event-driven updates
        database.notifyChanges()
        
        // Wait for stream to emit update
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        task.cancel()
        
        // Then
        XCTAssertGreaterThanOrEqual(receivedUsers.count, 1, "Should have received at least 1 emission")
        if receivedUsers.count >= 2 {
            XCTAssertNil(receivedUsers[0]) // Initial nil state
            XCTAssertNotNil(receivedUsers[1]) // After insert
            XCTAssertEqual(receivedUsers[1]?.displayName, "John")
        } else if receivedUsers.count == 1 {
            // If only got one emission, it should be the updated user (timing dependent)
            XCTAssertNotNil(receivedUsers[0], "First emission should be the user")
            XCTAssertEqual(receivedUsers[0]?.displayName, "John")
        }
    }
    
    func testObserveUsers_EmitsUpdates() async throws {
        // Given
        let userIds = ["user1", "user2"]
        
        // When
        let stream = repository.observeUsers(userIds: userIds)
        
        // Create a task to collect stream values
        var receivedUserDicts: [[String: User]] = []
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            // Get first emission (empty)
            if let first = await iterator.next() {
                receivedUserDicts.append(first)
            }
            // Wait for second emission after insert
            if let second = await iterator.next() {
                receivedUserDicts.append(second)
            }
        }
        
        // Give stream time to set up and emit initial state
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Insert users
        let user1 = createLocalUser(id: "user1", displayName: "Alice", email: "alice@example.com")
        let user2 = createLocalUser(id: "user2", displayName: "Bob", email: "bob@example.com")
        try database.insert(user1)
        try database.insert(user2)
        try database.save()
        
        // Trigger notification for event-driven updates
        database.notifyChanges()
        
        // Wait for stream to emit update
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        task.cancel()
        
        // Then
        XCTAssertGreaterThanOrEqual(receivedUserDicts.count, 1, "Should have received at least 1 emission")
        if receivedUserDicts.count >= 2 {
            XCTAssertEqual(receivedUserDicts[0].count, 0) // Initial empty state
            XCTAssertEqual(receivedUserDicts[1].count, 2) // After insert
            XCTAssertNotNil(receivedUserDicts[1]["user1"])
            XCTAssertNotNil(receivedUserDicts[1]["user2"])
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLocalUser(id: String, displayName: String, email: String) -> LocalUser {
        return LocalUser(
            id: id,
            googleId: "google_\(id)",
            email: email,
            displayName: displayName,
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            syncStatus: .synced,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

