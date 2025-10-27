//
//  RAGResponse.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//

import Foundation

/// Response from RAG query containing AI-generated answer and source citations
struct RAGResponse: Codable {
    let answer: String
    let sources: [SourceMessage]
    let queryTime: String // ISO 8601 timestamp
    
    // MARK: - Computed Properties
    
    /// Number of source messages cited
    var sourceCount: Int {
        return sources.count
    }
    
    /// Unique conversations referenced in sources
    var conversationCount: Int {
        return Set(sources.map { $0.conversationId }).count
    }
    
    /// Formatted query time as Date
    var queryDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: queryTime)
    }
}

