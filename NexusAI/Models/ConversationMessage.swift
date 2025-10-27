//
//  ConversationMessage.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//  Display model for AI chat interface (different from regular Message model)
//

import Foundation

/// Represents a message in the AI Assistant chat interface
struct ConversationMessage: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool // true if user message, false if AI response
    let text: String
    let timestamp: Date
    var sources: [SourceMessage]? // Only populated for AI responses
    var isLoading: Bool // true when AI is generating response
    
    // MARK: - Initializers
    
    init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        sources: [SourceMessage]? = nil,
        isLoading: Bool = false
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.sources = sources
        self.isLoading = isLoading
    }
    
    // MARK: - Factory Methods
    
    /// Create a user message
    static func userMessage(_ text: String) -> ConversationMessage {
        return ConversationMessage(
            isUser: true,
            text: text,
            sources: nil,
            isLoading: false
        )
    }
    
    /// Create a loading AI message (placeholder while generating)
    static func loadingMessage() -> ConversationMessage {
        return ConversationMessage(
            isUser: false,
            text: "Searching your conversations...",
            sources: nil,
            isLoading: true
        )
    }
    
    /// Create an AI response message
    static func aiMessage(_ text: String, sources: [SourceMessage]) -> ConversationMessage {
        return ConversationMessage(
            isUser: false,
            text: text,
            sources: sources,
            isLoading: false
        )
    }
    
    /// Create an error message
    static func errorMessage(_ error: String) -> ConversationMessage {
        return ConversationMessage(
            isUser: false,
            text: "❌ " + error,
            sources: nil,
            isLoading: false
        )
    }
    
    // MARK: - Computed Properties
    
    /// Formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Has sources (for AI messages)
    var hasSources: Bool {
        return sources?.isEmpty == false
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isUser == rhs.isUser &&
               lhs.text == rhs.text &&
               lhs.isLoading == rhs.isLoading
    }
}

