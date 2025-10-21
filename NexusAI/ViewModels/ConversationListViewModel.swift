//
//  ConversationListViewModel.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// ViewModel for managing the conversation list screen
@MainActor
@available(iOS 17.0, *)
class ConversationListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of conversations for the current user
    @Published var conversations: [Conversation] = []
    
    /// Loading state for initial load
    @Published var isLoading = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Search text for filtering conversations
    @Published var searchText = ""
    
    // MARK: - Private Properties
    
    /// Current authenticated user's ID
    private var currentUserId: String {
        guard let uid = Auth.auth().currentUser?.uid else {
            return ""
        }
        return uid
    }
    
    /// Service for conversation operations
    private let conversationService = ConversationService()
    
    /// Service for local storage operations
    private let localStorageService = LocalStorageService.shared
    
    /// Firestore database reference
    private let db = FirebaseService.shared.db
    
    /// Firestore listener registration for cleanup
    private var conversationListener: ListenerRegistration?
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Filtered conversations based on search text
    var filteredConversations: [Conversation] {
        // Return all conversations if search text is empty
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return conversations
        }
        
        let lowercasedSearch = searchText.lowercased()
        
        return conversations.filter { conversation in
            // Search in group name for group conversations
            if conversation.type == .group,
               let groupName = conversation.groupName,
               groupName.lowercased().contains(lowercasedSearch) {
                return true
            }
            
            // Search in participant display names
            for (_, participantInfo) in conversation.participants {
                if participantInfo.displayName.lowercased().contains(lowercasedSearch) {
                    return true
                }
            }
            
            // Search in last message text
            if let lastMessage = conversation.lastMessage,
               lastMessage.text.lowercased().contains(lowercasedSearch) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize the view model and start listening to conversations
    init() {
        // Load cached conversations immediately for offline support
        loadCachedConversations()
        
        // Start listening to conversations for real-time updates
        listenToConversations()
    }
    
    /// Clean up Firestore listener when view model is deallocated
    deinit {
        conversationListener?.remove()
        conversationListener = nil
    }
    
    // MARK: - Public Methods
    
    /// Manually refresh conversations
    func refresh() {
        // Listener already handles real-time updates
        // This method can be used for pull-to-refresh if needed
        listenToConversations()
    }
    
    // MARK: - Private Methods
    
    /// Set up Firestore snapshot listener for conversations
    private func listenToConversations() {
        guard !currentUserId.isEmpty else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Remove existing listener if any
        conversationListener?.remove()
        
        // Query conversations where current user is a participant
        conversationListener = db
            .collection(Constants.Collections.conversations)
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                // Handle errors
                if let error = error {
                    Task { @MainActor in
                        self.isLoading = false
                        self.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    }
                    return
                }
                
                // Process documents
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                // Map documents to Conversation models
                let newConversations = documents.compactMap { document -> Conversation? in
                    do {
                        return try document.data(as: Conversation.self)
                    } catch {
                        print("Error decoding conversation: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                // Update published property on main thread
                Task { @MainActor in
                    // Use incremental update instead of full replacement
                    self.mergeConversations(newConversations)
                    self.isLoading = false
                    
                    // Cache conversations locally
                    self.cacheConversations(newConversations)
                }
            }
    }
    
    /// Merge new conversations into existing array without full replacement
    /// This prevents SwiftUI from recreating views unnecessarily
    private func mergeConversations(_ newConversations: [Conversation]) {
        // Get IDs from new conversations
        let newIds = Set(newConversations.compactMap { $0.id })
        
        // Update existing conversations or add new ones
        for newConv in newConversations {
            guard let newId = newConv.id else { continue }
            
            if let existingIndex = conversations.firstIndex(where: { $0.id == newId }) {
                // Update existing conversation in place
                conversations[existingIndex] = newConv
            } else {
                // New conversation - add it
                conversations.append(newConv)
            }
        }
        
        // Remove conversations that are no longer in the result
        conversations.removeAll { conv in
            guard let id = conv.id else { return true }
            return !newIds.contains(id)
        }
        
        // Sort by updatedAt (already sorted from Firestore, but ensure it)
        // Handle optional updatedAt by using createdAt as fallback
        conversations.sort { 
            let date1 = $0.updatedAt ?? $0.createdAt
            let date2 = $1.updatedAt ?? $1.createdAt
            return date1 > date2
        }
    }
    
    /// Load cached conversations from local storage
    private func loadCachedConversations() {
        do {
            let cachedConversations = try localStorageService.getCachedConversations()
            
            // Convert cached conversations back to Conversation models
            let conversations = cachedConversations.compactMap { cached -> Conversation? in
                guard let type = ConversationType(rawValue: cached.typeRaw) else {
                    return nil
                }
                
                // Create basic conversation from cached data
                // Note: Participant info is simplified in cache
                return Conversation(
                    id: cached.id,
                    type: type,
                    participantIds: cached.participantIds,
                    participants: [:], // Will be filled by Firestore sync
                    lastMessage: cached.lastMessageText != nil ? Conversation.LastMessage(
                        text: cached.lastMessageText!,
                        senderId: "",
                        senderName: "",
                        timestamp: cached.lastMessageTimestamp ?? cached.updatedAt ?? cached.createdAt
                    ) : nil,
                    groupName: cached.groupName,
                    groupImageUrl: nil,
                    createdAt: cached.createdAt,
                    updatedAt: cached.updatedAt
                )
            }
            
            // Only use cached data if we have some
            if !conversations.isEmpty {
                self.conversations = conversations
            }
        } catch {
            print("Failed to load cached conversations: \(error.localizedDescription)")
            // Don't show error to user - this is just a cache miss
        }
    }
    
    /// Cache conversations to local storage
    private func cacheConversations(_ conversations: [Conversation]) {
        // Cache in background to avoid blocking UI
        Task {
            do {
                // Clear existing cache to avoid duplicates
                try await MainActor.run {
                    try self.localStorageService.clearCachedConversations()
                }
                
                // Cache new conversations
                try await MainActor.run {
                    try self.localStorageService.cacheConversations(conversations)
                }
            } catch {
                print("Failed to cache conversations: \(error.localizedDescription)")
                // Silent failure - caching is best-effort
            }
        }
    }
}

