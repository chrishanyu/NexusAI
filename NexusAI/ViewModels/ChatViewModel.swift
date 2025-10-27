//
//  ChatViewModel.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

/// ViewModel for managing the chat screen
@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All messages in the conversation
    @Published var allMessages: [Message] = []
    
    /// Current conversation
    @Published var conversation: Conversation?
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Text input for new message
    @Published var messageText = ""
    
    /// Pagination: Loading older messages state
    @Published var isLoadingOlderMessages = false
    
    /// Pagination: Whether more messages are available to load
    @Published var hasMoreMessages = true
    
    /// Pagination: Last loaded message for cursor-based pagination
    @Published var lastLoadedMessage: Message?
    
    /// Presence: Whether the other user is online (for 1v1 chats)
    @Published var isOtherUserOnline: Bool = false
    
    /// Presence: Last seen timestamp for the other user (for 1v1 chats)
    @Published var otherUserLastSeen: Date?
    
    // MARK: - Private Properties
    
    /// Conversation ID (internal for access from ChatView)
    let conversationId: String
    
    /// Current authenticated user's ID
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    /// Current user's display name from conversation participants
    private var currentUserDisplayName: String {
        let displayName = conversation?.participants[currentUserId]?.displayName ?? ""
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : displayName
    }
    
    /// Whether this is a group conversation
    var isGroupConversation: Bool {
        conversation?.type == .group
    }
    
    // MARK: - Local-First Sync Dependencies (if enabled)
    
    private var messageRepository: MessageRepositoryProtocol?
    private var conversationRepository: ConversationRepositoryProtocol?
    
    // MARK: - Legacy Dependencies (if local-first disabled)
    
    /// Message service (legacy)
    private var messageService: MessageService?
    
    /// Conversation service (legacy)
    private var conversationService: ConversationService?
    
    /// Local storage service (legacy)
    private var localStorageService: LocalStorageService?
    
    /// Message queue service for offline messages (legacy)
    private var messageQueueService: MessageQueueService?
    
    /// Firestore listener registration (legacy)
    private var messageListener: ListenerRegistration?
    
    /// Presence listener handle for RTDB (nonisolated for cleanup in deinit)
    nonisolated(unsafe) private var presenceListenerHandle: DatabaseHandle?
    
    /// Other user ID for presence tracking (nonisolated for cleanup in deinit)
    nonisolated(unsafe) private var otherUserIdForPresence: String?
    
    /// Presence service
    private let presenceService = RealtimePresenceService.shared
    
    // MARK: - Shared Dependencies
    
    /// Network monitor for connectivity status
    private let networkMonitor = NetworkMonitor.shared
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for auto-dismissing error messages
    private var errorDismissTimer: Timer?
    
    /// Whether the device is offline
    @Published var isOffline: Bool = false
    
    /// Task for debouncing mark-as-read calls
    private var markAsReadTask: Task<Void, Never>?
    
    /// Task for listening to repository messages
    private var repositoryListenerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize with conversation ID and optional repositories
    /// - Parameters:
    ///   - conversationId: ID of the conversation to display
    ///   - messageRepository: Optional message repository (for testing or local-first sync)
    ///   - conversationRepository: Optional conversation repository (for testing or local-first sync)
    init(
        conversationId: String,
        messageRepository: MessageRepositoryProtocol? = nil,
        conversationRepository: ConversationRepositoryProtocol? = nil
    ) {
        self.conversationId = conversationId
        
        // Set up dependencies based on feature flag
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            // Use repositories (local-first sync)
            self.messageRepository = messageRepository ?? RepositoryFactory.shared.messageRepository
            self.conversationRepository = conversationRepository ?? RepositoryFactory.shared.conversationRepository
            print("✅ ChatViewModel using local-first sync (repositories)")
        } else {
            // Use legacy services (direct Firebase)
            self.messageService = MessageService()
            self.conversationService = ConversationService()
            self.localStorageService = LocalStorageService.shared
            self.messageQueueService = MessageQueueService.shared
            print("✅ ChatViewModel using legacy Firebase services")
        }
        
        // Load conversation details and messages
        loadConversation()
        
        // Set initial offline status
        isOffline = !networkMonitor.isConnected
        
        // Observe network connectivity changes
        observeNetworkStatus()
        
        // Start listening to real-time message updates
        startListeningToMessages()
    }
    
    /// Clean up listeners when view model is deallocated
    deinit {
        messageListener?.remove()
        messageListener = nil
        repositoryListenerTask?.cancel()
        repositoryListenerTask = nil
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
        cleanupPresenceListener()
    }
    
    // MARK: - Public Methods
    
    /// Clean up listeners when view is dismissed
    func cleanupListeners() {
        messageListener?.remove()
        messageListener = nil
        repositoryListenerTask?.cancel()
        repositoryListenerTask = nil
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
        markAsReadTask?.cancel()
        markAsReadTask = nil
        cleanupPresenceListener()
        print("✅ Chat listeners cleaned up")
    }
    
    /// Mark visible unread messages as read with debouncing
    /// - Note: This method debounces calls by 800ms to prevent excessive Firestore writes
    ///   and to allow delivered status to be visible before marking as read
    func markVisibleMessagesAsRead() {
        // Cancel any existing mark-as-read task (debouncing)
        markAsReadTask?.cancel()
        
        // Create new debounced task
        markAsReadTask = Task { @MainActor in
            // Wait 800ms before executing (debounce + allow delivered status to show)
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms
            
            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }
            
            // Filter messages to find unread messages
            let unreadMessages = allMessages.filter { message in
                // Only messages sent by others
                guard message.senderId != currentUserId else { return false }
                
                // Only messages not already read by current user
                guard !message.readBy.contains(currentUserId) else { return false }
                
                // Only messages with Firestore IDs
                guard message.id != nil else { return false }
                
                return true
            }
            
            // Extract message IDs
            let messageIds = unreadMessages.compactMap { $0.id }
            
            // Return early if no messages to mark as read
            guard !messageIds.isEmpty else { return }
            
            // Mark messages as read using appropriate service
            do {
                if let repository = messageRepository {
                    // Use repository (local-first sync)
                    try await repository.markMessagesAsRead(
                        messageIds: messageIds,
                        conversationId: conversationId,
                        userId: currentUserId
                    )
                } else if let service = messageService {
                    // Use legacy service
                    try await service.markMessagesAsRead(
                        messageIds: messageIds,
                        conversationId: conversationId,
                        userId: currentUserId
                    )
                }
            } catch {
                // Silent failure - read receipts shouldn't block chat functionality
            }
        }
    }
    
    /// Send a new message
    func sendMessage() {
        // Trim whitespace
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Clear input immediately for better UX
        messageText = ""
        
        // Use repository if local-first sync is enabled
        if let repository = messageRepository {
            // Repository pattern: Optimistic UI and sync handled automatically
            Task {
                do {
                    _ = try await repository.sendMessage(
                        conversationId: conversationId,
                        text: trimmedText,
                        senderId: currentUserId,
                        senderName: currentUserDisplayName
                    )
                    print("✅ Message sent via repository (optimistic UI handled automatically)")
                } catch {
                    await MainActor.run {
                        self.setErrorMessage("Failed to send message: \(error.localizedDescription)")
                    }
                    print("❌ Repository send message failed: \(error.localizedDescription)")
                }
            }
            return
        }
        
        // Legacy path: Manual optimistic UI and queue management
        guard let service = messageService, let localStorage = localStorageService, let queueService = messageQueueService else {
            return
        }
        
        // Generate unique local ID for optimistic message
        let localId = UUID().uuidString
        
        // Create optimistic message with "sending" status
        let optimisticMessage = Message(
            id: nil, // No Firestore ID yet
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: currentUserDisplayName,
            text: trimmedText,
            timestamp: Date(),
            status: .sending,
            readBy: [currentUserId], // Mark as read by sender
            deliveredTo: [],
            localId: localId
        )
        
        // Add directly to allMessages for immediate display
        allMessages.append(optimisticMessage)
        
        // Save to local cache (best-effort, non-blocking)
        Task {
            do {
                try await MainActor.run {
                    try localStorage.cacheMessages([optimisticMessage])
                }
            } catch {
                print("Failed to cache optimistic message: \(error.localizedDescription)")
                // Silent failure - caching is best-effort
            }
        }
        
        // Check network status and decide whether to send or queue
        if networkMonitor.isConnected {
            // Online: Send message to Firestore immediately
            Task {
                do {
                    // Call MessageService to send message
                    let messageId = try await service.sendMessage(
                        conversationId: conversationId,
                        text: trimmedText,
                        senderId: currentUserId,
                        senderName: currentUserDisplayName,
                        localId: localId
                    )
                    
                    // On success: update message in allMessages with Firestore ID
                    await MainActor.run {
                        if let index = allMessages.firstIndex(where: { $0.localId == localId }) {
                            var updatedMessage = allMessages[index]
                            updatedMessage.id = messageId
                            updatedMessage.status = .delivered // Message is delivered once written to Firebase
                            allMessages[index] = updatedMessage
                        }
                    }
                } catch {
                    // On failure: update message status to "failed"
                    await MainActor.run {
                        if let index = allMessages.firstIndex(where: { $0.localId == localId }) {
                            var failedMessage = allMessages[index]
                            failedMessage.status = .failed
                            allMessages[index] = failedMessage
                        }
                        
                        // Set error message for user feedback with auto-dismiss
                        self.setErrorMessage("Failed to send message: \(error.localizedDescription)")
                    }
                    
                    print("Failed to send message to Firestore: \(error.localizedDescription)")
                }
            }
        } else {
            // Offline: Add message to queue
            Task {
                do {
                    try await MainActor.run {
                        try queueService.enqueue(message: optimisticMessage)
                    }
                    print("Message queued for sending when online: \(localId)")
                    // Keep status as "sending" - will be sent when connectivity is restored
                } catch {
                    // Failed to queue - mark as failed
                    await MainActor.run {
                        if let index = allMessages.firstIndex(where: { $0.localId == localId }) {
                            var failedMessage = allMessages[index]
                            failedMessage.status = .failed
                            allMessages[index] = failedMessage
                        }
                        self.setErrorMessage("Failed to queue message: \(error.localizedDescription)")
                    }
                    print("Failed to enqueue message: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Manually refresh messages (triggered by pull-to-refresh)
    func refresh() async {
        // If using local-first sync, trigger a force sync for this conversation
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            await SyncEngine.shared.forceSyncMessages(conversationId: conversationId)
        } else {
            // Legacy mode: restart message listener
            await MainActor.run {
                if let listener = messageListener {
                    listener.remove()
                    messageListener = nil
                }
                startListeningToMessages()
            }
        }
    }
    
    /// Retry sending a failed message
    /// - Parameter localId: The localId of the failed message to retry
    func retryMessage(localId: String) {
        // Note: Retry is only available in legacy mode
        // Repository mode handles retries automatically
        guard let service = messageService else {
            print("⚠️ Retry not available - using repository mode with automatic retry")
            return
        }
        
        // Find the failed message
        guard let index = allMessages.firstIndex(where: { $0.localId == localId }) else {
            print("Failed to find message with localId: \(localId)")
            return
        }
        
        let failedMessage = allMessages[index]
        
        // Create new message with "sending" status and updated timestamp
        let retryingMessage = Message(
            id: failedMessage.id,
            conversationId: failedMessage.conversationId,
            senderId: failedMessage.senderId,
            senderName: failedMessage.senderName,
            text: failedMessage.text,
            timestamp: Date(), // Update timestamp to current time
            status: .sending,
            readBy: failedMessage.readBy,
            deliveredTo: failedMessage.deliveredTo,
            localId: failedMessage.localId
        )
        allMessages[index] = retryingMessage
        
        // Clear any previous error message
        errorMessage = nil
        
        // Retry sending to Firestore
        Task {
            do {
                // Call MessageService to send message
                let messageId = try await service.sendMessage(
                    conversationId: conversationId,
                    text: failedMessage.text,
                    senderId: currentUserId,
                    senderName: currentUserDisplayName,
                    localId: localId
                )
                
                // On success: update optimistic message with Firestore ID and "sent" status
                await MainActor.run {
                    if let index = allMessages.firstIndex(where: { $0.localId == localId }) {
                        var updatedMessage = allMessages[index]
                        updatedMessage.id = messageId
                        updatedMessage.status = .sent
                        allMessages[index] = updatedMessage
                    }
                }
            } catch {
                // On failure: update message status back to "failed"
                await MainActor.run {
                    if let index = allMessages.firstIndex(where: { $0.localId == localId }) {
                        var failedMessage = allMessages[index]
                        failedMessage.status = .failed
                        allMessages[index] = failedMessage
                    }
                    
                    // Set error message for user feedback with auto-dismiss
                    self.setErrorMessage("Failed to send message: \(error.localizedDescription)")
                }
                
                print("Failed to retry message: \(error.localizedDescription)")
            }
        }
    }
    
    /// Load older messages (pagination)
    func loadOlderMessages() {
        // Note: Repository mode loads all messages automatically
        // Pagination is only needed in legacy mode
        guard let service = messageService else {
            print("ℹ️ Pagination not needed - repository mode loads all messages")
            return
        }
        
        // Don't load if already loading or no more messages
        guard !isLoadingOlderMessages, hasMoreMessages else {
            print("⚠️ Skipping load: isLoading=\(isLoadingOlderMessages), hasMore=\(hasMoreMessages)")
            return
        }
        
        // Get the oldest message timestamp from current messages
        guard let oldestMessage = allMessages.first else {
            print("⚠️ No messages to paginate from")
            hasMoreMessages = false
            return
        }
        
        isLoadingOlderMessages = true
        print("📥 Loading older messages before \(oldestMessage.timestamp)...")
        
        Task {
            do {
                // Query Firestore for messages before the oldest timestamp
                let olderMessages = try await service.getMessagesBefore(
                    conversationId: conversationId,
                    beforeDate: oldestMessage.timestamp,
                    limit: 50
                )
                
                await MainActor.run {
                    print("✅ Loaded \(olderMessages.count) older messages")
                    
                    // Prepend older messages to allMessages
                    self.allMessages = olderMessages + self.allMessages
                    
                    // Update pagination state
                    if olderMessages.count < 50 {
                        // Fewer than requested means we've reached the end
                        self.hasMoreMessages = false
                        print("📭 No more messages to load")
                    }
                    
                    // Update last loaded message for cursor tracking
                    self.lastLoadedMessage = olderMessages.first
                    
                    self.isLoadingOlderMessages = false
                    
                    // Cache the loaded messages to local storage
                    self.cacheMessagesToLocalStorage(olderMessages)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoadingOlderMessages = false
                    self.setErrorMessage("Failed to load older messages: \(error.localizedDescription)")
                    print("❌ Error loading older messages: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Start listening to real-time message updates
    private func startListeningToMessages() {
        if let repository = messageRepository {
            // Use repository pattern with AsyncStream
            repositoryListenerTask = Task { @MainActor in
                for await messages in repository.observeMessages(conversationId: conversationId) {
                    // Repository returns all messages for the conversation
                    self.allMessages = messages.sorted { $0.timestamp < $1.timestamp }
                    
                    // Update pagination state
                    if messages.count < 50 {
                        self.hasMoreMessages = false
                    }
                    
                    // Mark new unread messages as read (if chat is visible)
                    // This handles messages that arrive while user is already in the chat
                    self.markVisibleMessagesAsRead()
                    
                    // Reduced logging - only in debug mode
                    #if DEBUG
                    print("📨 \(messages.count) messages")
                    #endif
                }
            }
            return
        }
        
        // Legacy path: Use MessageService with callback
        guard let service = messageService else { return }
        
        var isInitialLoad = true
        
        messageListener = service.listenToMessages(
            conversationId: conversationId,
            limit: 50
        ) { [weak self] messages in
            guard let self = self else { return }
            
            // Merge Firestore messages into allMessages
            Task { @MainActor in
                if isInitialLoad {
                    if messages.count < 50 {
                        self.hasMoreMessages = false
                    }
                    isInitialLoad = false
                }
                
                // Always merge, whether initial or subsequent
                self.mergeFirestoreMessages(messages)
                
                // Cache messages to local storage for offline access
                self.cacheMessagesToLocalStorage(messages)
            }
        }
    }
    
    /// Merge Firestore messages into allMessages array
    private func mergeFirestoreMessages(_ firestoreMessages: [Message]) {
        // Safety check: if we have messages and Firestore returns empty, keep our messages
        if !allMessages.isEmpty && firestoreMessages.isEmpty {
            return
        }
        
        // Process each Firestore message
        for firestoreMessage in firestoreMessages {
            // Try to find existing message by localId or id
            if let existingIndex = allMessages.firstIndex(where: { existingMsg in
                // Match by localId first (most reliable for deduplication)
                if let fLocalId = firestoreMessage.localId,
                   let eLocalId = existingMsg.localId,
                   fLocalId == eLocalId {
                    return true
                }
                // Match by id second
                if let fId = firestoreMessage.id,
                   let eId = existingMsg.id,
                   fId == eId {
                    return true
                }
                return false
            }) {
                // Update existing message with Firestore data
                allMessages[existingIndex] = firestoreMessage
            } else {
                // This is a new message we don't have yet
                allMessages.append(firestoreMessage)
            }
        }
        
        // Sort messages by timestamp
        allMessages.sort { $0.timestamp < $1.timestamp }
        
        // Mark new unread messages as read (if chat is visible)
        // This handles messages that arrive while user is already in the chat
        markVisibleMessagesAsRead()
    }
    
    /// Cache messages to local storage (legacy mode only)
    /// - Parameter messages: Messages to cache
    private func cacheMessagesToLocalStorage(_ messages: [Message]) {
        guard !messages.isEmpty, let localStorage = localStorageService else { return }
        
        Task {
            do {
                // First, clear existing cached messages for this conversation to avoid duplicates
                try await MainActor.run {
                    try localStorage.clearCachedMessages(conversationId: conversationId)
                }
                
                // Then cache the new messages
                try await MainActor.run {
                    try localStorage.cacheMessages(messages)
                }
            } catch {
                print("⚠️ Failed to cache messages: \(error.localizedDescription)")
                // Silent failure - caching is best-effort
            }
        }
    }
    
    /// Observe network connectivity changes
    private func observeNetworkStatus() {
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                let wasOffline = self.isOffline
                self.isOffline = !isConnected
                
                // If we just came back online, flush the message queue (legacy mode only)
                if wasOffline && isConnected, let queueService = self.messageQueueService {
                    print("Network restored - flushing message queue")
                    Task {
                        let results = await queueService.flushQueue()
                        
                        // Update optimistic messages with flush results
                        await MainActor.run {
                            for result in results {
                                if result.success, let messageId = result.messageId {
                                    // Update optimistic message with Firestore ID
                                    if let index = self.allMessages.firstIndex(where: { $0.localId == result.localId }) {
                                        var updatedMessage = self.allMessages[index]
                                        updatedMessage.id = messageId
                                        updatedMessage.status = .sent
                                        self.allMessages[index] = updatedMessage
                                    }
                                }
                                // Failed messages stay in queue with "sending" status
                            }
                        }
                    }
                } else if !isConnected {
                    print("Network lost - messages will be queued")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Load conversation details
    private func loadConversation() {
        isLoading = true
        
        Task {
            do {
                let conversation: Conversation?
                
                // Use appropriate service based on feature flag
                if let repository = conversationRepository {
                    // Use repository
                    conversation = try await repository.getConversation(conversationId: conversationId)
                } else if let service = conversationService {
                    // Use legacy service
                    conversation = try await service.getConversation(conversationId: conversationId)
                } else {
                    throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No conversation service available"])
                }
                
                await MainActor.run {
                    if let conversation = conversation {
                        self.conversation = conversation
                        // Start listening to presence for 1v1 chats
                        self.startListeningToPresence()
                    } else {
                        self.setErrorMessage("Conversation not found")
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.setErrorMessage("Failed to load conversation: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Presence Tracking
    
    /// Start listening to the other user's presence status (for 1v1 chats only)
    private func startListeningToPresence() {
        // Only track presence for 1v1 conversations
        guard let conversation = conversation, conversation.type == .direct else {
            return
        }
        
        // Get the other user's ID
        guard let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else {
            print("⚠️ Could not find other user in conversation")
            return
        }
        
        // Clean up any existing listener
        cleanupPresenceListener()
        
        // Cache the other user ID for cleanup
        otherUserIdForPresence = otherUserId
        
        // Start listening to presence
        presenceListenerHandle = presenceService.listenToPresence(userId: otherUserId) { [weak self] isOnline, lastSeen in
            Task { @MainActor in
                self?.isOtherUserOnline = isOnline
                self?.otherUserLastSeen = lastSeen
            }
        }
    }
    
    /// Clean up the presence listener
    nonisolated private func cleanupPresenceListener() {
        guard let handle = presenceListenerHandle,
              let otherUserId = otherUserIdForPresence else {
            return
        }
        
        // Remove observer from Firebase RTDB
        Database.database().reference().child("presence").child(otherUserId).removeObserver(withHandle: handle)
        
        // Clear the stored values
        presenceListenerHandle = nil
        otherUserIdForPresence = nil
    }
    
    // MARK: - Error Handling
    
    /// Set error message with auto-dismiss after 5 seconds
    /// - Parameter message: The error message to display
    private func setErrorMessage(_ message: String) {
        // Cancel any existing timer
        errorDismissTimer?.invalidate()
        
        // Set the error message
        errorMessage = mapErrorToUserFriendlyMessage(message)
        
        // Schedule auto-dismiss after 5 seconds
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: Constants.Animation.errorDismiss, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.errorMessage = nil
            }
        }
    }
    
    /// Map Firestore/system errors to user-friendly messages
    /// - Parameter error: The error message or description
    /// - Returns: A user-friendly error message
    private func mapErrorToUserFriendlyMessage(_ error: String) -> String {
        let lowercasedError = error.lowercased()
        
        // Network errors
        if lowercasedError.contains("network") || lowercasedError.contains("connection") {
            return "No internet connection. Your message will be sent when you're back online."
        }
        
        // Permission errors
        if lowercasedError.contains("permission") || lowercasedError.contains("unauthorized") {
            return "You don't have permission to send messages in this conversation."
        }
        
        // Firestore errors
        if lowercasedError.contains("firestore") || lowercasedError.contains("deadline exceeded") {
            return "Server is taking too long to respond. Please try again."
        }
        
        // Rate limiting
        if lowercasedError.contains("rate") || lowercasedError.contains("quota") {
            return "Too many requests. Please wait a moment and try again."
        }
        
        // Not found errors
        if lowercasedError.contains("not found") || lowercasedError.contains("doesn't exist") {
            return "This conversation no longer exists."
        }
        
        // Generic fallback
        return "Failed to send message. Please try again."
    }
}

