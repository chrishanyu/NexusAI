//
//  ActionItemRepository.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import Foundation
import SwiftData

/// Concrete implementation of ActionItemRepositoryProtocol
/// Manages CRUD operations for action items using LocalDatabase
@MainActor
final class ActionItemRepository: ActionItemRepositoryProtocol {
    
    private let database: LocalDatabase
    
    init(database: LocalDatabase? = nil) {
        self.database = database ?? LocalDatabase.shared
    }
    
    // MARK: - Observation
    
    func observeActionItems(for conversationId: String) -> AsyncStream<[ActionItem]> {
        let predicate = #Predicate<LocalActionItem> { item in
            item.conversationId == conversationId
        }
        
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                let stream = database.observe(LocalActionItem.self, where: predicate)
                
                for await localItems in stream {
                    // Sort manually (completion status, then deadline, then created date)
                    let sorted = localItems.sorted { item1, item2 in
                        // Incomplete items first
                        if item1.isComplete != item2.isComplete {
                            return !item1.isComplete
                        }
                        // Then by deadline (items with deadlines come first)
                        if let deadline1 = item1.deadline, let deadline2 = item2.deadline {
                            return deadline1 < deadline2
                        } else if item1.deadline != nil {
                            return true
                        } else if item2.deadline != nil {
                            return false
                        }
                        // Finally by extracted date (most recent first)
                        return item1.extractedAt > item2.extractedAt
                    }
                    
                    let items = sorted.map { $0.toActionItem() }
                    continuation.yield(items)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Read Operations
    
    func fetch(for conversationId: String) async throws -> [ActionItem] {
        let predicate = #Predicate<LocalActionItem> { item in
            item.conversationId == conversationId
        }
        
        let localItems = try database.fetch(LocalActionItem.self, where: predicate)
        
        // Sort manually (completion status, then deadline, then created date)
        let sorted = localItems.sorted { item1, item2 in
            // Incomplete items first
            if item1.isComplete != item2.isComplete {
                return !item1.isComplete
            }
            // Then by deadline (items with deadlines come first)
            if let deadline1 = item1.deadline, let deadline2 = item2.deadline {
                return deadline1 < deadline2
            } else if item1.deadline != nil {
                return true
            } else if item2.deadline != nil {
                return false
            }
            // Finally by extracted date (most recent first)
            return item1.extractedAt > item2.extractedAt
        }
        
        return sorted.map { $0.toActionItem() }
    }
    
    func fetchAll(assignedTo: String? = nil) async throws -> [ActionItem] {
        let allItems = try database.fetch(LocalActionItem.self)
        
        // Sort manually (completion status, then deadline, then created date)
        let sorted = allItems.sorted { item1, item2 in
            // Incomplete items first
            if item1.isComplete != item2.isComplete {
                return !item1.isComplete
            }
            // Then by deadline (items with deadlines come first)
            if let deadline1 = item1.deadline, let deadline2 = item2.deadline {
                return deadline1 < deadline2
            } else if item1.deadline != nil {
                return true
            } else if item2.deadline != nil {
                return false
            }
            // Finally by extracted date (most recent first)
            return item1.extractedAt > item2.extractedAt
        }
        
        // Filter by assignee if provided
        if let assignedTo = assignedTo {
            let filtered = sorted.filter { $0.assignee == assignedTo }
            return filtered.map { $0.toActionItem() }
        }
        
        return sorted.map { $0.toActionItem() }
    }
    
    func fetchOne(itemId: UUID) async throws -> ActionItem? {
        let idString = itemId.uuidString
        let predicate = #Predicate<LocalActionItem> { item in
            item.id == idString
        }
        
        guard let localItem = try database.fetchOne(LocalActionItem.self, where: predicate) else {
            return nil
        }
        
        return localItem.toActionItem()
    }
    
    func countIncomplete(for conversationId: String) async throws -> Int {
        let predicate = #Predicate<LocalActionItem> { item in
            item.conversationId == conversationId && item.isComplete == false
        }
        
        return try database.count(LocalActionItem.self, where: predicate)
    }
    
    // MARK: - Write Operations
    
    func save(_ items: [ActionItem]) async throws {
        // Convert to local models
        let localItems = items.map { LocalActionItem.from($0) }
        
        // Batch insert
        try database.insertBatch(localItems)
        
        // Notify observers
        database.notifyChanges()
        
        print("✅ Saved \(items.count) action item(s)")
    }
    
    func update(itemId: UUID, isComplete: Bool) async throws {
        let idString = itemId.uuidString
        let predicate = #Predicate<LocalActionItem> { item in
            item.id == idString
        }
        
        guard let localItem = try database.fetchOne(LocalActionItem.self, where: predicate) else {
            throw DatabaseError.entityNotFound("Action item with id \(itemId) not found")
        }
        
        // Update completion status
        localItem.isComplete = isComplete
        localItem.updatedAt = Date()
        
        try database.update(localItem)
        database.notifyChanges()
        
        print("✅ Updated action item completion: \(isComplete)")
    }
    
    func update(item: ActionItem) async throws {
        let idString = item.id.uuidString
        let predicate = #Predicate<LocalActionItem> { localItem in
            localItem.id == idString
        }
        
        guard let localItem = try database.fetchOne(LocalActionItem.self, where: predicate) else {
            throw DatabaseError.entityNotFound("Action item with id \(item.id) not found")
        }
        
        // Update with new data
        localItem.update(from: item)
        
        try database.update(localItem)
        database.notifyChanges()
        
        print("✅ Updated action item: \(item.task)")
    }
    
    func delete(itemId: UUID) async throws {
        let idString = itemId.uuidString
        let predicate = #Predicate<LocalActionItem> { item in
            item.id == idString
        }
        
        guard let localItem = try database.fetchOne(LocalActionItem.self, where: predicate) else {
            throw DatabaseError.entityNotFound("Action item with id \(itemId) not found")
        }
        
        try database.delete(localItem)
        database.notifyChanges()
        
        print("✅ Deleted action item")
    }
    
    func deleteAll(for conversationId: String) async throws {
        let predicate = #Predicate<LocalActionItem> { item in
            item.conversationId == conversationId
        }
        
        try database.deleteAll(LocalActionItem.self, where: predicate)
        database.notifyChanges()
        
        print("✅ Deleted all action items for conversation \(conversationId)")
    }
}

