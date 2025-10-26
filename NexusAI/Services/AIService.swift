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
    
    /// Unified system prompt for all AI interactions
    /// This prompt stays constant and defines the AI's capabilities and behavior
    private let unifiedSystemPrompt = """
    You are an intelligent assistant integrated into a team messaging app called NexusAI. Your role is to help remote teams work more effectively by analyzing their conversations and providing actionable insights.
    
    CORE CAPABILITIES:
    1. **Summarization**: Provide concise summaries of conversation threads, highlighting key points and takeaways
    2. **Action Item Extraction**: Identify tasks, commitments, and responsibilities with clear assignments
    3. **Decision Tracking**: Recognize when decisions are made, who agreed, and the reasoning behind them
    4. **Priority Analysis**: Determine urgency based on keywords, deadlines, context, and impact
    5. **Deadline Detection**: Extract all time commitments, due dates, and deadlines mentioned
    6. **Natural Q&A**: Answer questions about the conversation context accurately and helpfully
    
    CONVERSATION CONTEXT PROVIDED:
    - Full message history with participant names
    - Participant information and roles
    - Conversation metadata and timestamps
    
    RESPONSE GUIDELINES:
    - Be concise but thorough - remote teams value clarity over verbosity
    - Use clear formatting: bullet points, numbering, and structure for scanability
    - Reference specific messages or participants when relevant
    - If information isn't in the conversation, state that clearly - don't guess
    - For action items: Always identify WHO, WHAT, WHEN (if mentioned), and WHICH MESSAGE
    - For decisions: Note consensus level (unanimous/majority/split) and reasoning
    - For priorities: Explain WHY something is urgent using specific indicators
    - For deadlines: Always include who is responsible and what is due
    
    FORMATTING STANDARDS:
    - Use emojis for visual clarity and quick scanning:
      📋 for action items/tasks
      ✅ for decisions/agreements
      🔴 for urgent/high priority
      ⚠️ for medium priority
      🟢 for low priority
      📅 for deadlines/dates
      👤 for people/assignments
    - Use **bold** for emphasis on key information
    - Keep lists organized, numbered, and scannable
    - Include timestamps when referencing specific messages
    - Use "---" to separate different sections in longer responses
    
    PERSONA:
    You are a professional team assistant - helpful and proactive, but never pushy. You understand the challenges of remote work: timezone differences, context switching, and information overload. Your goal is to save time and reduce friction.
    
    IMPORTANT:
    - Maintain context from previous messages in the conversation
    - You can answer follow-up questions that reference earlier responses
    - If asked to filter or refine a previous response, do so intelligently
    - Support multi-turn conversations naturally
    """
    
    /// Build chat messages array for OpenAI API
    /// - Parameters:
    ///   - prompt: User's prompt/question
    ///   - context: Conversation context
    /// - Returns: Array of chat messages
    private func buildChatMessages(
        prompt: String,
        context: String
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = []
        
        // 1. Add unified system prompt (always first, always the same)
        if let systemMessage = ChatQuery.ChatCompletionMessageParam(
            role: .system,
            content: unifiedSystemPrompt
        ) {
            messages.append(systemMessage)
        }
        
        // 2. Build user message with context (if available)
        let userMessage: String
        if !context.isEmpty {
            userMessage = """
            CONVERSATION CONTEXT:
            \(context)
            
            ---
            USER REQUEST: \(prompt)
            """
        } else {
            // No context - just the user's question
            userMessage = prompt
        }
        
        if let userMsg = ChatQuery.ChatCompletionMessageParam(
            role: .user,
            content: userMessage
        ) {
            messages.append(userMsg)
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

