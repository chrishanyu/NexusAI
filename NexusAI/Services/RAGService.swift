//
//  RAGService.swift
//  NexusAI
//
//  Service for RAG-powered queries using GPT-4
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

/// Custom errors for RAG operations
enum RAGError: LocalizedError {
    case networkError(String)
    case cloudFunctionError(String)
    case invalidResponse
    case notAuthenticated
    case noResults
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Unable to connect. Check your internet. \(message)"
        case .cloudFunctionError(let message):
            return "Something went wrong: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "Please sign in to use this feature"
        case .noResults:
            return "I couldn't find relevant information about that."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
    
    /// User-friendly error message
    var userMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Check your internet."
        case .cloudFunctionError:
            return "Something went wrong. Please try again."
        case .invalidResponse:
            return "Something went wrong. Please try again."
        case .notAuthenticated:
            return "Please sign in to use this feature."
        case .noResults:
            return "I couldn't find relevant information about that in your conversations."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

/// Service for RAG-powered Q&A functionality
class RAGService {
    
    // MARK: - Properties
    
    private let functions: Functions
    private let timeout: TimeInterval = 60.0 // 60 second timeout
    
    // MARK: - Initialization
    
    init() {
        self.functions = Functions.functions()
        
        // Optional: Use emulator for local testing
        #if DEBUG
        // Uncomment to use local emulator
        // functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Perform RAG query - main entry point
    /// - Parameters:
    ///   - question: User's question
    ///   - conversationHistory: Previous Q&A pairs for follow-up support (optional)
    /// - Returns: RAG response with answer and sources
    func query(_ question: String, conversationHistory: [[String: String]]? = nil) async throws -> RAGResponse {
        guard let userId = getCurrentUserId() else {
            throw RAGError.notAuthenticated
        }
        
        // Validate input
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RAGError.cloudFunctionError("Question cannot be empty")
        }
        
        // Prepare parameters
        var parameters: [String: Any] = [
            "question": question,
            "userId": userId
        ]
        
        // Add conversation history if provided
        if let history = conversationHistory, !history.isEmpty {
            parameters["conversationHistory"] = history
        }
        
        do {
            // Call Cloud Function with timeout
            let callable = functions.httpsCallable("ragQuery")
            
            // Create timeout task
            let result = try await withTimeout(seconds: timeout) {
                try await callable.call(parameters)
            }
            
            // Process response
            return try processResponse(result)
        } catch let error as RAGError {
            throw error
        } catch {
            // Handle specific Firebase errors
            if let functionsError = error as NSError? {
                // Check for specific error codes
                if functionsError.domain == "FIRFunctionsErrorDomain" {
                    switch functionsError.code {
                    case 7: // PERMISSION_DENIED
                        throw RAGError.notAuthenticated
                    case 8: // RESOURCE_EXHAUSTED (rate limit)
                        throw RAGError.cloudFunctionError("Too many requests. Please wait a moment.")
                    case 13: // INTERNAL
                        throw RAGError.cloudFunctionError("Server error. Please try again.")
                    default:
                        throw RAGError.cloudFunctionError(functionsError.localizedDescription)
                    }
                }
            }
            throw RAGError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    /// Process Cloud Function response and convert to RAGResponse
    private func processResponse(_ result: HTTPSCallableResult) throws -> RAGResponse {
        guard let data = result.data as? [String: Any],
              let answer = data["answer"] as? String,
              let sourcesData = data["sources"] as? [[String: Any]],
              let queryTime = data["queryTime"] as? String else {
            throw RAGError.invalidResponse
        }
        
        // Parse sources
        let sources = sourcesData.compactMap { dict -> SourceMessage? in
            guard let messageId = dict["id"] as? String,
                  let conversationId = dict["conversationId"] as? String,
                  let conversationName = dict["conversationName"] as? String,
                  let messageText = dict["messageText"] as? String,
                  let senderName = dict["senderName"] as? String,
                  let timestamp = dict["timestamp"] as? Timestamp,
                  let relevanceScore = dict["relevanceScore"] as? Double else {
                return nil
            }
            
            return SourceMessage(
                id: messageId,
                conversationId: conversationId,
                conversationName: conversationName,
                messageText: messageText,
                senderName: senderName,
                timestamp: timestamp,
                relevanceScore: relevanceScore
            )
        }
        
        // Return response even if no results found
        // (Don't throw error - it's a valid response, just no sources)
        return RAGResponse(
            answer: answer,
            sources: sources,
            queryTime: queryTime
        )
    }
    
    /// Get current user ID from Firebase Auth
    private func getCurrentUserId() -> String? {
        return FirebaseService.shared.currentUserId
    }
    
    /// Execute async operation with timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add operation task
            group.addTask {
                return try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RAGError.timeout
            }
            
            // Return first result (either operation completes or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

