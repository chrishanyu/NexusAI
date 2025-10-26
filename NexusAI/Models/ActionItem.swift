//
//  ActionItem.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import Foundation

/// Represents an action item extracted from a conversation
struct ActionItem: Identifiable, Codable, Hashable {
    /// Unique identifier
    let id: UUID
    
    /// Which conversation this came from
    let conversationId: String
    
    /// Description of what needs to be done (required)
    let task: String
    
    /// Person responsible (optional, can be unassigned)
    let assignee: String?
    
    /// Link to the source message (required)
    let messageId: String
    
    /// When AI extracted this item (required)
    let extractedAt: Date
    
    /// Completion status
    var isComplete: Bool
    
    /// Optional due date if mentioned in conversation
    var deadline: Date?
    
    /// Priority level
    var priority: Priority
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        conversationId: String,
        task: String,
        assignee: String? = nil,
        messageId: String,
        extractedAt: Date = Date(),
        isComplete: Bool = false,
        deadline: Date? = nil,
        priority: Priority = .medium
    ) {
        self.id = id
        self.conversationId = conversationId
        self.task = task
        self.assignee = assignee
        self.messageId = messageId
        self.extractedAt = extractedAt
        self.isComplete = isComplete
        self.deadline = deadline
        self.priority = priority
    }
    
    // MARK: - Computed Properties
    
    /// Whether the action item is overdue
    var isOverdue: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date() && !isComplete
    }
    
    /// Days until deadline (negative if overdue)
    var daysUntilDeadline: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }
    
    /// Human-readable deadline text
    var relativeDeadlineText: String? {
        guard let deadline = deadline else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Check if overdue
        if deadline < now {
            if let days = daysUntilDeadline, days < 0 {
                let overdueDays = abs(days)
                if overdueDays == 0 {
                    return "Overdue today"
                } else if overdueDays == 1 {
                    return "Overdue by 1 day"
                } else {
                    return "Overdue by \(overdueDays) days"
                }
            }
            return "Overdue"
        }
        
        // Check if today
        if calendar.isDateInToday(deadline) {
            return "Due today"
        }
        
        // Check if tomorrow
        if calendar.isDateInTomorrow(deadline) {
            return "Due tomorrow"
        }
        
        // Check if within this week
        if let days = daysUntilDeadline {
            if days <= 7 {
                return "Due in \(days) days"
            }
        }
        
        // For future dates, show formatted date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Due \(formatter.string(from: deadline))"
    }
}

