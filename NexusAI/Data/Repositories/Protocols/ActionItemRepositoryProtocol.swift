//
//  ActionItemRepositoryProtocol.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import Foundation

/// Protocol defining action item repository operations
/// ViewModels depend on this protocol, not the concrete implementation
@MainActor
protocol ActionItemRepositoryProtocol {
    
    // MARK: - Observation (Reactive Queries)
    
    /// Observe action items for a conversation with real-time updates
    /// - Parameter conversationId: The conversation ID
    /// - Returns: AsyncStream that emits action items whenever they change
    func observeActionItems(for conversationId: String) -> AsyncStream<[ActionItem]>
    
    // MARK: - Read Operations
    
    /// Get all action items for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Array of action items sorted by deadline and creation date
    func fetch(for conversationId: String) async throws -> [ActionItem]
    
    /// Get all action items, optionally filtered by assignee
    /// - Parameter assignedTo: Optional assignee name to filter by
    /// - Returns: Array of action items
    func fetchAll(assignedTo: String?) async throws -> [ActionItem]
    
    /// Get a single action item by ID
    /// - Parameter itemId: The action item UUID
    /// - Returns: The action item, or nil if not found
    func fetchOne(itemId: UUID) async throws -> ActionItem?
    
    /// Count incomplete action items for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Number of incomplete items
    func countIncomplete(for conversationId: String) async throws -> Int
    
    // MARK: - Write Operations
    
    /// Save multiple action items (batch insert)
    /// - Parameter items: Array of action items to save
    func save(_ items: [ActionItem]) async throws
    
    /// Update completion status of an action item
    /// - Parameters:
    ///   - itemId: The action item UUID
    ///   - isComplete: New completion status
    func update(itemId: UUID, isComplete: Bool) async throws
    
    /// Update an action item with new data
    /// - Parameter item: The updated action item
    func update(item: ActionItem) async throws
    
    /// Delete an action item
    /// - Parameter itemId: The action item UUID to delete
    func delete(itemId: UUID) async throws
    
    /// Delete all action items for a conversation
    /// - Parameter conversationId: The conversation ID
    func deleteAll(for conversationId: String) async throws
}

