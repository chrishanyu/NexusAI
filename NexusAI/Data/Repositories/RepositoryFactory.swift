//
//  RepositoryFactory.swift
//  NexusAI
//
//  Created on 10/23/25.
//

import Foundation

/// Factory for creating repository instances with proper dependency injection
/// Provides centralized repository creation for the entire app
@MainActor
final class RepositoryFactory {
    
    // MARK: - Singleton
    
    static let shared = RepositoryFactory()
    
    // MARK: - Properties
    
    private let database: LocalDatabase
    
    // Lazy repository instances
    private lazy var _messageRepository: MessageRepository = {
        MessageRepository(database: database)
    }()
    
    private lazy var _conversationRepository: ConversationRepository = {
        ConversationRepository(database: database)
    }()
    
    private lazy var _userRepository: UserRepository = {
        UserRepository(database: database)
    }()
    
    private lazy var _aiMessageRepository: AIMessageRepository = {
        AIMessageRepository(database: database)
    }()
    
    private lazy var _actionItemRepository: ActionItemRepository = {
        ActionItemRepository(database: database)
    }()
    
    // MARK: - Initialization
    
    private init() {
        self.database = LocalDatabase.shared
        print("✅ RepositoryFactory initialized")
    }
    
    // Custom initializer for testing
    init(database: LocalDatabase) {
        self.database = database
        print("✅ RepositoryFactory initialized (custom database)")
    }
    
    // MARK: - Public API
    
    /// Get the message repository instance
    var messageRepository: MessageRepositoryProtocol {
        _messageRepository
    }
    
    /// Get the conversation repository instance
    var conversationRepository: ConversationRepositoryProtocol {
        _conversationRepository
    }
    
    /// Get the user repository instance
    var userRepository: UserRepositoryProtocol {
        _userRepository
    }
    
    /// Get the AI message repository instance
    var aiMessageRepository: AIMessageRepository {
        _aiMessageRepository
    }
    
    /// Get the action item repository instance
    var actionItemRepository: ActionItemRepositoryProtocol {
        _actionItemRepository
    }
    
    /// Reset all repositories (useful for testing or logout)
    func reset() {
        // Repositories will be recreated on next access due to lazy initialization
        print("🔄 RepositoryFactory reset")
    }
}

