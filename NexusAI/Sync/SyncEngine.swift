//
//  SyncEngine.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import FirebaseFirestore
import Combine

/// Main sync engine coordinator that handles bidirectional synchronization
/// between Firestore and local SwiftData storage
@MainActor
final class SyncEngine {
    
    // MARK: - Properties
    
    private let database: LocalDatabase
    private let firebaseService: FirebaseService
    private let conflictResolver: ConflictResolver
    private let networkMonitor: any NetworkMonitoring
    private let conversationRepository: ConversationRepositoryProtocol
    
    /// Firestore listeners for real-time updates
    private var conversationMessageListeners: [String: ListenerRegistration] = [:]
    private var conversationListener: ListenerRegistration?
    private var userListener: ListenerRegistration?
    
    /// Track if sync engine is currently running
    private(set) var isRunning: Bool = false
    
    /// Sync worker task
    private var syncWorkerTask: Task<Void, Never>?
    
    /// Combine cancellables for network monitoring
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        database: LocalDatabase? = nil,
        firebaseService: FirebaseService? = nil,
        conflictResolver: ConflictResolver? = nil,
        networkMonitor: (any NetworkMonitoring)? = nil,
        conversationRepository: ConversationRepositoryProtocol? = nil
    ) {
        self.database = database ?? LocalDatabase.shared
        self.firebaseService = firebaseService ?? FirebaseService.shared
        self.conversationRepository = conversationRepository ?? RepositoryFactory.shared.conversationRepository
        self.conflictResolver = conflictResolver ?? ConflictResolver()
        self.networkMonitor = networkMonitor ?? NetworkMonitor.shared
        
        print("✅ SyncEngine initialized")
    }
    
    // MARK: - Lifecycle
    
    /// Start all Firestore listeners for pull sync and sync worker for push sync
    func start() {
        guard !isRunning else {
            print("⚠️ SyncEngine already running")
            return
        }
        
        print("🚀 Starting SyncEngine...")
        
        // Start network monitoring
        observeNetworkChanges()
        
        // Start database change monitoring for immediate sync
        observeDatabaseChanges()
        
        // Start pull sync listeners
        startMessageListener()
        startConversationListener()
        startUserListener()
        
        // Start push sync worker
        startSyncWorker()
        
        isRunning = true
        print("✅ SyncEngine started successfully")
    }
    
    /// Stop all Firestore listeners and sync worker
    func stop() {
        guard isRunning else {
            print("⚠️ SyncEngine not running")
            return
        }
        
        print("🛑 Stopping SyncEngine...")
        
        // Stop network monitoring
        cancellables.removeAll()
        
        // Stop pull sync listeners
        for (conversationId, listener) in conversationMessageListeners {
            listener.remove()
            print("🧹 Removed message listener for conversation: \(conversationId)")
        }
        conversationMessageListeners.removeAll()
        
        conversationListener?.remove()
        userListener?.remove()
        
        conversationListener = nil
        userListener = nil
        
        // Stop push sync worker
        syncWorkerTask?.cancel()
        syncWorkerTask = nil
        
        isRunning = false
        print("✅ SyncEngine stopped successfully")
    }
    
    // MARK: - Network Monitoring
    
    /// Observe network status changes and trigger sync on reconnection
    private func observeNetworkChanges() {
        print("📡 Starting network monitoring...")
        
        // Track previous connection state to detect transitions
        var wasConnected = networkMonitor.isConnected
        
        networkMonitor.isConnectedPublisher
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if isConnected && !wasConnected {
                        // Network reconnected - trigger immediate sync
                        print("🌐 Network reconnected - triggering immediate sync...")
                        await self.performSyncCycle()
                    } else if !isConnected && wasConnected {
                        // Network disconnected
                        print("📴 Network disconnected - sync paused")
                    }
                    
                    wasConnected = isConnected
                }
            }
            .store(in: &cancellables)
        
        print("✅ Network monitoring active")
    }
    
    /// Observe database changes and trigger immediate sync for pending entities
    private func observeDatabaseChanges() {
        print("📡 Starting database change monitoring...")
        
        NotificationCenter.default
            .publisher(for: .localDatabaseDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // Check if we're online before triggering sync
                    guard self.networkMonitor.isConnected else {
                        return
                    }
                    
                    // Trigger immediate sync cycle for pending entities
                    print("🔄 Database changed - triggering immediate sync...")
                    await self.performSyncCycle()
                }
            }
            .store(in: &cancellables)
        
        print("✅ Database change monitoring active")
    }
    
    // MARK: - Push Sync Worker
    
    /// Start background worker to sync pending entities
    private func startSyncWorker() {
        print("🔄 Starting sync worker...")
        
        syncWorkerTask = Task { @MainActor in
            while !Task.isCancelled {
                // Run sync cycle
                await performSyncCycle()
                
                // Wait 10 seconds before next cycle
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        
        print("✅ Sync worker started")
    }
    
    /// Perform one sync cycle - sync all pending/failed entities
    internal func performSyncCycle() async {
        // Skip sync if offline
        guard networkMonitor.isConnected else {
            // Silently skip - don't spam logs when offline
            return
        }
        
        var totalSynced = 0
        var totalFailed = 0
        
        // Sync pending and failed messages
        let (messagesSynced, messagesFailed) = await syncPendingMessages()
        totalSynced += messagesSynced
        totalFailed += messagesFailed
        
        // Sync pending and failed conversations
        let (conversationsSynced, conversationsFailed) = await syncPendingConversations()
        totalSynced += conversationsSynced
        totalFailed += conversationsFailed
        
        // Sync pending and failed users
        let (usersSynced, usersFailed) = await syncPendingUsers()
        totalSynced += usersSynced
        totalFailed += usersFailed
        
        // Only log if there was actual work done
        if totalSynced > 0 || totalFailed > 0 {
            print("✅ Synced: \(totalSynced) | Failed: \(totalFailed)")
        }
    }
    
    /// Sync all pending and retry-eligible failed messages
    private func syncPendingMessages() async -> (synced: Int, failed: Int) {
        do {
            // Query for pending messages
            let pendingPredicate = #Predicate<LocalMessage> { message in
                message.syncStatusRaw == "pending"
            }
            let pendingMessages = try database.fetch(LocalMessage.self, where: pendingPredicate)
            
            if !pendingMessages.isEmpty {
                print("📤 [SYNC] Found \(pendingMessages.count) pending messages to sync")
                for msg in pendingMessages {
                    print("📤 [SYNC] Pending: \(msg.id) - readBy: \(msg.readBy), status: \(msg.status)")
                }
            }
            
            // Query for failed messages
            let failedPredicate = #Predicate<LocalMessage> { message in
                message.syncStatusRaw == "failed"
            }
            let failedMessages = try database.fetch(LocalMessage.self, where: failedPredicate)
            
            // Filter failed messages that are eligible for retry
            let retryableMessages = failedMessages.filter { message in
                shouldRetrySync(
                    status: .failed,
                    retryCount: message.syncRetryCount,
                    lastAttempt: message.lastSyncAttempt
                )
            }
            
            // Combine pending and retryable messages
            let messagesToSync = pendingMessages + retryableMessages
            
            // Sort by timestamp (oldest first) for proper ordering
            let sortedMessages = messagesToSync.sorted { $0.timestamp < $1.timestamp }
            
            var synced = 0
            var failed = 0
            
            // Sync each message
            for message in sortedMessages {
                let success = await syncMessage(message)
                if success {
                    synced += 1
                } else {
                    failed += 1
                }
            }
            
            return (synced, failed)
            
        } catch {
            print("❌ Error querying pending messages: \(error.localizedDescription)")
            return (0, 0)
        }
    }
    
    /// Sync all pending and retry-eligible failed conversations
    private func syncPendingConversations() async -> (synced: Int, failed: Int) {
        do {
            // Query for pending conversations
            let pendingPredicate = #Predicate<LocalConversation> { conversation in
                conversation.syncStatusRaw == "pending"
            }
            let pendingConversations = try database.fetch(LocalConversation.self, where: pendingPredicate)
            
            // Query for failed conversations
            let failedPredicate = #Predicate<LocalConversation> { conversation in
                conversation.syncStatusRaw == "failed"
            }
            let failedConversations = try database.fetch(LocalConversation.self, where: failedPredicate)
            
            // Filter failed conversations that are eligible for retry
            let retryableConversations = failedConversations.filter { conversation in
                shouldRetrySync(
                    status: .failed,
                    retryCount: conversation.syncRetryCount,
                    lastAttempt: conversation.lastSyncAttempt
                )
            }
            
            // Combine pending and retryable conversations
            let conversationsToSync = pendingConversations + retryableConversations
            
            // Sort by updatedAt (oldest first) for proper ordering
            let sortedConversations = conversationsToSync.sorted { 
                $0.updatedAt < $1.updatedAt
            }
            
            var synced = 0
            var failed = 0
            
            // Sync each conversation
            for conversation in sortedConversations {
                let success = await syncConversation(conversation)
                if success {
                    synced += 1
                } else {
                    failed += 1
                }
            }
            
            return (synced, failed)
            
        } catch {
            print("❌ Error querying pending conversations: \(error.localizedDescription)")
            return (0, 0)
        }
    }
    
    /// Sync all pending and retry-eligible failed users
    private func syncPendingUsers() async -> (synced: Int, failed: Int) {
        do {
            // Query for pending users
            let pendingPredicate = #Predicate<LocalUser> { user in
                user.syncStatusRaw == "pending"
            }
            let pendingUsers = try database.fetch(LocalUser.self, where: pendingPredicate)
            
            // Query for failed users
            let failedPredicate = #Predicate<LocalUser> { user in
                user.syncStatusRaw == "failed"
            }
            let failedUsers = try database.fetch(LocalUser.self, where: failedPredicate)
            
            // Filter failed users that are eligible for retry
            let retryableUsers = failedUsers.filter { user in
                shouldRetrySync(
                    status: .failed,
                    retryCount: user.syncRetryCount,
                    lastAttempt: user.lastSyncAttempt
                )
            }
            
            // Combine pending and retryable users
            let usersToSync = pendingUsers + retryableUsers
            
            // Sort by lastSeen (oldest first) for proper ordering
            let sortedUsers = usersToSync.sorted { $0.lastSeen < $1.lastSeen }
            
            var synced = 0
            var failed = 0
            
            // Sync each user
            for user in sortedUsers {
                let success = await syncUser(user)
                if success {
                    synced += 1
                } else {
                    failed += 1
                }
            }
            
            return (synced, failed)
            
        } catch {
            print("❌ Error querying pending users: \(error.localizedDescription)")
            return (0, 0)
        }
    }
    
    // MARK: - Pull Sync - Message Listener
    
    /// Start listening to Firestore messages for real-time pull sync
    /// Creates per-conversation listeners based on user's conversations
    private func startMessageListener() {
        guard let currentUserId = firebaseService.currentUserId else {
            print("⚠️ Cannot start message listener: No authenticated user")
            return
        }
        
        print("📥 Starting message listeners for user: \(currentUserId)...")
        
        // Observe conversation repository to get user's conversations
        // When conversations change, add/remove message listeners accordingly
        Task {
            do {
                // Get initial conversations for current user
                let conversations = try await conversationRepository.getConversations(userId: currentUserId)
                print("ℹ️ Found \(conversations.count) conversations to monitor")
                
                // Start listener for each conversation
                for conversation in conversations {
                    guard let conversationId = conversation.id else { continue }
                    addMessageListenerForConversation(conversationId: conversationId)
                }
                
                // Also observe conversation changes to dynamically add/remove listeners
                observeConversationChangesForMessageListeners(userId: currentUserId)
                
                print("✅ Message listeners started for \(conversations.count) conversations")
            } catch {
                print("❌ Error starting message listeners: \(error.localizedDescription)")
            }
        }
    }
    
    /// Observe conversation changes to dynamically add/remove message listeners
    private func observeConversationChangesForMessageListeners(userId: String) {
        // Observe local database for conversation changes
        NotificationCenter.default
            .publisher(for: .localDatabaseDidChange)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.syncMessageListenersWithConversations(userId: userId)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Sync message listeners with current conversations
    private func syncMessageListenersWithConversations(userId: String) async {
        do {
            let conversations = try await conversationRepository.getConversations(userId: userId)
            let currentConversationIds = Set(conversations.compactMap { $0.id })
            let listeningConversationIds = Set(conversationMessageListeners.keys)
            
            // Add listeners for new conversations
            let newConversations = currentConversationIds.subtracting(listeningConversationIds)
            for conversationId in newConversations {
                addMessageListenerForConversation(conversationId: conversationId)
            }
            
            // Remove listeners for conversations user is no longer in
            let removedConversations = listeningConversationIds.subtracting(currentConversationIds)
            for conversationId in removedConversations {
                removeMessageListenerForConversation(conversationId: conversationId)
            }
        } catch {
            print("⚠️ Error syncing message listeners: \(error.localizedDescription)")
        }
    }
    
    /// Add a message listener for a specific conversation
    func addMessageListenerForConversation(conversationId: String) {
        // Skip if already listening
        guard conversationMessageListeners[conversationId] == nil else {
            return
        }
        
        print("📥 Adding message listener for conversation: \(conversationId)")
        
        let listener = firebaseService.db
            .collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        print("❌ Message listener error for \(conversationId): \(error.localizedDescription)")
                        self.handleListenerError(error, listenerName: "Message Listener (\(conversationId))")
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ Message snapshot is nil for \(conversationId)")
                    return
                }
                
                // Process document changes
                Task { @MainActor in
                    await self.processMessageChanges(snapshot.documentChanges)
                }
            }
        
        conversationMessageListeners[conversationId] = listener
        print("✅ Message listener added for conversation: \(conversationId)")
    }
    
    /// Remove a message listener for a specific conversation
    func removeMessageListenerForConversation(conversationId: String) {
        guard let listener = conversationMessageListeners[conversationId] else {
            return
        }
        
        print("🧹 Removing message listener for conversation: \(conversationId)")
        listener.remove()
        conversationMessageListeners.removeValue(forKey: conversationId)
    }
    
    /// Process message document changes from Firestore
    private func processMessageChanges(_ changes: [DocumentChange]) async {
        for change in changes {
            do {
                let message = try change.document.data(as: Message.self)
                
                switch change.type {
                case .added:
                    try await handleMessageAdded(message)
                case .modified:
                    try await handleMessageModified(message)
                case .removed:
                    try await handleMessageRemoved(message)
                }
            } catch {
                print("❌ Error processing message change: \(error.localizedDescription)")
            }
        }
    }
    
    /// Handle new message from Firestore
    internal func handleMessageAdded(_ message: Message) async throws {
        guard let messageId = message.id else {
            print("⚠️ Message has no ID, skipping")
            return
        }
        
        // Check if message already exists locally by Firestore ID
        let idPredicate = #Predicate<LocalMessage> { localMessage in
            localMessage.id == messageId
        }
        
        let existingById = try database.fetchOne(LocalMessage.self, where: idPredicate)
        
        // If found by ID, skip (already exists)
        if existingById != nil {
            // Silently skip if exists (reduces log noise)
            return
        }
        
        // Check if this is an optimistic message (by localId) that needs updating
        if let localId = message.localId {
            let localIdPredicate = #Predicate<LocalMessage> { localMessage in
                localMessage.localId == localId
            }
            
            if let existingByLocalId = try database.fetchOne(LocalMessage.self, where: localIdPredicate) {
                // Found optimistic message - update it with Firestore ID instead of inserting duplicate
                print("🔄 Updating optimistic message with Firestore ID: \(messageId)")
                existingByLocalId.id = messageId
                existingByLocalId.syncStatus = .synced
                existingByLocalId.serverTimestamp = message.timestamp
                existingByLocalId.statusRaw = message.status.rawValue
                existingByLocalId.readBy = message.readBy
                existingByLocalId.deliveredTo = message.deliveredTo
                existingByLocalId.updatedAt = Date()
                try database.save()
                
                // Notify observers of changes
                database.notifyChanges()
                return
            }
        }
        
        // New message from another user - insert into local database
        let localMessage = LocalMessage.from(message, syncStatus: .synced)
        try database.insert(localMessage)
        try database.save()
        
        // Reduced logging - only in debug mode
        #if DEBUG
        print("✅ Message added: \(messageId)")
        #endif
        
        // Notify observers of changes
        database.notifyChanges()
    }
    
    /// Handle modified message from Firestore (conflict resolution)
    internal func handleMessageModified(_ message: Message) async throws {
        guard let messageId = message.id else {
            print("⚠️ Message has no ID, skipping")
            return
        }
        
        print("📥 [PULL] handleMessageModified called for: \(messageId)")
        print("📥 [PULL] Remote readBy: \(message.readBy), status: \(message.status)")
        
        // Fetch local version
        let predicate = #Predicate<LocalMessage> { localMessage in
            localMessage.id == messageId
        }
        
        guard let localMessage = try database.fetchOne(LocalMessage.self, where: predicate) else {
            print("📥 [PULL] Message not found locally, treating as new")
            // Message doesn't exist locally - treat as new
            try await handleMessageAdded(message)
            return
        }
        
        print("📥 [PULL] Local readBy: \(localMessage.readBy), status: \(localMessage.status), syncStatus: \(localMessage.syncStatus)")
        
        // Skip processing if local message is already synced and timestamps match
        // This prevents unnecessary DB operations when the pull listener receives
        // a message that we just pushed (avoiding the push→pull→update cycle)
        // UNLESS readBy/deliveredTo arrays OR status have changed (read receipts)
        if localMessage.syncStatus == .synced && 
           abs(localMessage.timestamp.timeIntervalSince(message.timestamp)) < 1.0 {
            // Check if read receipts, delivery status, or message status changed
            let readByChanged = Set(localMessage.readBy) != Set(message.readBy)
            let deliveredToChanged = Set(localMessage.deliveredTo) != Set(message.deliveredTo)
            let statusChanged = localMessage.status != message.status
            
            print("📥 [PULL] Early exit check - synced: true, timestamps match: true")
            print("📥 [PULL] readByChanged: \(readByChanged), deliveredToChanged: \(deliveredToChanged), statusChanged: \(statusChanged)")
            
            if !readByChanged && !deliveredToChanged && !statusChanged {
                // No status changes - skip processing
                print("📥 [PULL] No changes detected - skipping processing")
                return
            }
            // Status changed - continue processing to update readBy/deliveredTo/status
            print("📥 [PULL] Status fields changed - continuing to process update")
        }
        
        // Resolve conflict using ConflictResolver
        let resolution = conflictResolver.resolveMessage(local: localMessage, remote: message)
        
        print("📥 [PULL] Conflict resolution result: \(resolution.isLocalWinner ? "local wins" : "remote wins")")
        
        // Update sync status and fields based on resolution
        if resolution.isLocalWinner {
            // Local version won - mark as pending to sync back
            localMessage.syncStatus = .pending
            print("📥 [PULL] Local wins - marking as pending to sync back")
        } else {
            // Remote version won - update ALL fields from remote
            print("📥 [PULL] Remote wins - updating local with remote data")
            print("📥 [PULL] Updating readBy: \(localMessage.readBy) → \(message.readBy)")
            print("📥 [PULL] Updating status: \(localMessage.status) → \(message.status)")
            
            localMessage.text = message.text
            localMessage.senderName = message.senderName
            localMessage.senderId = message.senderId
            localMessage.conversationId = message.conversationId
            localMessage.statusRaw = message.status.rawValue
            localMessage.readBy = message.readBy
            localMessage.deliveredTo = message.deliveredTo
            localMessage.timestamp = message.timestamp
            localMessage.serverTimestamp = message.timestamp
            localMessage.syncStatus = .synced
            localMessage.updatedAt = Date()
            
            print("📥 [PULL] Local now has - readBy: \(localMessage.readBy), status: \(localMessage.status)")
        }
        
        try database.save()
        print("📥 [PULL] Database saved")
        
        // Notify observers of changes
        database.notifyChanges()
        print("📥 [PULL] Changes notified - UI should update")
    }
    
    /// Handle deleted message from Firestore
    internal func handleMessageRemoved(_ message: Message) async throws {
        guard let messageId = message.id else {
            print("⚠️ Message has no ID, skipping")
            return
        }
        
        // Fetch local version
        let predicate = #Predicate<LocalMessage> { localMessage in
            localMessage.id == messageId
        }
        
        if let localMessage = try database.fetchOne(LocalMessage.self, where: predicate) {
            try database.delete(localMessage)
            try database.save()
            print("🗑️ Message deleted: \(messageId)")
            
            // Notify observers of changes
            database.notifyChanges()
        } else {
            print("ℹ️ Message not found locally: \(messageId)")
        }
    }
    
    // MARK: - Pull Sync - Conversation Listener
    
    /// Start listening to Firestore conversations for real-time pull sync
    private func startConversationListener() {
        guard let currentUserId = firebaseService.currentUserId else {
            print("⚠️ Cannot start conversation listener: No authenticated user")
            return
        }
        
        print("📥 Starting conversation listener for user: \(currentUserId)...")
        
        // Listen to conversations where the current user is a participant
        conversationListener = firebaseService.db
            .collection(Constants.Collections.conversations)
            .whereField("participantIds", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.handleListenerError(error, listenerName: "Conversation Listener")
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ Conversation snapshot is nil")
                    return
                }
                
                // Process document changes
                Task { @MainActor in
                    await self.processConversationChanges(snapshot.documentChanges)
                }
            }
        
        print("✅ Conversation listener started")
    }
    
    /// Process conversation document changes from Firestore
    private func processConversationChanges(_ changes: [DocumentChange]) async {
        for change in changes {
            do {
                let conversation = try change.document.data(as: Conversation.self)
                
                switch change.type {
                case .added:
                    try await handleConversationAdded(conversation)
                case .modified:
                    try await handleConversationModified(conversation)
                case .removed:
                    try await handleConversationRemoved(conversation)
                }
            } catch {
                print("❌ Error processing conversation change: \(error.localizedDescription)")
            }
        }
    }
    
    /// Handle new conversation from Firestore
    internal func handleConversationAdded(_ conversation: Conversation) async throws {
        guard let conversationId = conversation.id else {
            print("⚠️ Conversation has no ID, skipping")
            return
        }
        
        // Check if conversation already exists locally
        let predicate = #Predicate<LocalConversation> { localConversation in
            localConversation.id == conversationId
        }
        
        let existing = try database.fetchOne(LocalConversation.self, where: predicate)
        
        if existing == nil {
            // New conversation - insert into local database
            let localConversation = LocalConversation.from(conversation, syncStatus: .synced)
            try database.insert(localConversation)
            try database.save()
            print("✅ Conversation added: \(conversationId)")
            
            // Notify observers of changes
            database.notifyChanges()
        } else {
            print("ℹ️ Conversation already exists: \(conversationId)")
        }
    }
    
    /// Handle modified conversation from Firestore (conflict resolution)
    internal func handleConversationModified(_ conversation: Conversation) async throws {
        guard let conversationId = conversation.id else {
            print("⚠️ Conversation has no ID, skipping")
            return
        }
        
        // Fetch local version
        let predicate = #Predicate<LocalConversation> { localConversation in
            localConversation.id == conversationId
        }
        
        guard let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) else {
            // Conversation doesn't exist locally - treat as new
            try await handleConversationAdded(conversation)
            return
        }
        
        // Skip processing if local conversation is already synced and timestamps match
        // This prevents unnecessary DB operations when the pull listener receives
        // a conversation that we just pushed (avoiding the push→pull→update cycle)
        let remoteUpdatedAt = conversation.updatedAt ?? conversation.createdAt
        if localConversation.syncStatus == .synced && 
           abs(localConversation.updatedAt.timeIntervalSince(remoteUpdatedAt)) < 1.0 {
            // Local version is already synced and up-to-date - skip processing
            return
        }
        
        // Resolve conflict using ConflictResolver
        let resolution = conflictResolver.resolveConversation(local: localConversation, remote: conversation)
        
        // Update sync status and fields based on resolution
        if resolution.isLocalWinner {
            // Local version won - mark as pending to sync back
            localConversation.syncStatus = .pending
            print("🔄 Conversation conflict resolved (local wins): \(conversationId)")
        } else {
            // Remote version won - update ALL fields from remote
            localConversation.typeRaw = conversation.type.rawValue
            localConversation.participantIds = conversation.participantIds
            localConversation.participants = conversation.participants
            localConversation.groupName = conversation.groupName
            localConversation.groupImageUrl = conversation.groupImageUrl
            localConversation.createdBy = conversation.createdBy
            localConversation.lastMessage = conversation.lastMessage
            localConversation.updatedAt = conversation.updatedAt ?? conversation.createdAt
            localConversation.serverTimestamp = conversation.updatedAt ?? conversation.createdAt
            localConversation.syncStatus = .synced
            print("🔄 Conversation conflict resolved (remote wins): \(conversationId)")
        }
        
        try database.save()
        
        // Notify observers of changes
        database.notifyChanges()
    }
    
    /// Handle deleted conversation from Firestore
    internal func handleConversationRemoved(_ conversation: Conversation) async throws {
        guard let conversationId = conversation.id else {
            print("⚠️ Conversation has no ID, skipping")
            return
        }
        
        // Fetch local version
        let predicate = #Predicate<LocalConversation> { localConversation in
            localConversation.id == conversationId
        }
        
        if let localConversation = try database.fetchOne(LocalConversation.self, where: predicate) {
            try database.delete(localConversation)
            try database.save()
            print("🗑️ Conversation deleted: \(conversationId)")
            
            // Notify observers of changes
            database.notifyChanges()
        } else {
            print("ℹ️ Conversation not found locally: \(conversationId)")
        }
    }
    
    // MARK: - Pull Sync - User Listener
    
    /// Start listening to Firestore users for real-time pull sync (presence updates)
    private func startUserListener() {
        print("📥 Starting user listener...")
        
        // Listen to all users for presence updates
        // In production, you might want to limit this to contacts/recent conversation participants
        userListener = firebaseService.db
            .collection(Constants.Collections.users)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.handleListenerError(error, listenerName: "User Listener")
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ User snapshot is nil")
                    return
                }
                
                // Process document changes
                Task { @MainActor in
                    await self.processUserChanges(snapshot.documentChanges)
                }
            }
        
        print("✅ User listener started")
    }
    
    /// Process user document changes from Firestore
    private func processUserChanges(_ changes: [DocumentChange]) async {
        for change in changes {
            do {
                let user = try change.document.data(as: User.self)
                
                switch change.type {
                case .added:
                    try await handleUserAdded(user)
                case .modified:
                    try await handleUserModified(user)
                case .removed:
                    try await handleUserRemoved(user)
                }
            } catch {
                print("❌ Error processing user change: \(error.localizedDescription)")
            }
        }
    }
    
    /// Handle new user from Firestore
    internal func handleUserAdded(_ user: User) async throws {
        guard let userId = user.id else {
            print("⚠️ User has no ID, skipping")
            return
        }
        
        // Check if user already exists locally
        let predicate = #Predicate<LocalUser> { localUser in
            localUser.id == userId
        }
        
        let existing = try database.fetchOne(LocalUser.self, where: predicate)
        
        if existing == nil {
            // New user - insert into local database
            let localUser = LocalUser.from(user, syncStatus: .synced)
            try database.insert(localUser)
            try database.save()
            print("✅ User added: \(userId)")
            
            // Notify observers of changes
            database.notifyChanges()
        } else {
            print("ℹ️ User already exists: \(userId)")
        }
    }
    
    /// Handle modified user from Firestore (presence always from server)
    internal func handleUserModified(_ user: User) async throws {
        guard let userId = user.id else {
            print("⚠️ User has no ID, skipping")
            return
        }
        
        // Fetch local version
        let predicate = #Predicate<LocalUser> { localUser in
            localUser.id == userId
        }
        
        guard let localUser = try database.fetchOne(LocalUser.self, where: predicate) else {
            // User doesn't exist locally - treat as new
            try await handleUserAdded(user)
            return
        }
        
        // Skip processing if local user is already synced and timestamps match
        // Exception: Always update presence (isOnline, lastSeen) even if synced
        // This prevents unnecessary DB operations for profile updates we just pushed
        if localUser.syncStatus == .synced && 
           abs(localUser.lastSeen.timeIntervalSince(user.lastSeen)) < 1.0 &&
           localUser.isOnline == user.isOnline {
            // Local version is already synced, up-to-date, and presence matches - skip processing
            return
        }
        
        // Resolve conflict using ConflictResolver
        let resolution = conflictResolver.resolveUser(local: localUser, remote: user)
        
        // Update sync status and fields based on resolution
        if resolution.isLocalWinner {
            // Local profile won, but always use remote presence
            localUser.isOnline = user.isOnline
            localUser.lastSeen = user.lastSeen
            localUser.syncStatus = .pending // Profile needs sync back
            print("🔄 User conflict resolved (local profile wins, remote presence): \(userId)")
        } else {
            // Remote version won - update ALL fields from remote
            localUser.displayName = user.displayName
            localUser.email = user.email
            localUser.profileImageUrl = user.profileImageUrl
            localUser.isOnline = user.isOnline
            localUser.lastSeen = user.lastSeen
            localUser.serverTimestamp = user.createdAt
            localUser.syncStatus = .synced
            localUser.updatedAt = Date()
            print("🔄 User conflict resolved (remote wins): \(userId)")
        }
        
        try database.save()
        
        // Notify observers of changes
        database.notifyChanges()
    }
    
    /// Handle deleted user from Firestore
    internal func handleUserRemoved(_ user: User) async throws {
        guard let userId = user.id else {
            print("⚠️ User has no ID, skipping")
            return
        }
        
        // Fetch local version
        let predicate = #Predicate<LocalUser> { localUser in
            localUser.id == userId
        }
        
        if let localUser = try database.fetchOne(LocalUser.self, where: predicate) {
            try database.delete(localUser)
            try database.save()
            print("🗑️ User deleted: \(userId)")
            
            // Notify observers of changes
            database.notifyChanges()
        } else {
            print("ℹ️ User not found locally: \(userId)")
        }
    }
    
    // MARK: - Error Handling
    
    /// Track retry attempts for each listener
    private var messageListenerRetryCount = 0
    private var conversationListenerRetryCount = 0
    private var userListenerRetryCount = 0
    
    private let maxRetryAttempts = 5
    private let initialRetryDelay: TimeInterval = 2.0 // seconds
    
    /// Handle Firestore listener errors with retry logic
    private func handleListenerError(_ error: Error, listenerName: String) {
        print("❌ \(listenerName) error: \(error.localizedDescription)")
        
        // Determine which listener failed and get retry count
        var retryCount = 0
        switch listenerName {
        case "Message Listener":
            messageListenerRetryCount += 1
            retryCount = messageListenerRetryCount
        case "Conversation Listener":
            conversationListenerRetryCount += 1
            retryCount = conversationListenerRetryCount
        case "User Listener":
            userListenerRetryCount += 1
            retryCount = userListenerRetryCount
        default:
            break
        }
        
        // Check if we've exceeded max retries
        guard retryCount <= maxRetryAttempts else {
            print("🚫 \(listenerName) exceeded max retry attempts (\(maxRetryAttempts))")
            // In production: Alert user, log to analytics, etc.
            return
        }
        
        // Calculate exponential backoff delay: 2s, 4s, 8s, 16s, 32s
        let retryDelay = initialRetryDelay * pow(2.0, Double(retryCount - 1))
        print("🔄 \(listenerName) will retry in \(retryDelay) seconds (attempt \(retryCount)/\(maxRetryAttempts))")
        
        // Schedule retry
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            
            // Restart the appropriate listener
            switch listenerName {
            case "Message Listener":
                self.startMessageListener()
            case "Conversation Listener":
                self.startConversationListener()
            case "User Listener":
                self.startUserListener()
            default:
                break
            }
        }
    }
    
    /// Reset retry counters (call when listeners successfully reconnect)
    private func resetRetryCounters() {
        messageListenerRetryCount = 0
        conversationListenerRetryCount = 0
        userListenerRetryCount = 0
        print("✅ Retry counters reset")
    }
    
    // MARK: - Push Sync - Message
    
    /// Sync a pending message to Firestore
    /// - Parameter localMessage: The local message to sync
    /// - Returns: True if sync succeeded, false otherwise
    @discardableResult
    internal func syncMessage(_ localMessage: LocalMessage) async -> Bool {
        guard localMessage.syncStatus != .synced else {
            print("ℹ️ Message already synced: \(localMessage.id)")
            return true
        }
        
        // Check exponential backoff
        if !shouldRetrySync(
            status: localMessage.syncStatus,
            retryCount: localMessage.syncRetryCount,
            lastAttempt: localMessage.lastSyncAttempt
        ) {
            print("⏳ Message sync delayed by backoff: \(localMessage.id)")
            return false
        }
        
        do {
            print("📤 [SYNC_MSG] Starting sync for message: \(localMessage.id)")
            print("📤 [SYNC_MSG] readBy: \(localMessage.readBy), deliveredTo: \(localMessage.deliveredTo)")
            print("📤 [SYNC_MSG] status: \(localMessage.status), syncStatus: \(localMessage.syncStatus)")
            
            // Get conversation to retrieve participant IDs
            let conversationRef = firebaseService.db
                .collection(Constants.Collections.conversations)
                .document(localMessage.conversationId)
            let conversationDoc = try await conversationRef.getDocument()
            guard let participantIds = conversationDoc.data()?["participantIds"] as? [String] else {
                throw NSError(domain: "SyncEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get participant IDs"])
            }
            
            // Check if message already has Firestore ID (updating existing)
            let docRef: DocumentReference
            if localMessage.id != localMessage.localId {
                // Message has Firestore ID - update existing document
                // Use arrayUnion for readBy/deliveredTo to prevent race conditions
                docRef = firebaseService.db
                    .collection(Constants.Collections.conversations)
                    .document(localMessage.conversationId)
                    .collection(Constants.Collections.messages)
                    .document(localMessage.id)
                
                var updateData: [String: Any] = [:]
                
                // Use arrayUnion to merge arrays instead of overwriting
                if !localMessage.readBy.isEmpty {
                    updateData["readBy"] = FieldValue.arrayUnion(localMessage.readBy)
                    print("📤 [SYNC_MSG] Adding readBy: \(localMessage.readBy)")
                }
                if !localMessage.deliveredTo.isEmpty {
                    updateData["deliveredTo"] = FieldValue.arrayUnion(localMessage.deliveredTo)
                    print("📤 [SYNC_MSG] Adding deliveredTo: \(localMessage.deliveredTo)")
                }
                
                // Determine status based on readBy/deliveredTo arrays
                // If anyone other than sender has read it, status is .read
                if localMessage.readBy.contains(where: { $0 != localMessage.senderId }) {
                    updateData["status"] = MessageStatus.read.rawValue
                    print("📤 [SYNC_MSG] Setting status to .read")
                } else if localMessage.deliveredTo.contains(where: { $0 != localMessage.senderId }) {
                    updateData["status"] = MessageStatus.delivered.rawValue
                    print("📤 [SYNC_MSG] Setting status to .delivered")
                } else {
                    updateData["status"] = MessageStatus.sent.rawValue
                    print("📤 [SYNC_MSG] Setting status to .sent")
                }
                
                print("📤 [SYNC_MSG] Updating Firestore with data: \(updateData)")
                try await docRef.updateData(updateData)
                print("📤 [SYNC_MSG] Firestore update successful")
            } else {
                // New message - create document with full data
                let messageData: [String: Any] = [
                    "conversationId": localMessage.conversationId,
                    "senderId": localMessage.senderId,
                    "senderName": localMessage.senderName,
                    "text": localMessage.text,
                    "timestamp": Timestamp(date: localMessage.timestamp),
                    "status": MessageStatus.delivered.rawValue,
                    "readBy": localMessage.readBy,
                    "deliveredTo": localMessage.deliveredTo.isEmpty ? participantIds : localMessage.deliveredTo,
                    "localId": localMessage.localId
                ]
                
                docRef = try await firebaseService.db
                    .collection(Constants.Collections.conversations)
                    .document(localMessage.conversationId)
                    .collection(Constants.Collections.messages)
                    .addDocument(data: messageData)
                
                // Update local message with Firestore ID
                localMessage.id = docRef.documentID
            }
            
            // Mark as synced
            localMessage.syncStatus = .synced
            localMessage.lastSyncAttempt = Date()
            localMessage.syncRetryCount = 0
            localMessage.serverTimestamp = Date()
            try database.save()
            
            // Update conversation's last message
            let message = localMessage.toMessage()
            try? await conversationRepository.updateLastMessage(
                conversationId: localMessage.conversationId,
                message: message
            )
            
            // Reduce log verbosity - only log ID
            print("✅ Synced: \(localMessage.id)")
            return true
            
        } catch {
            print("❌ Failed to sync message: \(error.localizedDescription)")
            
            // Mark as failed and increment retry count
            localMessage.syncStatus = .failed
            localMessage.lastSyncAttempt = Date()
            localMessage.syncRetryCount += 1
            try? database.save()
            
            return false
        }
    }
    
    // MARK: - Push Sync - Conversation
    
    /// Sync a pending conversation to Firestore
    /// - Parameter localConversation: The local conversation to sync
    /// - Returns: True if sync succeeded, false otherwise
    @discardableResult
    internal func syncConversation(_ localConversation: LocalConversation) async -> Bool {
        guard localConversation.syncStatus != .synced else {
            print("ℹ️ Conversation already synced: \(localConversation.id)")
            return true
        }
        
        // Check exponential backoff
        if !shouldRetrySync(
            status: localConversation.syncStatus,
            retryCount: localConversation.syncRetryCount,
            lastAttempt: localConversation.lastSyncAttempt
        ) {
            print("⏳ Conversation sync delayed by backoff: \(localConversation.id)")
            return false
        }
        
        do {
            print("📤 Syncing conversation: \(localConversation.id)")
            
            // Create conversation data
            // Convert participants dictionary to Firestore-compatible format
            var participantsData: [String: [String: Any]] = [:]
            for (userId, participantInfo) in localConversation.participants {
                participantsData[userId] = [
                    "displayName": participantInfo.displayName,
                    "profileImageUrl": participantInfo.profileImageUrl as Any
                ]
            }
            
            var conversationData: [String: Any] = [
                "type": localConversation.typeRaw,
                "participantIds": localConversation.participantIds,
                "participants": participantsData,
                "createdBy": localConversation.createdBy ?? "",
                "createdAt": Timestamp(date: localConversation.createdAt),
                "updatedAt": Timestamp(date: localConversation.updatedAt)
            ]
            
            // Add optional fields
            if let groupName = localConversation.groupName {
                conversationData["groupName"] = groupName
            }
            if let groupImageUrl = localConversation.groupImageUrl {
                conversationData["groupImageUrl"] = groupImageUrl
            }
            if let lastMessage = localConversation.lastMessage {
                conversationData["lastMessage"] = [
                    "text": lastMessage.text,
                    "senderId": lastMessage.senderId,
                    "senderName": lastMessage.senderName,
                    "timestamp": Timestamp(date: lastMessage.timestamp)
                ] as [String: Any]
            }
            
            // Update Firestore
            let docRef = firebaseService.db
                .collection(Constants.Collections.conversations)
                .document(localConversation.id)
            try await docRef.setData(conversationData, merge: true)
            
            // Mark as synced
            localConversation.syncStatus = .synced
            localConversation.lastSyncAttempt = Date()
            localConversation.syncRetryCount = 0
            localConversation.serverTimestamp = Date()
            try database.save()
            
            print("✅ Conversation synced successfully: \(localConversation.id)")
            return true
            
        } catch {
            print("❌ Failed to sync conversation: \(error.localizedDescription)")
            
            // Mark as failed and increment retry count
            localConversation.syncStatus = .failed
            localConversation.lastSyncAttempt = Date()
            localConversation.syncRetryCount += 1
            try? database.save()
            
            return false
        }
    }
    
    // MARK: - Push Sync - User
    
    /// Sync a pending user profile to Firestore
    /// - Parameter localUser: The local user to sync
    /// - Returns: True if sync succeeded, false otherwise
    @discardableResult
    internal func syncUser(_ localUser: LocalUser) async -> Bool {
        guard localUser.syncStatus != .synced else {
            print("ℹ️ User already synced: \(localUser.id)")
            return true
        }
        
        // Check exponential backoff
        if !shouldRetrySync(
            status: localUser.syncStatus,
            retryCount: localUser.syncRetryCount,
            lastAttempt: localUser.lastSyncAttempt
        ) {
            print("⏳ User sync delayed by backoff: \(localUser.id)")
            return false
        }
        
        do {
            print("📤 Syncing user: \(localUser.id)")
            
            // Create user data (only sync profile fields, not presence)
            var userData: [String: Any] = [
                "googleId": localUser.googleId,
                "email": localUser.email,
                "displayName": localUser.displayName,
                "profileImageUrl": localUser.profileImageUrl ?? "",
                "createdAt": Timestamp(date: localUser.createdAt)
                // Note: Do NOT sync isOnline/lastSeen - those are server-managed
            ]
            
            // Include avatar color if available (for cross-device consistency)
            if let avatarColorHex = localUser.avatarColorHex, !avatarColorHex.isEmpty {
                userData["avatarColorHex"] = avatarColorHex
            }
            
            // Update Firestore
            let docRef = firebaseService.db
                .collection(Constants.Collections.users)
                .document(localUser.id)
            try await docRef.setData(userData, merge: true)
            
            // Mark as synced
            localUser.syncStatus = .synced
            localUser.lastSyncAttempt = Date()
            localUser.syncRetryCount = 0
            localUser.serverTimestamp = Date()
            try database.save()
            
            print("✅ User synced successfully: \(localUser.id)")
            return true
            
        } catch {
            print("❌ Failed to sync user: \(error.localizedDescription)")
            
            // Mark as failed and increment retry count
            localUser.syncStatus = .failed
            localUser.lastSyncAttempt = Date()
            localUser.syncRetryCount += 1
            try? database.save()
            
            return false
        }
    }
    
    // MARK: - Retry Logic
    
    /// Calculate exponential backoff delay: 1s, 2s, 4s, 8s, 16s
    internal func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0 // 1 second
        let maxDelay: TimeInterval = 16.0 // 16 seconds max
        let delay = baseDelay * pow(2.0, Double(retryCount))
        return min(delay, maxDelay)
    }
    
    /// Check if entity should retry sync based on exponential backoff
    internal func shouldRetrySync(
        status: SyncStatus,
        retryCount: Int,
        lastAttempt: Date?
    ) -> Bool {
        // Always allow pending entities on first attempt
        guard status == .failed, let lastAttempt = lastAttempt else {
            return true
        }
        
        // Max 5 retries
        guard retryCount < 5 else {
            return false
        }
        
        // Check if enough time has passed based on backoff
        let backoffDelay = calculateBackoffDelay(retryCount: retryCount)
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        
        return timeSinceLastAttempt >= backoffDelay
    }
}

