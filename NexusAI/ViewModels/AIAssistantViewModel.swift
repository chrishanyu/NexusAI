//
//  AIAssistantViewModel.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import Combine

/// ViewModel for managing AI Assistant interactions
@MainActor
class AIAssistantViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All AI messages in this conversation
    @Published var messages: [LocalAIMessage] = []
    
    /// Loading state while waiting for AI response
    @Published var isLoading = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Whether the chat history has been loaded
    @Published var isHistoryLoaded = false
    
    // MARK: - Private Properties
    
    /// Conversation ID this AI chat is associated with
    private let conversationId: String
    
    /// AI message repository
    private let repository: AIMessageRepository
    
    /// AI service for OpenAI integration
    private let aiService: AIService
    
    /// Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    /// Observation task for real-time message updates
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        conversationId: String,
        repository: AIMessageRepository? = nil,
        aiService: AIService? = nil
    ) {
        self.conversationId = conversationId
        self.repository = repository ?? RepositoryFactory.shared.aiMessageRepository
        self.aiService = aiService ?? AIService()
        
        // Start observing messages
        startObservingMessages()
    }
    
    deinit {
        observationTask?.cancel()
    }
    
    // MARK: - Message Observation
    
    /// Start observing AI messages in real-time
    private func startObservingMessages() {
        observationTask = Task { @MainActor in
            let stream = repository.observeMessages(conversationId: conversationId)
            
            for await messages in stream {
                self.messages = messages
                self.isHistoryLoaded = true
            }
        }
    }
    
    // MARK: - Load Chat History
    
    /// Load chat history for this conversation
    func loadChatHistory() async {
        do {
            messages = try await repository.fetchMessages(for: conversationId)
            isHistoryLoaded = true
        } catch {
            print("❌ Failed to load AI chat history: \(error)")
            errorMessage = "Failed to load chat history"
        }
    }
    
    // MARK: - Send Message
    
    /// Send a message to the AI assistant
    /// - Parameters:
    ///   - text: The user's message text
    ///   - conversationContext: Optional conversation context (messages and participants)
    func sendMessage(
        text: String,
        conversationContext: String? = nil
    ) async {
        guard !text.isEmpty else { return }
        
        // Clear any existing error
        errorMessage = nil
        isLoading = true
        
        do {
            // Save user's message
            try await repository.saveMessage(
                text: text,
                isFromAI: false,
                conversationId: conversationId
            )
            
            // Get AI response
            let context = conversationContext ?? ""
            let aiResponse = try await aiService.sendMessage(
                prompt: text,
                conversationContext: context
            )
            
            // Save AI's response
            try await repository.saveMessage(
                text: aiResponse,
                isFromAI: true,
                conversationId: conversationId
            )
            
        } catch let error as AIServiceError {
            // Handle AI service errors with user-friendly messages
            errorMessage = error.userMessage
            print("❌ AI Service error: \(error.localizedDescription)")
        } catch {
            // Handle repository or other errors
            errorMessage = "Failed to send message. Please try again."
            print("❌ Failed to send AI message: \(error)")
        }
        
        isLoading = false
    }
    
    /// Send a message with conversation context built from Message and Conversation objects
    /// - Parameters:
    ///   - text: The user's message text
    ///   - conversation: The conversation object
    ///   - messages: Array of conversation messages
    func sendMessage(
        text: String,
        conversation: Conversation,
        messages: [Message]
    ) async {
        let context = aiService.buildConversationContext(
            conversation: conversation,
            messages: messages
        )
        
        await sendMessage(text: text, conversationContext: context)
    }
    
    // MARK: - Clear Chat History
    
    /// Clear all AI messages for this conversation
    func clearChatHistory() async {
        do {
            try await repository.clearMessages(for: conversationId)
            messages = []
            errorMessage = nil
        } catch {
            print("❌ Failed to clear AI chat history: \(error)")
            errorMessage = "Failed to clear chat history"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if the conversation has any AI messages
    var hasMessages: Bool {
        !messages.isEmpty
    }
    
    /// Get the count of messages
    var messageCount: Int {
        messages.count
    }
    
    /// Dismiss the current error message
    func dismissError() {
        errorMessage = nil
    }
}

