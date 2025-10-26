//
//  AIService.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation
import OpenAI

// MARK: - Action Item JSON Structure

/// JSON structure for action items returned by AI
struct ActionItemJSON: Codable {
    let task: String
    let assignee: String?
    let messageId: String
    let deadline: String?  // ISO 8601 date string or null
    let priority: String   // "high", "medium", or "low"
}

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
    
    // MARK: - Action Item Extraction
    
    /// Extract action items from conversation messages with structured JSON output
    /// - Parameters:
    ///   - messages: Array of conversation messages to analyze
    ///   - participants: Dictionary of participant information
    ///   - conversationId: The conversation ID
    /// - Returns: Array of extracted ActionItem objects
    /// - Throws: ActionItemError if extraction or parsing fails
    func extractActionItems(
        from messages: [Message],
        participants: [String: Conversation.ParticipantInfo],
        conversationId: String
    ) async throws -> [ActionItem] {
        // Build context with participant names
        let participantNames = participants.values.map { $0.displayName }.joined(separator: ", ")
        
        // Format messages for AI
        var messageContext = ""
        for message in messages {
            messageContext += "[\(message.senderName) at \(formatTimestamp(message.timestamp))]: \(message.text)\n"
        }
        
        // Build extraction prompt
        let prompt = buildExtractionPrompt(
            participantNames: participantNames,
            messageContext: messageContext
        )
        
        // Create the query with JSON mode
        let messages = [
            ChatQuery.ChatCompletionMessageParam(role: .system, content: prompt)!,
            ChatQuery.ChatCompletionMessageParam(role: .user, content: messageContext)!
        ]
        
        let query = ChatQuery(
            messages: messages,
            model: model,
            temperature: 0.3  // Lower temperature for more consistent JSON output
        )
        
        do {
            // Make the API call
            let result = try await openAI.chats(query: query)
            
            // Extract the response
            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw ActionItemError.noResponse
            }
            
            // Parse JSON response
            let actionItems = try parseActionItems(from: content, conversationId: conversationId)
            
            print("✅ Extracted \(actionItems.count) action item(s)")
            return actionItems
            
        } catch let error as ActionItemError {
            throw error
        } catch let error as URLError {
            throw ActionItemError.networkError(error.localizedDescription)
        } catch {
            throw ActionItemError.extractionFailed(error.localizedDescription)
        }
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
    
    // MARK: - Private Helpers (Action Items)
    
    /// Build the extraction prompt for action items
    /// - Parameters:
    ///   - participantNames: Comma-separated list of participant names
    ///   - messageContext: Formatted conversation messages
    /// - Returns: System prompt for extraction
    private func buildExtractionPrompt(participantNames: String, messageContext: String) -> String {
        return """
        You are analyzing a team conversation to extract action items.
        
        PARTICIPANTS: \(participantNames)
        
        INSTRUCTIONS:
        Extract all action items from this conversation. Return ONLY valid JSON array (no markdown, no explanatory text):
        
        [
          {
            "task": "string - clear description",
            "assignee": "string - exact participant name or null",
            "messageId": "string - message ID where mentioned",
            "deadline": "string - ISO8601 date or null",
            "priority": "high" | "medium" | "low"
          }
        ]
        
        RULES:
        1. Only clear, actionable tasks (not questions or discussions)
        2. Match assignee to participant names exactly
        3. Infer deadline from context: "by Friday" = next Friday 5pm ISO format
        4. Priority: high=urgent/today/ASAP, medium=normal/this week, low=future/optional
        5. Empty array [] if no action items
        6. Return ONLY the JSON array, nothing else
        
        IDENTIFY ACTION ITEMS BASED ON:
        - Direct assignments: "Bob, can you update the docs?"
        - Commitments: "I'll handle the testing"
        - Questions implying tasks: "Who can review the PR?"
        - Deadlines: "by Friday", "end of week", "tomorrow"
        - Urgency indicators: "urgent", "ASAP", "critical"
        """
    }
    
    /// Parse JSON response into ActionItem objects
    /// - Parameters:
    ///   - jsonString: Raw JSON string from AI
    ///   - conversationId: The conversation ID
    /// - Returns: Array of ActionItem objects
    /// - Throws: ActionItemError if parsing fails
    private func parseActionItems(from jsonString: String, conversationId: String) throws -> [ActionItem] {
        // 1. Strip markdown code blocks if AI includes them
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```\n", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Handle empty response
        if cleanedJSON.isEmpty || cleanedJSON == "[]" {
            return []
        }
        
        // 3. Convert to data
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw ActionItemError.invalidJSON("Could not convert response to data")
        }
        
        // 4. Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let jsonItems = try decoder.decode([ActionItemJSON].self, from: data)
            
            // 5. Convert to ActionItem objects
            let actionItems = jsonItems.compactMap { jsonItem -> ActionItem? in
                // Parse priority
                let priority = Priority(rawValue: jsonItem.priority.lowercased()) ?? .medium
                
                // Parse deadline
                var deadline: Date? = nil
                if let deadlineString = jsonItem.deadline {
                    let isoFormatter = ISO8601DateFormatter()
                    deadline = isoFormatter.date(from: deadlineString)
                }
                
                // Create action item
                return ActionItem(
                    conversationId: conversationId,
                    task: jsonItem.task,
                    assignee: jsonItem.assignee,
                    messageId: jsonItem.messageId,
                    extractedAt: Date(),
                    isComplete: false,
                    deadline: deadline,
                    priority: priority
                )
            }
            
            return actionItems
            
        } catch {
            throw ActionItemError.parsingFailed("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    /// Format timestamp for message context
    /// - Parameter date: The date to format
    /// - Returns: Formatted time string (e.g., "2:30 PM")
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Private Helpers (General)
    
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

// MARK: - Action Item Errors

/// Errors that can occur during action item extraction
enum ActionItemError: LocalizedError {
    case noResponse
    case networkError(String)
    case extractionFailed(String)
    case invalidJSON(String)
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response received from AI"
        case .networkError(let message):
            return "Network error: \(message)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        }
    }
    
    /// User-friendly error message
    var userMessage: String {
        switch self {
        case .noResponse:
            return "Couldn't extract action items. Please try again."
        case .networkError:
            return "No internet connection. Check your network and try again."
        case .extractionFailed:
            return "Something went wrong. Please try again later."
        case .invalidJSON, .parsingFailed:
            return "Couldn't understand the response. Try again or contact support."
        }
    }
}

