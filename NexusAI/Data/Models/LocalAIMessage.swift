//
//  LocalAIMessage.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import SwiftData

/// SwiftData model for AI assistant messages (local storage only, no Firebase sync)
@available(iOS 17.0, *)
@Model
final class LocalAIMessage {
    
    // MARK: - Identity
    
    /// Unique identifier for this AI message
    @Attribute(.unique) var id: String
    
    // MARK: - Content
    
    /// The conversation thread this AI chat belongs to
    var conversationId: String
    
    /// Message text content
    var text: String
    
    /// Whether this message is from the AI (true) or from the user (false)
    var isFromAI: Bool
    
    /// When the message was created
    var timestamp: Date
    
    /// Sequence number for ordering messages (0, 1, 2, ...)
    var sequenceNumber: Int
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        text: String,
        isFromAI: Bool,
        timestamp: Date = Date(),
        sequenceNumber: Int
    ) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.isFromAI = isFromAI
        self.timestamp = timestamp
        self.sequenceNumber = sequenceNumber
    }
}

