//
//  SyncStatus.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Represents the synchronization state of a local entity with Firestore
enum SyncStatus: String, Codable {
    /// Local data matches Firestore data - fully synchronized
    case synced
    
    /// Local write pending sync to Firestore
    case pending
    
    /// Sync attempt failed - will retry with exponential backoff
    case failed
    
    /// Conflict detected between local and remote data (rare with Last-Write-Wins)
    case conflict
    
    /// Human-readable description of the sync status
    var description: String {
        switch self {
        case .synced:
            return "Synced"
        case .pending:
            return "Pending sync"
        case .failed:
            return "Sync failed"
        case .conflict:
            return "Conflict"
        }
    }
    
    /// Whether this status indicates the entity needs to be synced
    var needsSync: Bool {
        switch self {
        case .synced:
            return false
        case .pending, .failed, .conflict:
            return true
        }
    }
}

