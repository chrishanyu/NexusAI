//
//  GlobalAIMessageBubbleView.swift
//  NexusAI
//
//  Created for RAG AI Assistant feature
//  Adapted from existing AIMessageBubbleView.swift
//

import SwiftUI
import FirebaseFirestore

/// Message bubble for Global AI Assistant chat
/// Uses ConversationMessage model (includes sources) vs LocalAIMessage
struct GlobalAIMessageBubbleView: View {
    let message: ConversationMessage
    var onSourceTap: ((SourceMessage) -> Void)?
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Message bubble
            messageBubble
            
            // Source attribution (only for AI messages with sources)
            if !message.isUser, let sources = message.sources, !sources.isEmpty {
                sourceAttributionSection(sources: sources)
            }
        }
    }
    
    // MARK: - Message Bubble
    
    private var messageBubble: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Sender label
                HStack(spacing: 6) {
                    if !message.isUser {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Text(message.isUser ? "You" : "AI Assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Message text with native Markdown support
                if message.isLoading {
                    loadingBubble
                } else {
                    textBubble
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    // MARK: - Text Bubble
    
    private var textBubble: some View {
        Text(LocalizedStringKey(message.text))  // Enables automatic Markdown parsing
            .font(.body)
            .textSelection(.enabled)  // Allow text selection/copying
            .tint(.purple)  // Links will be purple to match AI theme
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                message.isUser
                    ? LinearGradient(
                        colors: [Color.gray.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        message.isUser
                            ? LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - Loading Bubble
    
    private var loadingBubble: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Searching your conversations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Source Attribution Section
    
    private func sourceAttributionSection(sources: [SourceMessage]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("Based on \(sources.count) \(sources.count == 1 ? "message" : "messages"):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // Source cards
            ForEach(sources) { source in
                SourceMessageCard(source: source) {
                    onSourceTap?(source)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }
}

// MARK: - Preview Provider

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // User message
            GlobalAIMessageBubbleView(
                message: ConversationMessage(
                    isUser: true,
                    text: "What did we decide about the Q4 roadmap?"
                )
            )
            
            // AI response with sources
            GlobalAIMessageBubbleView(
                message: ConversationMessage(
                    isUser: false,
                    text: "Based on your conversation with Sarah on **Oct 20**, you decided to **launch on November 15th**. The team agreed to prioritize the mobile features first.",
                    sources: [
                        SourceMessage(
                            id: "msg1",
                            conversationId: "conv1",
                            conversationName: "Product Team",
                            messageText: "Let's go with November 15th for the launch. We need to finish mobile features first before desktop.",
                            senderName: "Sarah Chen",
                            timestamp: .init(date: Date().addingTimeInterval(-86400 * 6)),
                            relevanceScore: 0.95
                        ),
                        SourceMessage(
                            id: "msg2",
                            conversationId: "conv1",
                            conversationName: "Product Team",
                            messageText: "Agreed. Mobile is our priority. Desktop can wait until December.",
                            senderName: "Alex Johnson",
                            timestamp: .init(date: Date().addingTimeInterval(-86400 * 6)),
                            relevanceScore: 0.88
                        )
                    ]
                )
            ) { source in
                print("Tapped source: \(source.conversationName)")
            }
            
            // Loading message
            GlobalAIMessageBubbleView(
                message: ConversationMessage(
                    isUser: false,
                    text: "",
                    isLoading: true
                )
            )
            
            // AI message without sources
            GlobalAIMessageBubbleView(
                message: ConversationMessage(
                    isUser: false,
                    text: "I couldn't find information about that in your conversations. Try asking something else!"
                )
            )
        }
        .padding()
    }
}

