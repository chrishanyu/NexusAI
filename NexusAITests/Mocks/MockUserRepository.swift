//
//  MockUserRepository.swift
//  NexusAITests
//
//  Created on 10/22/25.
//

import Foundation
@testable import NexusAI

/// Mock implementation of UserRepositoryProtocol for testing
@MainActor
final class MockUserRepository: UserRepositoryProtocol {
    
    // Storage
    private var users: [String: User] = [:]
    
    // Mock control flags
    var shouldThrowError = false
    var errorToThrow: Error = MockError.generic
    
    // Call tracking
    var saveUserCallCount = 0
    var updatePresenceCallCount = 0
    var updateProfileCallCount = 0
    var deleteUserCallCount = 0
    var searchUsersCallCount = 0
    var lastSavedUser: User?
    var lastUpdatedUserId: String?
    
    // MARK: - Observation
    
    func observeUser(userId: String) -> AsyncStream<User?> {
        AsyncStream { continuation in
            continuation.yield(self.users[userId])
            continuation.finish()
        }
    }
    
    func observeUsers(userIds: [String]) -> AsyncStream<[String: User]> {
        AsyncStream { continuation in
            let filtered = self.users.filter { userIds.contains($0.key) }
            continuation.yield(filtered)
            continuation.finish()
        }
    }
    
    // MARK: - Read Operations
    
    func getUser(userId: String) async throws -> User? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return users[userId]
    }
    
    func getUsers(userIds: [String]) async throws -> [User] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return userIds.compactMap { users[$0] }
    }
    
    func searchUsers(query: String) async throws -> [User] {
        searchUsersCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let lowercasedQuery = query.lowercased()
        return users.values.filter { user in
            user.displayName.lowercased().contains(lowercasedQuery) ||
            user.email.lowercased().contains(lowercasedQuery)
        }.sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Write Operations
    
    func saveUser(_ user: User) async throws -> User {
        saveUserCallCount += 1
        lastSavedUser = user
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Unwrap optional user.id
        guard let userId = user.id else {
            throw MockError.notFound
        }
        users[userId] = user
        return user
    }
    
    func updatePresence(
        userId: String,
        isOnline: Bool,
        lastSeen: Date?
    ) async throws {
        updatePresenceCallCount += 1
        lastUpdatedUserId = userId
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard var user = users[userId] else {
            throw MockError.notFound
        }
        
        user.isOnline = isOnline
        if let lastSeen = lastSeen {
            user.lastSeen = lastSeen
        }
        users[userId] = user
    }
    
    func updateProfile(
        userId: String,
        displayName: String?,
        profileImageUrl: String?
    ) async throws {
        updateProfileCallCount += 1
        lastUpdatedUserId = userId
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard var user = users[userId] else {
            throw MockError.notFound
        }
        
        if let displayName = displayName {
            user.displayName = displayName
        }
        if let profileImageUrl = profileImageUrl {
            user.profileImageUrl = profileImageUrl
        }
        users[userId] = user
    }
    
    func deleteUser(userId: String) async throws {
        deleteUserCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        users.removeValue(forKey: userId)
    }
    
    // MARK: - Test Helpers
    
    func setUsers(_ users: [User]) {
        // Filter out users with nil id and unwrap
        self.users = Dictionary(uniqueKeysWithValues: users.compactMap { user in
            guard let userId = user.id else { return nil }
            return (userId, user)
        })
    }
    
    func reset() {
        users = [:]
        shouldThrowError = false
        saveUserCallCount = 0
        updatePresenceCallCount = 0
        updateProfileCallCount = 0
        deleteUserCallCount = 0
        searchUsersCallCount = 0
        lastSavedUser = nil
        lastUpdatedUserId = nil
    }
}

