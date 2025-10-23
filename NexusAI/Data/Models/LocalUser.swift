//
//  LocalUser.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// SwiftData model for local user profile storage with sync state tracking
@available(iOS 17.0, *)
@Model
final class LocalUser {
    
    // MARK: - Identity
    
    /// Unique identifier (Firebase Auth UID)
    @Attribute(.unique) var id: String
    
    /// Google account ID
    var googleId: String
    
    // MARK: - Profile
    
    /// User's email address
    var email: String
    
    /// User's display name
    var displayName: String
    
    /// URL to user's profile image
    var profileImageUrl: String?
    
    // MARK: - Presence
    
    /// Whether user is currently online
    var isOnline: Bool
    
    /// Last time user was seen online
    var lastSeen: Date
    
    // MARK: - Sync State
    
    /// Current sync status with Firestore
    var syncStatusRaw: String
    
    /// Timestamp of last sync attempt (nil if never attempted)
    var lastSyncAttempt: Date?
    
    /// Number of times sync has been retried
    var syncRetryCount: Int
    
    /// Server timestamp from Firestore (for conflict resolution)
    var serverTimestamp: Date?
    
    // MARK: - Metadata
    
    /// When user account was created
    var createdAt: Date
    
    /// When user profile was last updated locally
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Sync status as enum
    var syncStatus: SyncStatus {
        get {
            SyncStatus(rawValue: syncStatusRaw) ?? .synced
        }
        set {
            syncStatusRaw = newValue.rawValue
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        googleId: String,
        email: String,
        displayName: String,
        profileImageUrl: String?,
        isOnline: Bool,
        lastSeen: Date,
        syncStatus: SyncStatus = .synced,
        lastSyncAttempt: Date? = nil,
        syncRetryCount: Int = 0,
        serverTimestamp: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.googleId = googleId
        self.email = email
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.syncStatusRaw = syncStatus.rawValue
        self.lastSyncAttempt = lastSyncAttempt
        self.syncRetryCount = syncRetryCount
        self.serverTimestamp = serverTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Conversion Methods
    
    /// Convert LocalUser to domain User model
    func toUser() -> User {
        return User(
            id: id,
            googleId: googleId,
            email: email,
            displayName: displayName,
            profileImageUrl: profileImageUrl,
            isOnline: isOnline,
            lastSeen: lastSeen,
            createdAt: createdAt
        )
    }
    
    /// Create LocalUser from domain User model
    static func from(_ user: User, syncStatus: SyncStatus = .synced) -> LocalUser {
        return LocalUser(
            id: user.id ?? UUID().uuidString,
            googleId: user.googleId,
            email: user.email,
            displayName: user.displayName,
            profileImageUrl: user.profileImageUrl,
            isOnline: user.isOnline,
            lastSeen: user.lastSeen,
            syncStatus: syncStatus,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
    }
    
    /// Update LocalUser with data from domain User model
    func update(from user: User) {
        self.googleId = user.googleId
        self.email = user.email
        self.displayName = user.displayName
        self.profileImageUrl = user.profileImageUrl
        self.isOnline = user.isOnline
        self.lastSeen = user.lastSeen
        self.updatedAt = Date()
    }
}

