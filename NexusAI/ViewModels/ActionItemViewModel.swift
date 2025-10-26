//
//  ActionItemViewModel.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import Foundation
import Combine

/// ViewModel for managing action items in a conversation
@MainActor
class ActionItemViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All action items for this conversation
    @Published var items: [ActionItem] = []
    
    /// Loading state during extraction
    @Published var isLoading = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Show success toast
    @Published var showSuccessToast = false
    
    /// Success message text
    @Published var successMessage: String?
    
    // MARK: - Computed Properties
    
    /// Incomplete action items
    var incompleteItems: [ActionItem] {
        items.filter { !$0.isComplete }
    }
    
    /// Completed action items
    var completedItems: [ActionItem] {
        items.filter { $0.isComplete }
    }
    
    /// Count of incomplete items
    var incompleteCount: Int {
        incompleteItems.count
    }
    
    // MARK: - Private Properties
    
    private let conversationId: String
    private let repository: ActionItemRepositoryProtocol
    private let aiService: AIService
    
    // Data passed from parent view for extraction
    private var messages: [Message] = []
    private var conversation: Conversation?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        conversationId: String,
        repository: ActionItemRepositoryProtocol? = nil,
        aiService: AIService? = nil
    ) {
        self.conversationId = conversationId
        self.repository = repository ?? RepositoryFactory.shared.actionItemRepository
        self.aiService = aiService ?? AIService()
        
        // Load existing items
        Task {
            await loadItems()
        }
        
        // Observe real-time updates
        observeItems()
    }
    
    // MARK: - Public Methods
    
    /// Set messages and conversation data for extraction
    /// - Parameters:
    ///   - messages: Conversation messages
    ///   - conversation: Conversation object with participants
    func setConversationData(messages: [Message], conversation: Conversation?) {
        self.messages = messages
        self.conversation = conversation
    }
    
    /// Load action items from repository
    func loadItems() async {
        do {
            items = try await repository.fetch(for: conversationId)
        } catch {
            print("❌ Failed to load action items: \(error.localizedDescription)")
            errorMessage = "Failed to load action items."
        }
    }
    
    /// Extract action items from conversation using AI
    func extractItems() async {
        guard let conversation = conversation else {
            errorMessage = "Conversation data not available."
            return
        }
        
        guard !messages.isEmpty else {
            errorMessage = "No messages to analyze."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Call AI service to extract action items
            let extractedItems = try await aiService.extractActionItems(
                from: messages,
                participants: conversation.participants,
                conversationId: conversationId
            )
            
            // Save to repository
            if !extractedItems.isEmpty {
                try await repository.save(extractedItems)
                
                // Reload to get sorted items
                await loadItems()
                
                // Show success message
                successMessage = "✅ Saved \(extractedItems.count) action item\(extractedItems.count == 1 ? "" : "s")"
                showSuccessToast = true
            } else {
                // No items found
                successMessage = "No action items found in this conversation."
                showSuccessToast = true
            }
            
            isLoading = false
            
        } catch let error as ActionItemError {
            isLoading = false
            errorMessage = error.userMessage
            print("❌ Extraction error: \(error.localizedDescription)")
        } catch {
            isLoading = false
            errorMessage = "Something went wrong. Please try again."
            print("❌ Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// Toggle completion status of an action item
    /// - Parameter itemId: The action item UUID
    func toggleComplete(_ itemId: UUID) async {
        // Get current state before update
        guard let item = items.first(where: { $0.id == itemId }) else { return }
        let newCompleteState = !item.isComplete
        
        do {
            // Update in repository (observation will update UI automatically)
            try await repository.update(itemId: itemId, isComplete: newCompleteState)
            
        } catch {
            errorMessage = "Failed to update item."
            print("❌ Failed to toggle complete: \(error.localizedDescription)")
        }
    }
    
    /// Delete an action item
    /// - Parameter itemId: The action item UUID
    func deleteItem(_ itemId: UUID) async {
        do {
            try await repository.delete(itemId: itemId)
            await loadItems()
        } catch {
            errorMessage = "Failed to delete item."
            print("❌ Failed to delete item: \(error.localizedDescription)")
        }
    }
    
    /// Update an action item
    /// - Parameter item: The updated action item
    func updateItem(_ item: ActionItem) async {
        do {
            try await repository.update(item: item)
            await loadItems()
        } catch {
            errorMessage = "Failed to update item."
            print("❌ Failed to update item: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Observe action items for real-time updates
    private func observeItems() {
        let stream = repository.observeActionItems(for: conversationId)
        
        Task {
            for await updatedItems in stream {
                self.items = updatedItems
            }
        }
    }
}

