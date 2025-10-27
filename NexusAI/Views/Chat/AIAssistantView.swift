//
//  AIAssistantView.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import SwiftUI

// MARK: - Suggested Prompt Model

/// Represents a suggested prompt that users can quickly select
struct SuggestedPrompt: Identifiable {
    let id = UUID()
    let title: String          // Display title
    let icon: String           // SF Symbol name
    let userMessage: String    // What gets sent as user message
    let description: String?   // Optional help text
    
    init(title: String, icon: String, userMessage: String, description: String? = nil) {
        self.title = title
        self.icon = icon
        self.userMessage = userMessage
        self.description = description
    }
}

// MARK: - AI Assistant View

/// AI Assistant panel for contextual help with the conversation
struct AIAssistantView: View {
    // MARK: - Properties
    
    @Binding var isPresented: Bool
    @StateObject private var viewModel: AIAssistantViewModel
    @State private var userInput: String = ""
    @State private var showClearConfirmation: Bool = false
    @State private var scrollPosition: String? // For iOS 26+ scroll control
    @State private var isInitialLoad = true // Prevent scroll on initial message load
    
    // Conversation data for context
    let conversation: Conversation?
    let messages: [Message]
    
    // MARK: - Suggested Prompts for Remote Team Professionals
    
    /// Suggested prompts tailored for Remote Team Professional persona
    private let suggestedPrompts: [SuggestedPrompt] = [
        SuggestedPrompt(
            title: "Summarize thread",
            icon: "doc.text.fill",
            userMessage: "Please provide a concise summary of this conversation, highlighting key points and takeaways.",
            description: "Get a quick overview"
        ),
        SuggestedPrompt(
            title: "Extract action items",
            icon: "checklist",
            userMessage: """
Extract all action items, tasks, and commitments from this conversation.
For each item, identify:
- What needs to be done
- Who is responsible
- Any mentioned deadlines
- Which message it came from
""",
            description: "Never miss a task"
        ),
        SuggestedPrompt(
            title: "Show decisions made",
            icon: "checkmark.circle.fill",
            userMessage: """
Identify all decisions that were made in this conversation.
For each decision, show:
- What was decided
- Who participated
- Level of consensus (unanimous, majority, etc.)
- The reasoning behind it
""",
            description: "Track what was agreed"
        ),
        SuggestedPrompt(
            title: "Flag urgent items",
            icon: "exclamationmark.triangle.fill",
            userMessage: """
Analyze this conversation and flag any urgent or high-priority items.
Categorize messages by urgency level and explain why each is urgent.
Look for keywords like 'urgent', 'ASAP', 'critical', deadlines, and production issues.
""",
            description: "See what needs attention"
        ),
        SuggestedPrompt(
            title: "Find all deadlines",
            icon: "calendar.badge.clock",
            userMessage: "List all deadlines, due dates, and time commitments mentioned in this conversation, sorted chronologically. Include who is responsible for each.",
            description: "Stay on schedule"
        )
    ]
    
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
                            
                            // Invisible anchor for auto-scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .scrollTargetLayout() // iOS 26: Enable precise scroll positioning
                        .padding()
                    }
                    .scrollPosition(id: $scrollPosition, anchor: .bottom) // iOS 26: Modern scroll control
                    .onAppear {
                        // Scroll to bottom on initial load
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        // Skip initial load to prevent unwanted scroll animation
                        if isInitialLoad {
                            isInitialLoad = false
                            scrollToBottom(proxy: proxy, animated: false)
                            return
                        }
                        
                        // Auto-scroll on new messages (user message or AI response)
                        if newCount > oldCount {
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                    .onChange(of: viewModel.isLoading) { oldValue, newValue in
                        // Scroll when AI starts thinking or completes
                        if !oldValue && newValue {
                            // AI started thinking - scroll to show loading indicator
                            scrollToBottom(proxy: proxy, animated: true)
                        } else if oldValue && !newValue {
                            // AI finished responding - scroll to show the response
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
            Text("Quick Actions")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            // Loop through all suggested prompts
            ForEach(suggestedPrompts) { prompt in
                Button {
                    handleSuggestedPrompt(prompt)
                } label: {
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: prompt.icon)
                            .font(.system(size: 18))
                            .frame(width: 24)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Title and description
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if let description = prompt.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Arrow
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.08), Color.blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
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
    
    /// Handle suggested prompt button
    /// - Parameter prompt: The suggested prompt that was tapped
    private func handleSuggestedPrompt(_ prompt: SuggestedPrompt) {
        // Set the user input to the prompt's message
        userInput = prompt.userMessage
        // Send it as a user message
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
                
                // Message text with native Markdown support
                Text(LocalizedStringKey(message.text))  // 👈 Enables automatic Markdown parsing
                    .font(.body)
                    .textSelection(.enabled)  // Allow text selection/copying
                    .tint(.purple)  // Links will be purple to match AI theme
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

