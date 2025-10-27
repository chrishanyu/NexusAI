//
//  RAGQuery.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//

import Foundation

/// Represents a user query to the RAG AI Assistant
struct RAGQuery: Identifiable {
    let id: UUID
    let question: String
    let userId: String
    let timestamp: Date
    
    init(id: UUID = UUID(), question: String, userId: String, timestamp: Date = Date()) {
        self.id = id
        self.question = question
        self.userId = userId
        self.timestamp = timestamp
    }
}

