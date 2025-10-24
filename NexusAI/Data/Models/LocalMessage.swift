//
//  LocalMessage.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// SwiftData model for local message storage with sync state tracking
@available(iOS 17.0, *)
@Model
final class LocalMessage {
    
    // MARK: - Identity
    
    /// Firestore document ID (unique identifier)
    @Attribute(.unique) var id: String
    
    /// Local UUID for optimistic UI (generated before Firestore ID)
    var localId: String
    
    // MARK: - Content
    
    /// ID of the conversation this message belongs to
    var conversationId: String
    
    /// ID of the user who sent the message
    var senderId: String
    
    /// Display name of the sender
    var senderName: String
    
    /// Message text content
    var text: String
    
    /// When the message was created
    var timestamp: Date
    
    // MARK: - Status & Delivery
    
    /// Message status (sending, sent, delivered, read, failed)
    var statusRaw: String
    
    /// Array of user IDs who have read this message
    var readBy: [String]
    
    /// Array of user IDs who have received this message
    var deliveredTo: [String]
    
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
    
    /// When this local record was created
    var createdAt: Date
    
    /// When this local record was last updated
    var updatedAt: Date
    
    // MARK: - Relationships
    
    /// Optional relationship to conversation (for cascade deletes)
    @Relationship(deleteRule: .nullify, inverse: \LocalConversation.messages)
    var conversation: LocalConversation?
    
    // MARK: - Computed Properties
    
    /// Message status as enum
    var status: MessageStatus {
        get {
            MessageStatus(rawValue: statusRaw) ?? .sent
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
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
        localId: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date,
        status: MessageStatus,
        readBy: [String],
        deliveredTo: [String],
        syncStatus: SyncStatus = .synced,
        lastSyncAttempt: Date? = nil,
        syncRetryCount: Int = 0,
        serverTimestamp: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.localId = localId
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.readBy = readBy
        self.deliveredTo = deliveredTo
        self.syncStatusRaw = syncStatus.rawValue
        self.lastSyncAttempt = lastSyncAttempt
        self.syncRetryCount = syncRetryCount
        self.serverTimestamp = serverTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Conversion Methods
    
    /// Convert LocalMessage to domain Message model
    func toMessage() -> Message {
        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: timestamp,
            status: status,
            readBy: readBy,
            deliveredTo: deliveredTo,
            localId: localId
        )
    }
    
    /// Create LocalMessage from domain Message model
    static func from(_ message: Message, syncStatus: SyncStatus = .synced) -> LocalMessage {
        return LocalMessage(
            id: message.id ?? UUID().uuidString,
            localId: message.localId ?? UUID().uuidString,
            conversationId: message.conversationId,
            senderId: message.senderId,
            senderName: message.senderName,
            text: message.text,
            timestamp: message.timestamp,
            status: message.status,
            readBy: message.readBy,
            deliveredTo: message.deliveredTo,
            syncStatus: syncStatus,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// Update LocalMessage with data from domain Message model
    func update(from message: Message) {
        // Don't update id or localId (these are immutable)
        self.statusRaw = message.status.rawValue
        self.readBy = message.readBy
        self.deliveredTo = message.deliveredTo
        self.timestamp = message.timestamp
        self.updatedAt = Date()
    }
}

