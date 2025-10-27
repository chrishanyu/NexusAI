//
//  GlobalAIAssistantView.swift
//  NexusAI
//
//  Main view for Nexus (Global AI Assistant) tab
//  Adapted from existing AIAssistantView.swift
//

import SwiftUI

// MARK: - Suggested Prompt Model

/// Represents a suggested prompt for cross-conversation queries
struct GlobalAISuggestedPrompt: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let userMessage: String
    let description: String?
    
    init(title: String, icon: String, userMessage: String, description: String? = nil) {
        self.title = title
        self.icon = icon
        self.userMessage = userMessage
        self.description = description
    }
}

// MARK: - Nexus View

/// Main view for the Nexus (Global AI Assistant) tab
struct GlobalAIAssistantView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: GlobalAIViewModel
    @State private var userInput: String = ""
    @State private var showClearConfirmation: Bool = false
    @State private var scrollPosition: String? // For scroll control
    @State private var isInitialLoad = true // Prevent scroll on initial load
    
    // MARK: - Suggested Prompts for Cross-Conversation Queries
    
    /// Suggested prompts tailored for cross-conversation search
    private let suggestedPrompts: [GlobalAISuggestedPrompt] = [
        GlobalAISuggestedPrompt(
            title: "Show decisions made",
            icon: "checkmark.circle.fill",
            userMessage: "What decisions were made this week across all my conversations?",
            description: "Track what was agreed"
        ),
        GlobalAISuggestedPrompt(
            title: "Find urgent items",
            icon: "exclamationmark.triangle.fill",
            userMessage: "What needs immediate attention? Show me urgent or high-priority items across all conversations.",
            description: "See what needs attention"
        ),
        GlobalAISuggestedPrompt(
            title: "Show my tasks",
            icon: "checklist",
            userMessage: "What are all my action items and tasks across conversations?",
            description: "Never miss a task"
        ),
        GlobalAISuggestedPrompt(
            title: "Find deadlines",
            icon: "calendar.badge.clock",
            userMessage: "Show me all upcoming deadlines and due dates mentioned in my conversations.",
            description: "Stay on schedule"
        ),
        GlobalAISuggestedPrompt(
            title: "Summarize discussions",
            icon: "doc.text.fill",
            userMessage: "Summarize the main topics and discussions from this week across all my conversations.",
            description: "Get a quick overview"
        )
    ]
    
    // MARK: - Initialization
    
    init() {
        _viewModel = StateObject(wrappedValue: GlobalAIViewModel())
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // AI Chat Messages
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
                            GlobalAIMessageBubbleView(
                                message: message,
                                onSourceTap: { source in
                                    viewModel.navigateToMessage(source)
                                }
                            )
                            .id(message.id.uuidString)
                        }
                        
                        // Invisible anchor for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .scrollTargetLayout() // Enable precise scroll positioning
                    .padding()
                }
                .scrollPosition(id: $scrollPosition, anchor: .bottom)
                .onAppear {
                    // Scroll to bottom on initial load to show input bar and prompts
                    if !viewModel.hasMessages {
                        scrollPosition = "bottom"
                    }
                }
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    // Skip initial load to prevent unwanted scroll animation
                    if isInitialLoad {
                        isInitialLoad = false
                        // Set scroll position without animation
                        if let lastMessage = viewModel.messages.last {
                            scrollPosition = lastMessage.id.uuidString
                        }
                        return
                    }
                    
                    // Auto-scroll on new messages
                    if newCount > oldCount {
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                scrollPosition = lastMessage.id.uuidString
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { oldValue, newValue in
                    // Scroll when loading completes and AI response arrives
                    if oldValue && !newValue {
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                scrollPosition = lastMessage.id.uuidString
                            }
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
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Nexus")
                            .font(.headline)
                        Text(statusText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.hasMessages {
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Clear conversation history")
                    }
                }
            }
            .alert("Clear Chat History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearHistory()
                }
            } message: {
                Text("Are you sure you want to clear all AI chat messages? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Status text shown below title
    private var statusText: String {
        if viewModel.isLoading {
            return "Searching..."
        } else if viewModel.hasMessages {
            return "Ready"
        } else {
            return "Ask me anything"
        }
    }
    
    // MARK: - Subviews
    
    /// Header with Nexus branding
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
            
            Text("Nexus")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Search across all your conversations")
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
                
                Text("Nexus")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            Text("Hi! I can search across all your conversations to find decisions, track tasks, and answer questions. Ask me anything!")
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
                viewModel.errorMessage = nil
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
            TextField("Ask me anything about your conversations...", text: $userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...4)
                .disabled(viewModel.isLoading)
                .onSubmit {
                    handleSendMessage()
                }
            
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
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        viewModel.sendQuery(messageText)
    }
    
    /// Handle suggested prompt button
    /// - Parameter prompt: The suggested prompt that was tapped
    private func handleSuggestedPrompt(_ prompt: GlobalAISuggestedPrompt) {
        // Set the user input to the prompt's message
        userInput = prompt.userMessage
        // Send it as a user message
        handleSendMessage()
    }
}

// MARK: - Preview Provider

#Preview {
    GlobalAIAssistantView()
}

