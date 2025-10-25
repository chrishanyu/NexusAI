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
    @StateObject private var viewModel: AIAssistantViewModel
    @State private var userInput: String = ""
    @State private var showClearConfirmation: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    // Conversation data for context
    let conversation: Conversation?
    let messages: [Message]
    
    // MARK: - Initialization
    
    init(
        isPresented: Binding<Bool>,
        conversationId: String,
        conversation: Conversation?,
        messages: [Message]
    ) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: AIAssistantViewModel(conversationId: conversationId))
        self.conversation = conversation
        self.messages = messages
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // AI Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Header with gradient
                            headerView
                            
                            // Welcome message (only show if no messages)
                            if !viewModel.hasMessages && !viewModel.isLoading {
                                welcomeMessageView
                            }
                            
                            // Suggested Prompts (only show if no messages)
                            if !viewModel.hasMessages && !viewModel.isLoading {
                                suggestedPromptsView
                            }
                            
                            // Messages
                            ForEach(viewModel.messages) { message in
                                AIMessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // Loading indicator
                            if viewModel.isLoading {
                                loadingView
                            }
                            
                            // Invisible anchor for scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onChange(of: viewModel.isLoading) { _, isLoading in
                        if !isLoading {
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                }
                
                Divider()
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }
                
                // Input area
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.hasMessages {
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Start fresh conversation")
                    }
                }
                
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
            .alert("Clear Chat History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await viewModel.clearChatHistory()
                    }
                }
            } message: {
                Text("Are you sure you want to clear all AI chat messages? This cannot be undone.")
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
    
    /// Welcome message
    private var welcomeMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("AI Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            Text("Hi! I'm your AI assistant. I can help you with this conversation. Ask me anything about the messages, participants, or get suggestions!")
                .font(.body)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    /// Suggested prompts section
    private var suggestedPromptsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Button(action: handleSummarizeThread) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 16))
                    Text("Summarize this thread")
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    /// Loading indicator
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Thinking...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    /// Error banner
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
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
                .disabled(viewModel.isLoading)
            
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
            .disabled(userInput.isEmpty || viewModel.isLoading)
            .opacity((userInput.isEmpty || viewModel.isLoading) ? 0.5 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Methods
    
    /// Handle sending a message
    private func handleSendMessage() {
        guard !userInput.isEmpty, !viewModel.isLoading else { return }
        
        let messageText = userInput
        userInput = ""
        
        Task {
            if let conversation = conversation {
                await viewModel.sendMessage(
                    text: messageText,
                    conversation: conversation,
                    messages: messages
                )
            } else {
                await viewModel.sendMessage(text: messageText)
            }
        }
    }
    
    /// Handle summarize thread button
    private func handleSummarizeThread() {
        userInput = "Summarize this thread"
        handleSendMessage()
    }
    
    /// Scroll to bottom of message list
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - AI Message Bubble

/// Message bubble for AI chat
struct AIMessageBubbleView: View {
    let message: LocalAIMessage
    
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

