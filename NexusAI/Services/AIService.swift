//
//  AIService.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import OpenAI

/// Service for managing OpenAI API interactions
/// Handles chat completions with GPT-4 for contextual conversation analysis
class AIService {
    
    // MARK: - Properties
    
    private let openAI: OpenAI
    private let model: Model = .gpt4
    
    // MARK: - Initialization
    
    init() {
        let apiKey = ConfigManager.shared.openAIAPIKey
        self.openAI = OpenAI(apiToken: apiKey)
        print("✅ AIService initialized with GPT-4")
    }
    
    /// Custom initializer for testing with a specific API key
    init(apiKey: String) {
        self.openAI = OpenAI(apiToken: apiKey)
        print("✅ AIService initialized (custom key)")
    }
    
    // MARK: - Public API
    
    /// Send a message to the AI with conversation context
    /// - Parameters:
    ///   - prompt: The user's prompt/question
    ///   - conversationContext: Formatted conversation context (messages and participants)
    /// - Returns: AI response text
    /// - Throws: AIServiceError if request fails
    func sendMessage(
        prompt: String,
        conversationContext: String
    ) async throws -> String {
        // Build the messages for the chat completion
        let messages = buildChatMessages(prompt: prompt, context: conversationContext)
        
        // Create the query
        let query = ChatQuery(
            messages: messages,
            model: model,
            temperature: 0.7
        )
        
        do {
            // Make the API call
            let result = try await openAI.chats(query: query)
            
            // Extract the response
            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw AIServiceError.noResponse
            }
            
            return content
            
        } catch let error as URLError {
            // Network errors
            throw AIServiceError.networkError(error.localizedDescription)
        } catch {
            // Other errors (API errors, parsing errors, etc.)
            throw AIServiceError.apiError(error.localizedDescription)
        }
    }
    
    /// Send a simple message without context (for general queries)
    /// - Parameter prompt: The user's prompt/question
    /// - Returns: AI response text
    /// - Throws: AIServiceError if request fails
    func sendSimpleMessage(prompt: String) async throws -> String {
        return try await sendMessage(prompt: prompt, conversationContext: "")
    }
    
    // MARK: - Context Building
    
    /// Build conversation context from messages and participants
    /// - Parameters:
    ///   - messages: Array of conversation messages
    ///   - participants: Dictionary of participant info
    /// - Returns: Formatted context string
    func buildConversationContext(
        messages: [Message],
        participants: [String: Conversation.ParticipantInfo]
    ) -> String {
        var context = "Participants:\n"
        
        // Add participant information
        for (userId, info) in participants {
            context += "- \(info.displayName) (ID: \(userId))\n"
        }
        
        context += "\nConversation:\n"
        
        // Add messages
        for message in messages {
            let senderName = message.senderName
            context += "[\(senderName)]: \(message.text)\n"
        }
        
        return context
    }
    
    /// Build conversation context from a Conversation object
    /// - Parameters:
    ///   - conversation: The conversation object
    ///   - messages: Array of messages in the conversation
    /// - Returns: Formatted context string
    func buildConversationContext(
        conversation: Conversation,
        messages: [Message]
    ) -> String {
        return buildConversationContext(
            messages: messages,
            participants: conversation.participants
        )
    }
    
    // MARK: - Private Helpers
    
    /// Build chat messages array for OpenAI API
    /// - Parameters:
    ///   - prompt: User's prompt
    ///   - context: Conversation context
    /// - Returns: Array of chat messages
    private func buildChatMessages(
        prompt: String,
        context: String
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        
        // System prompt
        let systemPrompt = """
        You are a helpful AI assistant analyzing a conversation thread. \
        You have access to the conversation history and participant information. \
        Provide clear, concise, and contextually relevant responses. \
        When summarizing, focus on key points, decisions, and action items.
        """
        
        if let systemMessage = ChatQuery.ChatCompletionMessageParam(
            role: .system,
            content: systemPrompt
        ) {
            messages.append(systemMessage)
        }
        
        // Add context if available
        if !context.isEmpty {
            let contextMessage: String
            if prompt.lowercased().contains("summarize") {
                contextMessage = """
                Here is the conversation to summarize:
                
                \(context)
                
                Please provide a concise summary.
                """
            } else {
                contextMessage = """
                Here is the conversation context:
                
                \(context)
                
                User question: \(prompt)
                """
            }
            
            if let userMessage = ChatQuery.ChatCompletionMessageParam(
                role: .user,
                content: contextMessage
            ) {
                messages.append(userMessage)
            }
        } else {
            // No context, just the prompt
            if let userMessage = ChatQuery.ChatCompletionMessageParam(
                role: .user,
                content: prompt
            ) {
                messages.append(userMessage)
            }
        }
        
        return messages
    }
}

// MARK: - AI Service Errors

/// Errors that can occur during AI service operations
enum AIServiceError: LocalizedError {
    case noResponse
    case networkError(String)
    case apiError(String)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response received from AI"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidConfiguration:
            return "AI service configuration is invalid"
        }
    }
    
    /// User-friendly error message
    var userMessage: String {
        switch self {
        case .noResponse:
            return "I couldn't generate a response. Please try again."
        case .networkError:
            return "No internet connection. Please check your network and try again."
        case .apiError:
            return "Something went wrong. Please try again later."
        case .invalidConfiguration:
            return "AI service is not configured properly."
        }
    }
}

