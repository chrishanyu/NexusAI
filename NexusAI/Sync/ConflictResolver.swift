//
//  ConflictResolver.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Handles conflict resolution between local and remote data using Last-Write-Wins (LWW) strategy
/// Compares server timestamps to determine which version should be kept
/// Thread-safe: Can be called from any context as it only performs pure timestamp comparisons
final class ConflictResolver {
    
    // MARK: - Message Resolution
    
    /// Resolves conflicts between local and remote messages using LWW strategy
    /// - Parameters:
    ///   - local: Local message from SwiftData
    ///   - remote: Remote message from Firestore
    /// - Returns: The message that should be kept (winner of LWW comparison)
    func resolveMessage(local: LocalMessage, remote: Message) -> ConflictResolution<LocalMessage> {
        // Extract timestamps
        let localTimestamp = local.serverTimestamp ?? local.timestamp
        let remoteTimestamp = remote.timestamp
        
        // Last-Write-Wins: Keep the message with the most recent timestamp
        if remoteTimestamp > localTimestamp {
            // Remote is newer - update local with remote data
            let updatedLocal = LocalMessage.from(remote, syncStatus: .synced)
            return .useRemote(updatedLocal)
        } else if localTimestamp > remoteTimestamp {
            // Local is newer - keep local, mark as pending to sync back
            local.syncStatus = .pending
            return .useLocal(local)
        } else {
            // Timestamps are equal - remote wins by default (server is source of truth)
            let updatedLocal = LocalMessage.from(remote, syncStatus: .synced)
            return .useRemote(updatedLocal)
        }
    }
    
    // MARK: - Conversation Resolution
    
    /// Resolves conflicts between local and remote conversations using LWW strategy
    /// - Parameters:
    ///   - local: Local conversation from SwiftData
    ///   - remote: Remote conversation from Firestore
    /// - Returns: The conversation that should be kept
    func resolveConversation(local: LocalConversation, remote: Conversation) -> ConflictResolution<LocalConversation> {
        // Use serverTimestamp if available, otherwise use updatedAt
        let localTimestamp = local.serverTimestamp ?? local.updatedAt
        let remoteTimestamp = remote.updatedAt ?? remote.createdAt
        
        // Last-Write-Wins: Keep the conversation with the most recent timestamp
        if remoteTimestamp > localTimestamp {
            // Remote is newer - update local with remote data
            let updatedLocal = LocalConversation.from(remote, syncStatus: .synced)
            return .useRemote(updatedLocal)
        } else if localTimestamp > remoteTimestamp {
            // Local is newer - keep local, mark as pending to sync back
            local.syncStatus = .pending
            return .useLocal(local)
        } else {
            // Timestamps are equal - remote wins by default
            let updatedLocal = LocalConversation.from(remote, syncStatus: .synced)
            return .useRemote(updatedLocal)
        }
    }
    
    // MARK: - User Resolution
    
    /// Resolves conflicts between local and remote users with field-level merge
    /// Presence data (isOnline, lastSeen) always comes from server
    /// Profile data uses LWW strategy
    /// - Parameters:
    ///   - local: Local user from SwiftData
    ///   - remote: Remote user from Firestore
    /// - Returns: The user that should be kept
    func resolveUser(local: LocalUser, remote: User) -> ConflictResolution<LocalUser> {
        // Use serverTimestamp for comparison, fallback to createdAt
        let localTimestamp = local.serverTimestamp ?? local.createdAt
        let remoteTimestamp = remote.createdAt // User doesn't have updatedAt in current schema
        
        // Always use remote presence data (isOnline, lastSeen) - server is source of truth
        let updatedLocal = LocalUser.from(remote, syncStatus: .synced)
        
        // For profile fields, use LWW
        if localTimestamp > remoteTimestamp {
            // Local profile is newer - keep local profile fields but use remote presence
            updatedLocal.displayName = local.displayName
            updatedLocal.profileImageUrl = local.profileImageUrl
            updatedLocal.syncStatus = .pending // Need to sync profile back
            return .useLocal(updatedLocal)
        } else {
            // Remote is newer or equal - use all remote data
            return .useRemote(updatedLocal)
        }
    }
}

// MARK: - Conflict Resolution Result

/// Represents the result of a conflict resolution operation
enum ConflictResolution<T> {
    /// Use the remote version (Firestore data wins)
    case useRemote(T)
    
    /// Use the local version (local data wins, needs sync back)
    case useLocal(T)
    
    /// Get the resolved entity
    var resolved: T {
        switch self {
        case .useRemote(let entity):
            return entity
        case .useLocal(let entity):
            return entity
        }
    }
    
    /// Whether the local version won
    var isLocalWinner: Bool {
        if case .useLocal = self {
            return true
        }
        return false
    }
    
    /// Whether the remote version won
    var isRemoteWinner: Bool {
        if case .useRemote = self {
            return true
        }
        return false
    }
}

