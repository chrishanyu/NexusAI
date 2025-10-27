//
//  SourceMessageCard.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//  Displays source message attribution with tap navigation
//

import SwiftUI
import FirebaseFirestore

/// Card displaying a source message that the AI used to generate its response
struct SourceMessageCard: View {
    let source: SourceMessage
    var onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header: Conversation name + relevance score
                HStack {
                    // Conversation icon + name
                    HStack(spacing: 6) {
                        Image(systemName: conversationIcon)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(source.conversationName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Relevance score badge
                    if source.relevanceScore > 0.7 {
                        relevanceScoreBadge
                    }
                }
                
                // Message excerpt
                Text(source.truncatedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Footer: Sender + timestamp
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(source.senderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(source.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Navigation arrow
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    // MARK: - Conversation Icon
    
    private var conversationIcon: String {
        // Could be enhanced to detect group vs direct message
        // For now, use generic message icon
        return "bubble.left.and.bubble.right.fill"
    }
    
    // MARK: - Relevance Score Badge
    
    private var relevanceScoreBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("\(source.relevancePercentage)%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.blue.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
    }
}

// MARK: - Preview Provider

#Preview {
    VStack(spacing: 12) {
        // High relevance source
        SourceMessageCard(
            source: SourceMessage(
                id: "msg1",
                conversationId: "conv1",
                conversationName: "Product Team",
                messageText: "Let's go with November 15th for the launch. We need to finish mobile features first before desktop. I think this timeline gives us enough buffer for testing.",
                senderName: "Sarah Chen",
                timestamp: .init(date: Date().addingTimeInterval(-86400 * 6)),
                relevanceScore: 0.95
            )
        ) {
            print("Tapped high relevance source")
        }
        
        // Medium relevance source
        SourceMessageCard(
            source: SourceMessage(
                id: "msg2",
                conversationId: "conv2",
                conversationName: "Engineering",
                messageText: "Agreed. Mobile is our priority. Desktop can wait until December.",
                senderName: "Alex Johnson",
                timestamp: .init(date: Date().addingTimeInterval(-3600 * 2)),
                relevanceScore: 0.78
            )
        ) {
            print("Tapped medium relevance source")
        }
        
        // Lower relevance source (no badge)
        SourceMessageCard(
            source: SourceMessage(
                id: "msg3",
                conversationId: "conv3",
                conversationName: "Design Team",
                messageText: "Short message",
                senderName: "Jamie Lee",
                timestamp: .init(date: Date().addingTimeInterval(-60)),
                relevanceScore: 0.65
            )
        ) {
            print("Tapped lower relevance source")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

