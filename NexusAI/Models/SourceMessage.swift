//
//  SourceMessage.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//

import Foundation
import FirebaseFirestore

/// Represents a source message cited by the AI Assistant
struct SourceMessage: Codable, Identifiable, Hashable {
    let id: String // messageId
    let conversationId: String
    let conversationName: String
    let messageText: String
    let senderName: String
    let timestamp: Timestamp
    let relevanceScore: Double // 0.0 to 1.0
    
    // MARK: - Computed Properties
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let date = timestamp.dateValue()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Truncated message text for preview (max 100 characters)
    var truncatedText: String {
        if messageText.count <= 100 {
            return messageText
        }
        return String(messageText.prefix(97)) + "..."
    }
    
    /// Relevance percentage (0-100)
    var relevancePercentage: Int {
        return Int(relevanceScore * 100)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case conversationName
        case messageText
        case senderName
        case timestamp
        case relevanceScore
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(conversationId)
        hasher.combine(relevanceScore)
    }
    
    static func == (lhs: SourceMessage, rhs: SourceMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.conversationId == rhs.conversationId &&
               lhs.relevanceScore == rhs.relevanceScore
    }
}

