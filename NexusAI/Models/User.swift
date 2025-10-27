//
//  User.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/21/25.
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var googleId: String?  // Optional for backward compatibility with older user documents
    let email: String
    var displayName: String
    var profileImageUrl: String?
    var avatarColorHex: String?  // Synced to Firestore for cross-device consistency
    var isOnline: Bool?  // Optional with default - may be missing in older documents
    var lastSeen: Date?  // Optional with default - may be missing in older documents
    let createdAt: Date
    
    // Computed properties with safe defaults for optional presence fields
    var isCurrentlyOnline: Bool {
        return isOnline ?? false
    }
    
    var lastSeenDate: Date {
        return lastSeen ?? Date(timeIntervalSince1970: 0)  // Epoch if never seen
    }
    
    // Regular init for creating new users
    init(id: String? = nil, googleId: String?, email: String, displayName: String, 
         profileImageUrl: String? = nil, avatarColorHex: String? = nil,
         isOnline: Bool = false, lastSeen: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.googleId = googleId
        self.email = email
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.avatarColorHex = avatarColorHex
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }
}
