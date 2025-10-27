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
import FirebaseDatabase

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
    
    /// Unread counts for each conversation (conversationId -> count)
    @Published var conversationUnreadCounts: [String: Int] = [:]
    
    // MARK: - Private Properties
    
    /// Current authenticated user's ID
    private var currentUserId: String {
        guard let uid = Auth.auth().currentUser?.uid else {
            return ""
        }
        return uid
    }
    
    // MARK: - Local-First Sync Dependencies (if enabled)
    
    private var conversationRepository: ConversationRepositoryProtocol?
    private var messageRepository: MessageRepositoryProtocol?
    
    // MARK: - Legacy Dependencies (if local-first disabled)
    
    /// Service for conversation operations (legacy)
    private var conversationService: ConversationService?
    
    /// Service for message operations (legacy)
    private var messageService: MessageService?
    
    /// Service for local storage operations (legacy)
    private var localStorageService: LocalStorageService?
    
    /// Firestore database reference (legacy)
    private var db: Firestore?
    
    /// Presence service - use realtime database for reliable presence
    private let presenceService = RealtimePresenceService.shared
    
    /// Firestore listener registration for cleanup (legacy)
    private var conversationListener: ListenerRegistration?
    
    /// Presence listener handles for cleanup (RTDB)
    private var presenceListenerHandles: [DatabaseHandle] = []
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Task for listening to repository conversations
    private var repositoryListenerTask: Task<Void, Never>?
    
    /// Dictionary tracking online status of users (userId -> isOnline)
    @Published var userPresenceMap: [String: Bool] = [:]
    
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
    
    /// Initialize the view model with optional repositories
    /// - Parameters:
    ///   - conversationRepository: Optional conversation repository (for testing or local-first sync)
    ///   - messageRepository: Optional message repository (for testing or local-first sync)
    init(
        conversationRepository: ConversationRepositoryProtocol? = nil,
        messageRepository: MessageRepositoryProtocol? = nil
    ) {
        // Set up dependencies based on feature flag
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            // Use repositories (local-first sync)
            self.conversationRepository = conversationRepository ?? RepositoryFactory.shared.conversationRepository
            self.messageRepository = messageRepository ?? RepositoryFactory.shared.messageRepository
            print("✅ ConversationListViewModel using local-first sync (repositories)")
        } else {
            // Use legacy services (direct Firebase)
            self.conversationService = ConversationService()
            self.messageService = MessageService()
            self.localStorageService = LocalStorageService.shared
            self.db = FirebaseService.shared.db
            print("✅ ConversationListViewModel using legacy Firebase services")
            
            // Load cached conversations immediately for offline support (legacy only)
            loadCachedConversations()
        }
        
        // Start listening to conversations for real-time updates
        listenToConversations()
    }
    
    /// Clean up Firestore listeners when view model is deallocated
    deinit {
        conversationListener?.remove()
        conversationListener = nil
        repositoryListenerTask?.cancel()
        repositoryListenerTask = nil
        
        // Clean up RTDB presence listeners
        // Note: Individual listeners are managed by RealtimePresenceService singleton
        // We just clear our local reference array
        presenceListenerHandles.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Manually refresh conversations
    func refresh() {
        // Listener already handles real-time updates
        // This method can be used for pull-to-refresh if needed
        listenToConversations()
    }
    
    /// Update unread count for a specific conversation (optimistic update)
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - count: New unread count
    func updateUnreadCount(for conversationId: String, count: Int) {
        conversationUnreadCounts[conversationId] = max(0, count) // Ensure non-negative
    }
    
    /// Decrement unread count for a conversation (when messages are read)
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - by: Number to decrement by (default 1)
    func decrementUnreadCount(for conversationId: String, by amount: Int = 1) {
        let currentCount = conversationUnreadCounts[conversationId] ?? 0
        conversationUnreadCounts[conversationId] = max(0, currentCount - amount)
    }
    
    /// Increment unread count for a conversation (when new message arrives)
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - by: Number to increment by (default 1)
    func incrementUnreadCount(for conversationId: String, by amount: Int = 1) {
        let currentCount = conversationUnreadCounts[conversationId] ?? 0
        conversationUnreadCounts[conversationId] = currentCount + amount
    }
    
    // MARK: - Private Methods
    
    /// Set up listener for conversations (repository or Firestore)
    private func listenToConversations() {
        guard !currentUserId.isEmpty else {
            errorMessage = "Not authenticated"
            return
        }
        
        if let repository = conversationRepository {
            // Repository mode: Use AsyncStream
            isLoading = true
            errorMessage = nil
            
            repositoryListenerTask = Task { @MainActor in
                for await conversations in repository.observeConversations(userId: currentUserId) {
                    self.conversations = conversations.sorted {
                        let date1 = $0.updatedAt ?? $0.createdAt
                        let date2 = $1.updatedAt ?? $1.createdAt
                        return date1 > date2
                    }
                    self.isLoading = false
                    
                    // Calculate unread counts using repository
                    await self.calculateUnreadCountsWithRepository()
                    
                    // Update presence listeners
                    self.startPresenceListening()
                    
                    // Reduced logging
                    #if DEBUG
                    print("💬 \(conversations.count) conversations")
                    #endif
                }
            }
            return
        }
        
        // Legacy path: Use Firestore snapshot listener
        guard let database = db else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Remove existing listener if any
        conversationListener?.remove()
        
        // Query conversations where current user is a participant
        conversationListener = database
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
                    
                    // Calculate unread counts for all conversations
                    await self.calculateUnreadCounts()
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
        
        // Fix missing participant information
        Task {
            await enrichMissingParticipantInfo()
        }
        
        // Update presence listeners for new conversations
        startPresenceListening()
    }
    
    /// Load cached conversations from local storage (legacy mode only)
    private func loadCachedConversations() {
        guard let localStorage = localStorageService else { return }
        
        do {
            let cachedConversations = try localStorage.getCachedConversations()
            
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
                    participants: [:], // Will be filled by Firestore sync or enrichment
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
                
                // Enrich participant info immediately after loading from cache
                // This prevents "Unknown User" from showing while waiting for Firestore sync
                Task {
                    await enrichMissingParticipantInfo()
                }
            }
        } catch {
            print("Failed to load cached conversations: \(error.localizedDescription)")
            // Don't show error to user - this is just a cache miss
        }
    }
    
    /// Cache conversations to local storage (legacy mode only)
    private func cacheConversations(_ conversations: [Conversation]) {
        guard let localStorage = localStorageService else { return }
        
        // Cache in background to avoid blocking UI
        Task {
            do {
                // Clear existing cache to avoid duplicates
                try await MainActor.run {
                    try localStorage.clearCachedConversations()
                }
                
                // Cache new conversations
                try await MainActor.run {
                    try localStorage.cacheConversations(conversations)
                }
            } catch {
                print("Failed to cache conversations: \(error.localizedDescription)")
                // Silent failure - caching is best-effort
            }
        }
    }
    
    /// Calculate unread counts using repository (local-first sync)
    private func calculateUnreadCountsWithRepository() async {
        guard let repository = messageRepository else { return }
        
        let userId = currentUserId
        guard !userId.isEmpty else { return }
        
        var newCounts: [String: Int] = [:]
        
        // Get unread counts from repository for each conversation
        for conversation in conversations {
            guard let conversationId = conversation.id else { continue }
            
            do {
                let count = try await repository.getUnreadCount(
                    conversationId: conversationId,
                    userId: userId
                )
                newCounts[conversationId] = count
            } catch {
                print("⚠️ Failed to get unread count for conversation \(conversationId): \(error.localizedDescription)")
                newCounts[conversationId] = 0
            }
        }
        
        // Update on main thread
        await MainActor.run {
            self.conversationUnreadCounts = newCounts
        }
    }
    
    /// Calculate unread counts for all conversations (legacy mode)
    /// This queries Firestore for unread message counts and updates the conversationUnreadCounts dictionary
    private func calculateUnreadCounts() async {
        guard let service = messageService else { return }
        
        // Get current user ID
        let userId = currentUserId
        guard !userId.isEmpty else { return }
        
        // Create temporary dictionary to store counts
        var newCounts: [String: Int] = [:]
        
        // Query unread count for each conversation
        for conversation in conversations {
            guard let conversationId = conversation.id else { continue }
            
            do {
                let count = try await service.getUnreadCount(
                    conversationId: conversationId,
                    userId: userId
                )
                newCounts[conversationId] = count
            } catch {
                print("⚠️ Failed to get unread count for conversation \(conversationId): \(error.localizedDescription)")
                // Continue with other conversations even if one fails
                newCounts[conversationId] = 0
            }
        }
        
        // Update published property on main thread
        await MainActor.run {
            self.conversationUnreadCounts = newCounts
        }
    }
    
    /// Enrich conversations with missing participant information
    /// This fixes the "Unknown User" bug by fetching user profiles for participants with empty display names
    private func enrichMissingParticipantInfo() async {
        let authService = AuthService()
        let userId = currentUserId
        guard !userId.isEmpty else { return }
        
        // Work with a snapshot of conversations to avoid index issues
        let conversationsSnapshot = conversations
        
        // Dictionary to store enriched conversations by ID
        var enrichedConversations: [String: Conversation] = [:]
        
        // Check each conversation for missing participant info
        for conversation in conversationsSnapshot {
            // Skip group conversations - they usually have their own name
            // Only fix direct conversations where participant info is missing
            guard conversation.type == .direct else { continue }
            
            // Find the other participant (not current user)
            guard let otherParticipantId = conversation.participantIds.first(where: { $0 != userId }) else {
                continue
            }
            
            // Check if participant info is missing or empty
            let participantInfo = conversation.participants[otherParticipantId]
            let needsEnrichment = participantInfo == nil || 
                                  participantInfo?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            
            guard needsEnrichment else { continue }
            
            // Fetch user profile from Firestore
            do {
                let userProfile = try await authService.getUserProfile(userId: otherParticipantId)
                
                // Create updated conversation with enriched participant info
                var updatedConversation = conversation
                updatedConversation.participants[otherParticipantId] = Conversation.ParticipantInfo(
                    displayName: userProfile.displayName,
                    profileImageUrl: userProfile.profileImageUrl
                )
                
                // Store enriched conversation
                if let convId = conversation.id {
                    enrichedConversations[convId] = updatedConversation
                    print("✅ Enriched participant info for conversation \(convId): \(userProfile.displayName)")
                }
            } catch {
                print("⚠️ Failed to fetch user profile for \(otherParticipantId): \(error.localizedDescription)")
                // Continue with other conversations - this is best-effort
            }
        }
        
        // Apply all enriched conversations to the main array in one update
        guard !enrichedConversations.isEmpty else { return }
        
        await MainActor.run {
            // Create a completely new array to force SwiftUI to detect the change
            var updatedConversations: [Conversation] = []
            
            for conversation in self.conversations {
                if let convId = conversation.id,
                   let enriched = enrichedConversations[convId] {
                    // Use the enriched version
                    updatedConversations.append(enriched)
                } else {
                    // Keep the original
                    updatedConversations.append(conversation)
                }
            }
            
            // Replace entire array to trigger SwiftUI update
            self.conversations = updatedConversations
        }
    }
    
    // MARK: - Presence Tracking
    
    /// Start listening to presence for all conversation participants
    private func startPresenceListening() {
        // Clean up existing listeners if any
        presenceListenerHandles.removeAll()
        
        // Collect all unique user IDs from conversations (excluding current user)
        var allParticipantIds = Set<String>()
        for conversation in conversations {
            for participantId in conversation.participantIds where participantId != currentUserId {
                allParticipantIds.insert(participantId)
            }
        }
        
        // Only set up listener if we have participants to track
        guard !allParticipantIds.isEmpty else {
            return
        }
        
        // Convert to array - RTDB doesn't have the 10-user limit like Firestore!
        let participantIdsArray = Array(allParticipantIds)
        
        // Set up presence listener using RTDB
        presenceListenerHandles = presenceService.listenToMultiplePresence(userIds: participantIdsArray) { [weak self] presenceMap in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.userPresenceMap = presenceMap
            }
        }
    }
}

