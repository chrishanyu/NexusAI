//
//  MessageQueueService.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import Foundation
import SwiftData
import Combine

/// Service for managing offline message queue
@available(iOS 17.0, *)
@MainActor
class MessageQueueService: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for global queue management
    static let shared = MessageQueueService()
    
    // MARK: - Properties
    
    /// Local storage service for SwiftData operations
    private let localStorageService = LocalStorageService.shared
    
    /// Message service for sending queued messages
    private let messageService = MessageService()
    
    // MARK: - Published Properties
    
    /// Number of messages currently in queue
    @Published var queuedMessageCount: Int = 0
    
    /// Whether queue is currently being flushed
    @Published var isFlushing: Bool = false
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Update queue count on initialization
        updateQueueCount()
    }
    
    // MARK: - Public Methods
    
    /// Add a message to the offline queue
    /// - Parameter message: The message to enqueue
    /// - Throws: Storage error if save fails
    func enqueue(message: Message) throws {
        try localStorageService.enqueueMessage(message)
        updateQueueCount()
        print("Message enqueued. Queue count: \(queuedMessageCount)")
    }
    
    /// Get all queued messages sorted by timestamp
    /// - Returns: Array of queued messages
    /// - Throws: Storage error if fetch fails
    func getQueuedMessages() throws -> [QueuedMessage] {
        let messages = try localStorageService.getQueuedMessages()
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Remove a message from the queue by localId
    /// - Parameter localId: The local ID of the message to remove
    /// - Throws: Storage error if deletion fails
    func removeFromQueue(localId: String) throws {
        let messages = try getQueuedMessages()
        
        if let messageToRemove = messages.first(where: { $0.localId == localId }) {
            try localStorageService.dequeueMessage(messageToRemove)
            updateQueueCount()
            print("Message removed from queue. Queue count: \(queuedMessageCount)")
        } else {
            print("Warning: Message with localId \(localId) not found in queue")
        }
    }
    
    /// Clear all messages from the queue
    /// - Throws: Storage error if clear fails
    func clearQueue() throws {
        try localStorageService.clearMessageQueue()
        updateQueueCount()
        print("Queue cleared")
    }
    
    /// Check if a message with the given localId is in the queue
    /// - Parameter localId: The local ID to check
    /// - Returns: True if the message is queued, false otherwise
    func isMessageQueued(localId: String) -> Bool {
        do {
            let messages = try getQueuedMessages()
            return messages.contains { $0.localId == localId }
        } catch {
            print("Error checking queue status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Flush all queued messages by attempting to send them
    /// This method is typically called when network connectivity is restored
    /// - Returns: Array of flush results for each message
    func flushQueue() async -> [FlushResult] {
        // Prevent concurrent flushes
        guard !isFlushing else {
            print("Queue flush already in progress")
            return []
        }
        
        isFlushing = true
        defer { isFlushing = false }
        
        var results: [FlushResult] = []
        
        do {
            // Fetch all queued messages (already sorted by timestamp)
            let queuedMessages = try getQueuedMessages()
            
            guard !queuedMessages.isEmpty else {
                print("No queued messages to flush")
                return []
            }
            
            print("Flushing \(queuedMessages.count) queued message(s)")
            
            // Process each message in order
            for queuedMessage in queuedMessages {
                let result = await sendQueuedMessage(queuedMessage)
                results.append(result)
            }
            
            // Update queue count after flush
            updateQueueCount()
            
            let successCount = results.filter { $0.success }.count
            let failureCount = results.count - successCount
            print("Queue flush complete: \(successCount) succeeded, \(failureCount) failed")
            
        } catch {
            print("Error flushing queue: \(error.localizedDescription)")
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    /// Send a single queued message
    /// - Parameter queuedMessage: The queued message to send
    /// - Returns: Flush result indicating success or failure
    private func sendQueuedMessage(_ queuedMessage: QueuedMessage) async -> FlushResult {
        do {
            // Attempt to send the message
            let messageId = try await messageService.sendMessage(
                conversationId: queuedMessage.conversationId,
                text: queuedMessage.text,
                senderId: queuedMessage.senderId,
                senderName: queuedMessage.senderName,
                localId: queuedMessage.localId
            )
            
            // Success: remove from queue
            try await MainActor.run {
                try self.removeFromQueue(localId: queuedMessage.localId)
            }
            
            print("✅ Queued message sent successfully: \(queuedMessage.localId)")
            
            return FlushResult(
                localId: queuedMessage.localId,
                success: true,
                messageId: messageId,
                error: nil
            )
            
        } catch {
            // Failure: keep in queue
            print("❌ Failed to send queued message \(queuedMessage.localId): \(error.localizedDescription)")
            
            return FlushResult(
                localId: queuedMessage.localId,
                success: false,
                messageId: nil,
                error: error
            )
        }
    }
    
    /// Update the published queue count
    private func updateQueueCount() {
        do {
            queuedMessageCount = try getQueuedMessages().count
        } catch {
            print("Error updating queue count: \(error.localizedDescription)")
            queuedMessageCount = 0
        }
    }
}

// MARK: - Flush Result

/// Result of attempting to send a queued message
struct FlushResult {
    /// Local ID of the message
    let localId: String
    
    /// Whether the message was sent successfully
    let success: Bool
    
    /// Firestore message ID if successful
    let messageId: String?
    
    /// Error if failed
    let error: Error?
}
