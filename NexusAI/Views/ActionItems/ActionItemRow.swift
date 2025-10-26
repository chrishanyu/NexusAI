//
//  ActionItemRow.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import SwiftUI

/// Row component for displaying an action item in a list
struct ActionItemRow: View {
    
    // MARK: - Properties
    
    let item: ActionItem
    let onToggleComplete: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxView
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Task text
                taskTextView
                
                // Metadata badges
                metadataView
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(item.isComplete ? Color(.systemGray6).opacity(0.5) : Color.clear)
        .cornerRadius(12)
    }
    
    // MARK: - Subviews
    
    /// Checkbox for completion toggle
    private var checkboxView: some View {
        Button(action: handleCheckboxTap) {
            ZStack {
                Circle()
                    .strokeBorder(item.isComplete ? Color.green : Color.gray, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if item.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    /// Task description text
    private var taskTextView: some View {
        Text(item.task)
            .font(.body)
            .fontWeight(item.isComplete ? .regular : .semibold)
            .foregroundColor(item.isComplete ? .secondary : .primary)
            .strikethrough(item.isComplete, color: .gray)
    }
    
    /// Metadata badges (assignee, deadline, priority)
    private var metadataView: some View {
        HStack(spacing: 8) {
            // Assignee badge
            if let assignee = item.assignee {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text(assignee)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            
            // Deadline badge
            if let deadlineText = item.relativeDeadlineText {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(deadlineText)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundColor(item.isOverdue ? .red : .blue)
                .cornerRadius(6)
            }
            
            // Priority indicator
            priorityIndicatorView
        }
    }
    
    /// Priority indicator dot
    private var priorityIndicatorView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(item.priority.color)
                .frame(width: 8, height: 8)
            
            Text(item.priority.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    /// Handle checkbox tap with haptic feedback
    private func handleCheckboxTap() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Toggle completion
        onToggleComplete()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Incomplete item with assignee and deadline
        ActionItemRow(
            item: ActionItem(
                conversationId: "test",
                task: "Update API documentation with new endpoints",
                assignee: "Bob Chen",
                messageId: "msg-123",
                extractedAt: Date(),
                isComplete: false,
                deadline: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                priority: .high
            ),
            onToggleComplete: { print("Toggle 1") }
        )
        
        // Incomplete item without assignee
        ActionItemRow(
            item: ActionItem(
                conversationId: "test",
                task: "Review pull request #456",
                assignee: nil,
                messageId: "msg-456",
                extractedAt: Date(),
                isComplete: false,
                deadline: nil,
                priority: .medium
            ),
            onToggleComplete: { print("Toggle 2") }
        )
        
        // Completed item
        ActionItemRow(
            item: ActionItem(
                conversationId: "test",
                task: "Fix login bug",
                assignee: "Alice Johnson",
                messageId: "msg-789",
                extractedAt: Date(),
                isComplete: true,
                deadline: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                priority: .high
            ),
            onToggleComplete: { print("Toggle 3") }
        )
        
        // Overdue item
        ActionItemRow(
            item: ActionItem(
                conversationId: "test",
                task: "Deploy to production",
                assignee: "Carol Davis",
                messageId: "msg-999",
                extractedAt: Date(),
                isComplete: false,
                deadline: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
                priority: .high
            ),
            onToggleComplete: { print("Toggle 4") }
        )
    }
    .padding()
}

