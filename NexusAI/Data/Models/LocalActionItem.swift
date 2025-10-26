//
//  LocalActionItem.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import Foundation
import SwiftData

/// SwiftData model for local action item storage
@available(iOS 17.0, *)
@Model
final class LocalActionItem {
    
    // MARK: - Identity
    
    /// Unique identifier
    @Attribute(.unique) var id: String
    
    // MARK: - Core Properties
    
    /// Which conversation this came from
    var conversationId: String
    
    /// Description of what needs to be done (required)
    var task: String
    
    /// Person responsible (optional, can be unassigned)
    var assignee: String?
    
    /// Link to the source message (required)
    var messageId: String
    
    /// When AI extracted this item (required)
    var extractedAt: Date
    
    /// Completion status
    var isComplete: Bool
    
    /// Optional due date if mentioned in conversation
    var deadline: Date?
    
    /// Priority level stored as raw string value
    var priorityRaw: String
    
    // MARK: - Metadata
    
    /// When this local record was created
    var createdAt: Date
    
    /// When this local record was last updated
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Priority as enum
    var priority: Priority {
        get {
            Priority(rawValue: priorityRaw) ?? .medium
        }
        set {
            priorityRaw = newValue.rawValue
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        conversationId: String,
        task: String,
        assignee: String? = nil,
        messageId: String,
        extractedAt: Date,
        isComplete: Bool = false,
        deadline: Date? = nil,
        priority: Priority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.task = task
        self.assignee = assignee
        self.messageId = messageId
        self.extractedAt = extractedAt
        self.isComplete = isComplete
        self.deadline = deadline
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Conversion Methods
    
    /// Convert LocalActionItem to domain ActionItem model
    func toActionItem() -> ActionItem {
        return ActionItem(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: conversationId,
            task: task,
            assignee: assignee,
            messageId: messageId,
            extractedAt: extractedAt,
            isComplete: isComplete,
            deadline: deadline,
            priority: priority
        )
    }
    
    /// Create LocalActionItem from domain ActionItem model
    static func from(_ actionItem: ActionItem) -> LocalActionItem {
        return LocalActionItem(
            id: actionItem.id.uuidString,
            conversationId: actionItem.conversationId,
            task: actionItem.task,
            assignee: actionItem.assignee,
            messageId: actionItem.messageId,
            extractedAt: actionItem.extractedAt,
            isComplete: actionItem.isComplete,
            deadline: actionItem.deadline,
            priority: actionItem.priority,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// Update LocalActionItem with data from domain ActionItem model
    func update(from actionItem: ActionItem) {
        // Don't update id, conversationId, messageId, extractedAt (these are immutable)
        self.task = actionItem.task
        self.assignee = actionItem.assignee
        self.isComplete = actionItem.isComplete
        self.deadline = actionItem.deadline
        self.priorityRaw = actionItem.priority.rawValue
        self.updatedAt = Date()
    }
}

