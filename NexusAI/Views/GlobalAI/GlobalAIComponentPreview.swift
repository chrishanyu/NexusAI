//
//  GlobalAIComponentPreview.swift
//  NexusAI
//
//  Preview/testing file for Global AI components
//  This file demonstrates the new UI components working together
//

import SwiftUI
import FirebaseFirestore

/// Preview view showing all Global AI components in action
struct GlobalAIComponentPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Global AI Components Demo")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Divider()
                
                // Example conversation
                exampleConversation
                
                Divider()
                    .padding(.vertical)
                
                // Individual component tests
                Text("Individual Components:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                sourceCardExamples
            }
            .padding()
        }
    }
    
    // MARK: - Example Conversation
    
    private var exampleConversation: some View {
        VStack(spacing: 16) {
            // User asks a question
            GlobalAIMessageBubbleView(
                message: .userMessage("What did we decide about the Q4 roadmap?")
            )
            
            // AI responds with sources
            GlobalAIMessageBubbleView(
                message: ConversationMessage(
                    isUser: false,
                    text: """
                    Based on your conversations, here's what was decided for Q4:
                    
                    **Launch Date:** November 15th
                    **Priority:** Mobile features first, desktop in December
                    **Key Milestones:**
                    - Mobile app beta by Oct 30
                    - Testing phase Nov 1-10
                    - Production release Nov 15
                    
                    The team reached consensus that this timeline provides adequate buffer for testing and bug fixes.
                    """,
                    sources: [
                        SourceMessage(
                            id: "msg1",
                            conversationId: "conv1",
                            conversationName: "Product Team",
                            messageText: "Let's go with November 15th for the launch. We need to finish mobile features first before desktop. I think this timeline gives us enough buffer for testing and any last-minute fixes.",
                            senderName: "Sarah Chen",
                            timestamp: .init(date: Date().addingTimeInterval(-86400 * 6)),
                            relevanceScore: 0.95
                        ),
                        SourceMessage(
                            id: "msg2",
                            conversationId: "conv1",
                            conversationName: "Product Team",
                            messageText: "Agreed. Mobile is our priority. Desktop can wait until December. Let's focus on getting mobile right first.",
                            senderName: "Alex Johnson",
                            timestamp: .init(date: Date().addingTimeInterval(-86400 * 6)),
                            relevanceScore: 0.88
                        ),
                        SourceMessage(
                            id: "msg3",
                            conversationId: "conv2",
                            conversationName: "Engineering",
                            messageText: "The testing phase from Nov 1-10 should be sufficient. We've done this before and 10 days worked well.",
                            senderName: "Jamie Lee",
                            timestamp: .init(date: Date().addingTimeInterval(-86400 * 5)),
                            relevanceScore: 0.82
                        )
                    ]
                )
            ) { source in
                print("Tapped source: \(source.conversationName) - \(source.senderName)")
            }
            
            // User follow-up
            GlobalAIMessageBubbleView(
                message: .userMessage("What about the testing phase?")
            )
            
            // Loading state
            GlobalAIMessageBubbleView(
                message: .loadingMessage()
            )
        }
    }
    
    // MARK: - Source Card Examples
    
    private var sourceCardExamples: some View {
        VStack(spacing: 12) {
            // High relevance
            SourceMessageCard(
                source: SourceMessage(
                    id: "test1",
                    conversationId: "conv1",
                    conversationName: "Design Team",
                    messageText: "The new UI mockups look amazing! I especially love the color scheme. Should we proceed with this direction?",
                    senderName: "Morgan Davis",
                    timestamp: .init(date: Date().addingTimeInterval(-3600 * 2)),
                    relevanceScore: 0.92
                )
            ) {
                print("Tapped high relevance source")
            }
            
            // Medium relevance
            SourceMessageCard(
                source: SourceMessage(
                    id: "test2",
                    conversationId: "conv2",
                    conversationName: "Engineering Standup",
                    messageText: "Quick update: API integration is 80% complete. Should be done by tomorrow.",
                    senderName: "Taylor Swift",
                    timestamp: .init(date: Date().addingTimeInterval(-86400)),
                    relevanceScore: 0.76
                )
            ) {
                print("Tapped medium relevance source")
            }
            
            // Lower relevance (no badge)
            SourceMessageCard(
                source: SourceMessage(
                    id: "test3",
                    conversationId: "conv3",
                    conversationName: "Random Chat",
                    messageText: "Anyone up for coffee?",
                    senderName: "Jordan Kim",
                    timestamp: .init(date: Date().addingTimeInterval(-60 * 15)),
                    relevanceScore: 0.45
                )
            ) {
                print("Tapped lower relevance source")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GlobalAIComponentPreview()
}

