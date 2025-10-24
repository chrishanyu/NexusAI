//
//  LocalConversation.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

/// SwiftData model for local conversation storage with sync state tracking
@available(iOS 17.0, *)
@Model
final class LocalConversation {
    
    // MARK: - Identity
    
    /// Firestore document ID (unique identifier)
    @Attribute(.unique) var id: String
    
    // MARK: - Content
    
    /// Type of conversation ("direct" or "group")
    var typeRaw: String
    
    /// Array of user IDs participating in this conversation
    var participantIds: [String]
    
    /// Encoded participant info dictionary (userId -> ParticipantInfo)
    /// Stored as Data because SwiftData doesn't support nested dictionaries directly
    var participantsData: Data
    
    /// Group name (only for group conversations)
    var groupName: String?
    
    /// URL to group image (only for group conversations)
    var groupImageUrl: String?
    
    /// User ID of the person who created the group
    var createdBy: String?
    
    // MARK: - Last Message (Denormalized for Performance)
    
    /// Text of the last message in the conversation
    var lastMessageText: String?
    
    /// User ID of the sender of the last message
    var lastMessageSenderId: String?
    
    /// Display name of the sender of the last message
    var lastMessageSenderName: String?
    
    /// Timestamp of the last message
    var lastMessageTimestamp: Date?
    
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
    
    /// When the conversation was created
    var createdAt: Date
    
    /// When the conversation was last updated
    var updatedAt: Date
    
    // MARK: - Relationships
    
    /// Messages belonging to this conversation
    @Relationship(deleteRule: .cascade)
    var messages: [LocalMessage]?
    
    // MARK: - Computed Properties
    
    /// Conversation type as enum
    var type: ConversationType {
        get {
            ConversationType(rawValue: typeRaw) ?? .direct
        }
        set {
            typeRaw = newValue.rawValue
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
    
    /// Decoded participants dictionary
    var participants: [String: Conversation.ParticipantInfo] {
        get {
            guard let decoded = try? JSONDecoder().decode([String: Conversation.ParticipantInfo].self, from: participantsData) else {
                return [:]
            }
            return decoded
        }
        set {
            participantsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    /// Last message as structured type
    var lastMessage: Conversation.LastMessage? {
        get {
            guard let text = lastMessageText,
                  let senderId = lastMessageSenderId,
                  let senderName = lastMessageSenderName,
                  let timestamp = lastMessageTimestamp else {
                return nil
            }
            return Conversation.LastMessage(
                text: text,
                senderId: senderId,
                senderName: senderName,
                timestamp: timestamp
            )
        }
        set {
            lastMessageText = newValue?.text
            lastMessageSenderId = newValue?.senderId
            lastMessageSenderName = newValue?.senderName
            lastMessageTimestamp = newValue?.timestamp
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        type: ConversationType,
        participantIds: [String],
        participants: [String: Conversation.ParticipantInfo],
        groupName: String?,
        groupImageUrl: String?,
        createdBy: String?,
        lastMessage: Conversation.LastMessage?,
        syncStatus: SyncStatus = .synced,
        lastSyncAttempt: Date? = nil,
        syncRetryCount: Int = 0,
        serverTimestamp: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.participantIds = participantIds
        self.participantsData = (try? JSONEncoder().encode(participants)) ?? Data()
        self.groupName = groupName
        self.groupImageUrl = groupImageUrl
        self.createdBy = createdBy
        self.lastMessageText = lastMessage?.text
        self.lastMessageSenderId = lastMessage?.senderId
        self.lastMessageSenderName = lastMessage?.senderName
        self.lastMessageTimestamp = lastMessage?.timestamp
        self.syncStatusRaw = syncStatus.rawValue
        self.lastSyncAttempt = lastSyncAttempt
        self.syncRetryCount = syncRetryCount
        self.serverTimestamp = serverTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Conversion Methods
    
    /// Convert LocalConversation to domain Conversation model
    func toConversation() -> Conversation {
        return Conversation(
            id: id,
            type: type,
            participantIds: participantIds,
            participants: participants,
            lastMessage: lastMessage,
            groupName: groupName,
            groupImageUrl: groupImageUrl,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Create LocalConversation from domain Conversation model
    static func from(_ conversation: Conversation, syncStatus: SyncStatus = .synced) -> LocalConversation {
        return LocalConversation(
            id: conversation.id ?? UUID().uuidString,
            type: conversation.type,
            participantIds: conversation.participantIds,
            participants: conversation.participants,
            groupName: conversation.groupName,
            groupImageUrl: conversation.groupImageUrl,
            createdBy: conversation.createdBy,
            lastMessage: conversation.lastMessage,
            syncStatus: syncStatus,
            lastSyncAttempt: nil,
            syncRetryCount: 0,
            serverTimestamp: nil,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt ?? Date()
        )
    }
    
    /// Update LocalConversation with data from domain Conversation model
    func update(from conversation: Conversation) {
        self.typeRaw = conversation.type.rawValue
        self.participantIds = conversation.participantIds
        self.participants = conversation.participants
        self.groupName = conversation.groupName
        self.groupImageUrl = conversation.groupImageUrl
        self.createdBy = conversation.createdBy
        self.lastMessage = conversation.lastMessage
        self.updatedAt = conversation.updatedAt ?? Date()
    }
}

