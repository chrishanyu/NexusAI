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
    
    /// Google account ID (optional for backward compatibility)
    var googleId: String?
    
    // MARK: - Profile
    
    /// User's email address
    var email: String
    
    /// User's display name
    var displayName: String
    
    /// URL to user's profile image
    var profileImageUrl: String?
    
    // MARK: - Avatar Cache
    
    /// Stored avatar color for consistent display (hex string)
    var avatarColorHex: String?
    
    /// Precomputed initials for faster display
    var cachedInitials: String?
    
    /// Local file path to cached profile image
    var cachedImagePath: String?
    
    /// Last time cached image was accessed (for LRU eviction)
    var cachedImageLastAccess: Date?
    
    // MARK: - Presence
    
    /// Whether user is currently online (optional for backward compatibility)
    var isOnline: Bool?
    
    /// Last time user was seen online (optional for backward compatibility)
    var lastSeen: Date?
    
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
        googleId: String? = nil,
        email: String,
        displayName: String,
        profileImageUrl: String?,
        avatarColorHex: String? = nil,
        cachedInitials: String? = nil,
        cachedImagePath: String? = nil,
        cachedImageLastAccess: Date? = nil,
        isOnline: Bool? = nil,
        lastSeen: Date? = nil,
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
        self.avatarColorHex = avatarColorHex
        self.cachedInitials = cachedInitials
        self.cachedImagePath = cachedImagePath
        self.cachedImageLastAccess = cachedImageLastAccess
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
            avatarColorHex: avatarColorHex,
            isOnline: isOnline ?? false,  // Provide default
            lastSeen: lastSeen ?? Date(),  // Provide default
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
            avatarColorHex: user.avatarColorHex,
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
        
        // Update avatar color if provided from server (cross-device sync)
        if let serverColor = user.avatarColorHex, !serverColor.isEmpty {
            self.avatarColorHex = serverColor
        }
        
        self.isOnline = user.isOnline
        self.lastSeen = user.lastSeen
        self.updatedAt = Date()
    }
}

