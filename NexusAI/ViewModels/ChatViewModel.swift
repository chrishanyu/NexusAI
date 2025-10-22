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
    
    // MARK: - Private Properties
    
    /// Conversation ID (internal for access from ChatView)
    let conversationId: String
    
    /// Current authenticated user's ID
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    /// Current user's display name from conversation participants
    private var currentUserDisplayName: String {
        conversation?.participants[currentUserId]?.displayName ?? "You"
    }
    
    /// Message service
    private let messageService = MessageService()
    
    /// Conversation service
    private let conversationService = ConversationService()
    
    /// Local storage service
    private let localStorageService = LocalStorageService.shared
    
    /// Network monitor for connectivity status
    private let networkMonitor = NetworkMonitor.shared
    
    /// Message queue service for offline messages
    private let messageQueueService = MessageQueueService.shared
    
    /// Firestore listener registration
    private var messageListener: ListenerRegistration?
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for auto-dismissing error messages
    private var errorDismissTimer: Timer?
    
    /// Whether the device is offline
    @Published var isOffline: Bool = false
    
    /// Task for debouncing mark-as-read calls
    private var markAsReadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize with conversation ID
    /// - Parameter conversationId: ID of the conversation to display
    init(conversationId: String) {
        self.conversationId = conversationId
        
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
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Clean up listeners when view is dismissed
    func cleanupListeners() {
        messageListener?.remove()
        messageListener = nil
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
        markAsReadTask?.cancel()
        markAsReadTask = nil
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
            
            print("📖 Marking \(messageIds.count) messages as read...")
            
            // Call MessageService to mark messages as read (silent failure)
            do {
                try await messageService.markMessagesAsRead(
                    messageIds: messageIds,
                    conversationId: conversationId,
                    userId: currentUserId
                )
                print("✅ Successfully marked \(messageIds.count) messages as read")
            } catch {
                // Silent failure - read receipts shouldn't block chat functionality
                print("⚠️ Failed to mark messages as read: \(error.localizedDescription)")
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
                    try localStorageService.cacheMessages([optimisticMessage])
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
                    let messageId = try await messageService.sendMessage(
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
                            updatedMessage.status = .sent
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
                        try messageQueueService.enqueue(message: optimisticMessage)
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
    
    /// Retry sending a failed message
    /// - Parameter localId: The localId of the failed message to retry
    func retryMessage(localId: String) {
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
                let messageId = try await messageService.sendMessage(
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
                let olderMessages = try await messageService.getMessagesBefore(
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
        var isInitialLoad = true
        
        messageListener = messageService.listenToMessages(
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
                
                // Mark messages as delivered if current user is not the sender
                self.markMessagesAsDelivered(messages)
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
        
        // NOTE: We no longer auto-mark messages as read here.
        // Read status is only marked when user is actively viewing (ChatView lifecycle events)
    }
    
    /// Cache messages to local storage
    /// - Parameter messages: Messages to cache
    private func cacheMessagesToLocalStorage(_ messages: [Message]) {
        guard !messages.isEmpty else { return }
        
        Task {
            do {
                // First, clear existing cached messages for this conversation to avoid duplicates
                try await MainActor.run {
                    try localStorageService.clearCachedMessages(conversationId: conversationId)
                }
                
                // Then cache the new messages
                try await MainActor.run {
                    try localStorageService.cacheMessages(messages)
                }
            } catch {
                print("⚠️ Failed to cache messages: \(error.localizedDescription)")
                // Silent failure - caching is best-effort
            }
        }
    }
    
    /// Mark messages as delivered if the current user is not the sender
    /// - Parameter messages: Messages to check and mark as delivered
    private func markMessagesAsDelivered(_ messages: [Message]) {
        Task {
            for message in messages {
                // Only mark messages where current user is NOT the sender
                guard message.senderId != currentUserId else { continue }
                
                // Only mark if not already delivered to this user
                guard !message.deliveredTo.contains(currentUserId) else { continue }
                
                // Only mark if message has a Firestore ID
                guard let messageId = message.id else { continue }
                
                do {
                    try await messageService.markMessageAsDelivered(
                        conversationId: conversationId,
                        messageId: messageId,
                        userId: currentUserId
                    )
                    print("✅ Marked message \(messageId) as delivered")
                } catch {
                    print("⚠️ Failed to mark message as delivered: \(error.localizedDescription)")
                    // Silent failure - delivery status is best-effort
                }
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
                
                // If we just came back online, flush the message queue
                if wasOffline && isConnected {
                    print("Network restored - flushing message queue")
                    Task {
                        let results = await self.messageQueueService.flushQueue()
                        
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
                let conversation = try await conversationService.getConversation(conversationId: conversationId)
                
                await MainActor.run {
                    self.conversation = conversation
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

