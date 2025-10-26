//
//  UserRepositoryProtocol.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Protocol defining user repository operations
/// ViewModels depend on this protocol, not the concrete implementation
@MainActor
protocol UserRepositoryProtocol {
    
    // MARK: - Observation (Reactive Queries)
    
    /// Observe a user with real-time updates
    /// - Parameter userId: The user ID to observe
    /// - Returns: AsyncStream that emits the user whenever it changes
    func observeUser(userId: String) -> AsyncStream<User?>
    
    /// Observe multiple users with real-time updates
    /// - Parameter userIds: Array of user IDs to observe
    /// - Returns: AsyncStream that emits dictionary of users (userId -> User)
    func observeUsers(userIds: [String]) -> AsyncStream<[String: User]>
    
    // MARK: - Read Operations
    
    /// Get a user by ID
    /// - Parameter userId: The user ID
    /// - Returns: The user, or nil if not found
    func getUser(userId: String) async throws -> User?
    
    /// Get multiple users by IDs
    /// - Parameter userIds: Array of user IDs
    /// - Returns: Array of users
    func getUsers(userIds: [String]) async throws -> [User]
    
    /// Search users by display name
    /// - Parameter query: Search query string
    /// - Returns: Array of matching users
    func searchUsers(query: String) async throws -> [User]
    
    // MARK: - Write Operations
    
    /// Create or update a user profile
    /// - Parameter user: The user to save
    /// - Returns: The saved user
    func saveUser(_ user: User) async throws -> User
    
    /// Update user presence (online/offline status)
    /// - Parameters:
    ///   - userId: The user ID
    ///   - isOnline: Whether the user is online
    ///   - lastSeen: Optional last seen timestamp
    func updatePresence(
        userId: String,
        isOnline: Bool,
        lastSeen: Date?
    ) async throws
    
    /// Update user profile
    /// - Parameters:
    ///   - userId: The user ID
    ///   - displayName: Optional new display name
    ///   - profileImageUrl: Optional new profile image URL
    func updateProfile(
        userId: String,
        displayName: String?,
        profileImageUrl: String?
    ) async throws
    
    /// Update user's cached avatar properties (color and initials)
    /// - Parameters:
    ///   - userId: The user ID
    ///   - initials: Precomputed initials
    ///   - colorHex: Avatar background color as hex string
    func updateAvatarCache(
        userId: String,
        initials: String,
        colorHex: String
    ) async throws
    
    /// Delete a user
    /// - Parameter userId: The user ID to delete
    func deleteUser(userId: String) async throws
}

