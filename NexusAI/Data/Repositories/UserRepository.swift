//
//  UserRepository.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// Concrete implementation of UserRepositoryProtocol
/// Currently reads/writes ONLY from LocalDatabase (no Firestore sync yet)
@MainActor
final class UserRepository: UserRepositoryProtocol {
    
    private let database: LocalDatabase
    
    init(database: LocalDatabase? = nil) {
        self.database = database ?? LocalDatabase.shared
    }
    
    // MARK: - Observation
    
    func observeUser(userId: String) -> AsyncStream<User?> {
        let predicate = #Predicate<LocalUser> { user in
            user.id == userId
        }
        
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observeOne(LocalUser.self, where: predicate)
                
                for await localUser in stream {
                    continuation.yield(localUser?.toUser())
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func observeUsers(userIds: [String]) -> AsyncStream<[String: User]> {
        // Note: SwiftData predicates don't handle external array captures well
        // So we fetch all users and filter in memory
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observe(
                    LocalUser.self,
                    sortBy: [SortDescriptor(\LocalUser.displayName)]
                )
                
                for await allLocalUsers in stream {
                    // Filter to only requested users
                    let filteredUsers = allLocalUsers.filter { userIds.contains($0.id) }
                    let userDict = Dictionary(
                        uniqueKeysWithValues: filteredUsers.map { ($0.id, $0.toUser()) }
                    )
                    continuation.yield(userDict)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Read Operations
    
    func getUser(userId: String) async throws -> User? {
        let predicate = #Predicate<LocalUser> { user in
            user.id == userId
        }
        
        let localUser = try database.fetchOne(LocalUser.self, where: predicate)
        return localUser?.toUser()
    }
    
    func getUsers(userIds: [String]) async throws -> [User] {
        // Note: SwiftData predicates don't handle external array captures well
        // Fetch individually or fetch all and filter in memory
        // For small sets (typical use case), fetch all and filter is acceptable
        let allUsers = try database.fetch(
            LocalUser.self,
            sortBy: [SortDescriptor(\LocalUser.displayName)]
        )
        
        let filteredUsers = allUsers.filter { userIds.contains($0.id) }
        return filteredUsers.map { $0.toUser() }
    }
    
    func searchUsers(query: String) async throws -> [User] {
        // Note: SwiftData predicates with external captures can be problematic
        // Fetch all users and filter in memory for search
        let lowercasedQuery = query.lowercased()
        
        let allUsers = try database.fetch(
            LocalUser.self,
            sortBy: [SortDescriptor(\LocalUser.displayName)]
        )
        
        let filteredUsers = allUsers.filter { user in
            user.displayName.lowercased().contains(lowercasedQuery) ||
            user.email.lowercased().contains(lowercasedQuery)
        }
        
        // Limit search results
        return Array(filteredUsers.prefix(20)).map { $0.toUser() }
    }
    
    // MARK: - Write Operations
    
    func saveUser(_ user: User) async throws -> User {
        // User.id is optional (String?) due to @DocumentID
        guard let userId = user.id else {
            throw RepositoryError.invalidData
        }
        
        // Extract to local variable to avoid SwiftData predicate capture issue
        let predicate = #Predicate<LocalUser> { localUser in
            localUser.id == userId
        }
        
        if let existingLocal = try database.fetchOne(LocalUser.self, where: predicate) {
            // Update existing user
            existingLocal.update(from: user)
            existingLocal.syncStatus = .pending
            try database.update(existingLocal)
        } else {
            // Insert new user
            let localUser = LocalUser.from(user, syncStatus: .pending)
            try database.insert(localUser)
        }
        
        try database.save()
        return user
    }
    
    func updatePresence(
        userId: String,
        isOnline: Bool,
        lastSeen: Date?
    ) async throws {
        let predicate = #Predicate<LocalUser> { user in
            user.id == userId
        }
        
        guard let localUser = try database.fetchOne(LocalUser.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        localUser.isOnline = isOnline
        if let lastSeen = lastSeen {
            localUser.lastSeen = lastSeen
        }
        localUser.syncStatus = .pending
        
        try database.update(localUser)
        try database.save()
    }
    
    func updateProfile(
        userId: String,
        displayName: String?,
        profileImageUrl: String?
    ) async throws {
        let predicate = #Predicate<LocalUser> { user in
            user.id == userId
        }
        
        guard let localUser = try database.fetchOne(LocalUser.self, where: predicate) else {
            throw RepositoryError.notFound
        }
        
        if let displayName = displayName {
            localUser.displayName = displayName
        }
        if let profileImageUrl = profileImageUrl {
            localUser.profileImageUrl = profileImageUrl
        }
        localUser.syncStatus = .pending
        
        try database.update(localUser)
        try database.save()
    }
    
    func deleteUser(userId: String) async throws {
        let predicate = #Predicate<LocalUser> { user in
            user.id == userId
        }
        
        if let localUser = try database.fetchOne(LocalUser.self, where: predicate) {
            try database.delete(localUser)
            try database.save()
        }
    }
}

