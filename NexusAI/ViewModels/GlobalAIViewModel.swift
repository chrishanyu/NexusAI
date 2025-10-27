//
//  GlobalAIViewModel.swift
//  NexusAI
//
//  ViewModel for Global AI Assistant feature
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing Global AI Assistant state and interactions
@MainActor
class GlobalAIViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of conversation messages (user queries and AI responses)
    @Published var messages: [ConversationMessage] = []
    
    /// Loading state while waiting for AI response
    @Published var isLoading: Bool = false
    
    /// Error message to display (if any)
    @Published var errorMessage: String?
    
    /// Typing indicator for AI response animation
    @Published var isTyping: Bool = false
    
    // MARK: - Dependencies
    
    private let ragService: RAGService
    
    // MARK: - Computed Properties
    
    /// Check if there are any messages in the conversation
    var hasMessages: Bool {
        return !messages.isEmpty
    }
    
    /// Count of user messages
    var userMessageCount: Int {
        return messages.filter { $0.isUser }.count
    }
    
    /// Count of AI messages
    var aiMessageCount: Int {
        return messages.filter { !$0.isUser && !$0.isLoading }.count
    }
    
    // MARK: - Initialization
    
    init(ragService: RAGService? = nil) {
        self.ragService = ragService ?? RAGService()
    }
    
    // MARK: - Public Methods
    
    /// Send a user query to the AI Assistant
    /// - Parameter question: User's question
    func sendQuery(_ question: String) {
        // Validate input
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            return
        }
        
        // Clear any previous error
        errorMessage = nil
        
        // Add user message immediately (optimistic UI)
        let userMessage = ConversationMessage.userMessage(trimmedQuestion)
        messages.append(userMessage)
        
        // Add loading message
        let loadingMessage = ConversationMessage.loadingMessage()
        messages.append(loadingMessage)
        
        // Set loading state
        isLoading = true
        isTyping = true
        
        // Call RAG service
        Task {
            do {
                // Build conversation history for follow-up support
                let history = buildConversationHistory()
                
                // Query the RAG service with history
                let response = try await ragService.query(trimmedQuestion, conversationHistory: history)
                
                // Remove loading message
                if let loadingIndex = messages.firstIndex(where: { $0.isLoading }) {
                    messages.remove(at: loadingIndex)
                }
                
                // Add AI response with sources
                let aiMessage = ConversationMessage.aiMessage(response.answer, sources: response.sources)
                messages.append(aiMessage)
                
                // Update state
                isLoading = false
                isTyping = false
                
            } catch let error as RAGError {
                // Handle RAG-specific errors
                handleError(error)
            } catch {
                // Handle generic errors
                handleError(RAGError.networkError(error.localizedDescription))
            }
        }
    }
    
    /// Clear conversation history
    func clearHistory() {
        messages.removeAll()
        errorMessage = nil
        isLoading = false
        isTyping = false
    }
    
    /// Retry the last failed query
    func retryLastQuery() {
        // Find the last user message
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else {
            return
        }
        
        // Remove error message if present
        if let errorIndex = messages.lastIndex(where: { !$0.isUser && $0.text.hasPrefix("❌") }) {
            messages.remove(at: errorIndex)
        }
        
        // Retry with the same question
        sendQuery(lastUserMessage.text)
    }
    
    /// Handle navigation to source message
    /// - Parameter source: Source message to navigate to
    func navigateToMessage(_ source: SourceMessage) {
        // Post notifications for navigation
        // 1. Switch to Chat tab
        NotificationCenter.default.post(name: .switchToChatTab, object: nil)
        
        // 2. Navigate to specific message (with slight delay to allow tab switch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .jumpToMessage,
                object: source
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// Build conversation history from messages for GPT-4 context
    /// - Returns: Array of message dictionaries with role and content
    private func buildConversationHistory() -> [[String: String]] {
        var history: [[String: String]] = []
        
        // Convert UI messages to API format (excluding loading messages)
        for message in messages where !message.isLoading {
            if message.isUser {
                history.append([
                    "role": "user",
                    "content": message.text
                ])
            } else {
                history.append([
                    "role": "assistant",
                    "content": message.text
                ])
            }
        }
        
        // Limit to last 10 messages (5 Q&A pairs) to avoid token limits
        // This ensures follow-up questions have context without overwhelming the API
        return Array(history.suffix(10))
    }
    
    /// Handle errors and update UI accordingly
    private func handleError(_ error: RAGError) {
        // Remove loading message if present
        if let loadingIndex = messages.firstIndex(where: { $0.isLoading }) {
            messages.remove(at: loadingIndex)
        }
        
        // Add error message to conversation
        let errorText = error.userMessage
        let errorMessage = ConversationMessage.errorMessage(errorText)
        messages.append(errorMessage)
        
        // Set error state
        self.errorMessage = errorText
        isLoading = false
        isTyping = false
        
        // Log error for debugging
        print("❌ GlobalAIViewModel error: \(error.localizedDescription)")
    }
}

