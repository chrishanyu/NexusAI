//
//  AIMessageRepository.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import SwiftData

/// Repository for managing AI assistant messages (local storage only)
@MainActor
final class AIMessageRepository {
    
    private let database: LocalDatabase
    
    init(database: LocalDatabase? = nil) {
        self.database = database ?? LocalDatabase.shared
    }
    
    // MARK: - Observation
    
    /// Observe AI messages for a specific conversation in real-time
    /// - Parameter conversationId: The conversation ID
    /// - Returns: AsyncStream of AI message arrays
    func observeMessages(conversationId: String) -> AsyncStream<[LocalAIMessage]> {
        let predicate = #Predicate<LocalAIMessage> { message in
            message.conversationId == conversationId
        }
        
        return database.observe(
            LocalAIMessage.self,
            where: predicate,
            sortBy: [SortDescriptor(\LocalAIMessage.sequenceNumber, order: .forward)]
        )
    }
    
    // MARK: - Read Operations
    
    /// Fetch all AI messages for a specific conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Array of AI messages sorted by sequence number
    func fetchMessages(for conversationId: String) async throws -> [LocalAIMessage] {
        let predicate = #Predicate<LocalAIMessage> { message in
            message.conversationId == conversationId
        }
        
        return try database.fetch(
            LocalAIMessage.self,
            where: predicate,
            sortBy: [SortDescriptor(\LocalAIMessage.sequenceNumber, order: .forward)]
        )
    }
    
    /// Get the count of AI messages for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Number of messages
    func getMessageCount(for conversationId: String) async throws -> Int {
        let predicate = #Predicate<LocalAIMessage> { message in
            message.conversationId == conversationId
        }
        
        return try database.count(LocalAIMessage.self, where: predicate)
    }
    
    /// Get the next sequence number for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: The next sequence number to use
    func getNextSequenceNumber(for conversationId: String) async throws -> Int {
        let messages = try await fetchMessages(for: conversationId)
        return messages.last?.sequenceNumber ?? -1 + 1
    }
    
    // MARK: - Write Operations
    
    /// Save a new AI message
    /// - Parameters:
    ///   - text: The message text
    ///   - isFromAI: Whether the message is from AI or user
    ///   - conversationId: The conversation ID
    /// - Returns: The saved message
    @discardableResult
    func saveMessage(
        text: String,
        isFromAI: Bool,
        conversationId: String
    ) async throws -> LocalAIMessage {
        let sequenceNumber = try await getNextSequenceNumber(for: conversationId)
        
        let message = LocalAIMessage(
            conversationId: conversationId,
            text: text,
            isFromAI: isFromAI,
            timestamp: Date(),
            sequenceNumber: sequenceNumber
        )
        
        try database.insert(message)
        
        // Update or create AI conversation metadata
        try await updateConversationMetadata(conversationId: conversationId)
        
        // Notify observers
        database.notifyChanges()
        
        return message
    }
    
    /// Save multiple AI messages (batch operation)
    /// - Parameters:
    ///   - messages: Array of tuples (text, isFromAI)
    ///   - conversationId: The conversation ID
    func saveMessages(
        _ messages: [(text: String, isFromAI: Bool)],
        conversationId: String
    ) async throws {
        var sequenceNumber = try await getNextSequenceNumber(for: conversationId)
        
        let aiMessages = messages.map { message in
            let aiMessage = LocalAIMessage(
                conversationId: conversationId,
                text: message.text,
                isFromAI: message.isFromAI,
                timestamp: Date(),
                sequenceNumber: sequenceNumber
            )
            sequenceNumber += 1
            return aiMessage
        }
        
        try database.insertBatch(aiMessages)
        
        // Update AI conversation metadata
        try await updateConversationMetadata(conversationId: conversationId)
        
        // Notify observers
        database.notifyChanges()
    }
    
    // MARK: - Delete Operations
    
    /// Clear all AI messages for a specific conversation
    /// - Parameter conversationId: The conversation ID
    func clearMessages(for conversationId: String) async throws {
        let predicate = #Predicate<LocalAIMessage> { message in
            message.conversationId == conversationId
        }
        
        try database.deleteAll(LocalAIMessage.self, where: predicate)
        
        // Also delete the AI conversation metadata
        let metadataPredicate = #Predicate<LocalAIConversation> { aiConv in
            aiConv.conversationThreadId == conversationId
        }
        try database.deleteAll(LocalAIConversation.self, where: metadataPredicate)
        
        // Notify observers
        database.notifyChanges()
    }
    
    /// Delete a specific AI message
    /// - Parameter message: The message to delete
    func deleteMessage(_ message: LocalAIMessage) async throws {
        try database.delete(message)
        
        // Update conversation metadata
        try await updateConversationMetadata(conversationId: message.conversationId)
        
        // Notify observers
        database.notifyChanges()
    }
    
    // MARK: - Metadata Management
    
    /// Get or create AI conversation metadata
    /// - Parameter conversationId: The conversation ID
    /// - Returns: The AI conversation metadata
    func getOrCreateMetadata(for conversationId: String) async throws -> LocalAIConversation {
        let predicate = #Predicate<LocalAIConversation> { aiConv in
            aiConv.conversationThreadId == conversationId
        }
        
        if let existing = try database.fetchOne(LocalAIConversation.self, where: predicate) {
            return existing
        }
        
        // Create new metadata
        let metadata = LocalAIConversation(conversationThreadId: conversationId)
        try database.insert(metadata)
        return metadata
    }
    
    /// Update AI conversation metadata (message count, updated timestamp)
    /// - Parameter conversationId: The conversation ID
    private func updateConversationMetadata(conversationId: String) async throws {
        let metadata = try await getOrCreateMetadata(for: conversationId)
        let count = try await getMessageCount(for: conversationId)
        
        metadata.messageCount = count
        metadata.updatedAt = Date()
        
        try database.update(metadata)
    }
    
    // MARK: - Utility
    
    /// Check if a conversation has any AI messages
    /// - Parameter conversationId: The conversation ID
    /// - Returns: True if conversation has AI messages
    func hasMessages(for conversationId: String) async throws -> Bool {
        let count = try await getMessageCount(for: conversationId)
        return count > 0
    }
}

