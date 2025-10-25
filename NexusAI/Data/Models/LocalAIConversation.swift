//
//  LocalAIConversation.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import SwiftData

/// SwiftData model for AI conversation metadata (tracks AI chat usage per conversation)
@available(iOS 17.0, *)
@Model
final class LocalAIConversation {
    
    // MARK: - Identity
    
    /// Unique identifier for this AI conversation record
    @Attribute(.unique) var id: String
    
    /// ID of the conversation thread this AI chat is associated with
    var conversationThreadId: String
    
    // MARK: - Metadata
    
    /// When the AI chat was first created for this conversation
    var createdAt: Date
    
    /// When the AI chat was last updated
    var updatedAt: Date
    
    /// Cached count of messages in this AI conversation
    var messageCount: Int
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        conversationThreadId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messageCount: Int = 0
    ) {
        self.id = id
        self.conversationThreadId = conversationThreadId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
    }
}

