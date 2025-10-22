//
//  BannerData.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation

/// Model representing data for an in-app notification banner
struct BannerData: Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the banner (uses message timestamp)
    let id: UUID
    
    /// ID of the conversation the message belongs to
    let conversationId: String
    
    /// ID of the user who sent the message
    let senderId: String
    
    /// Display name of the sender
    let senderName: String
    
    /// Message text content (will be truncated for display)
    let messageText: String
    
    /// Optional URL for sender's profile image
    let profileImageUrl: String?
    
    /// Timestamp when the message was sent
    let timestamp: Date
    
    // MARK: - Initialization
    
    /// Initialize with explicit properties
    init(
        id: UUID = UUID(),
        conversationId: String,
        senderId: String,
        senderName: String,
        messageText: String,
        profileImageUrl: String? = nil,
        timestamp: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.messageText = messageText
        self.profileImageUrl = profileImageUrl
        self.timestamp = timestamp
    }
    
    /// Convenience initializer to create BannerData from a Message
    /// - Parameter message: The message to convert to banner data
    init(from message: Message) {
        self.id = UUID()
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.messageText = message.text
        self.profileImageUrl = nil // Will be fetched separately if needed
        self.timestamp = message.timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Truncated message text for banner display (max 50 characters)
    var displayText: String {
        if messageText.count <= 50 {
            return messageText
        }
        return String(messageText.prefix(50)) + "..."
    }
    
    // MARK: - Equatable
    
    static func == (lhs: BannerData, rhs: BannerData) -> Bool {
        lhs.id == rhs.id
    }
}

