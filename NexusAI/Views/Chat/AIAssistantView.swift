//
//  AIAssistantView.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import SwiftUI

/// AI Assistant panel for contextual help with the conversation
struct AIAssistantView: View {
    // MARK: - Properties
    
    @Binding var isPresented: Bool
    @State private var userInput: String = ""
    @State private var messages: [AIMessage] = [
        AIMessage(text: "Hi! I'm your AI assistant. I can help you with this conversation. Ask me anything about the messages, participants, or get suggestions!", isFromAI: true),
        AIMessage(text: "What's this conversation about?", isFromAI: false),
        AIMessage(text: "Based on the conversation, it appears you're discussing project updates and deadlines. Would you like me to summarize the key points or help you draft a response?", isFromAI: true)
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // AI Chat Messages
                ScrollView {
                    VStack(spacing: 16) {
                        // Header with gradient
                        headerView
                        
                        // Messages
                        ForEach(messages) { message in
                            AIMessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Input area
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Header with AI branding
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("AI Assistant")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ask me anything about this conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }
    
    /// Input bar with text field and send button
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask me anything...", text: $userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...4)
            
            Button(action: handleSendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .disabled(userInput.isEmpty)
            .opacity(userInput.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Methods
    
    /// Handle sending a message
    private func handleSendMessage() {
        guard !userInput.isEmpty else { return }
        
        let newMessage = AIMessage(text: userInput, isFromAI: false)
        messages.append(newMessage)
        userInput = ""
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = AIMessage(
                text: "I'm analyzing the conversation... (This is a mockup - AI functionality will be implemented soon!)",
                isFromAI: true
            )
            messages.append(aiResponse)
        }
    }
}

// MARK: - AI Message Models

/// Model for AI chat messages
struct AIMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromAI: Bool
}

// MARK: - AI Message Bubble

/// Message bubble for AI chat
struct AIMessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if !message.isFromAI {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromAI ? .leading : .trailing, spacing: 4) {
                // Sender label
                HStack(spacing: 6) {
                    if message.isFromAI {
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
                    
                    Text(message.isFromAI ? "AI Assistant" : "You")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // Message text
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isFromAI
                            ? LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                message.isFromAI
                                    ? LinearGradient(
                                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1
                            )
                    )
            }
            
            if message.isFromAI {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Preview

#Preview("AI Assistant") {
    AIAssistantView(isPresented: .constant(true))
}

