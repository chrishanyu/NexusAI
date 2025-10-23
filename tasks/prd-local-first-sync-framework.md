# PRD: Local-First Sync Framework

**Created:** October 22, 2025  
**Status:** Planning  
**Priority:** High - Foundation for better architecture and debugging

---

## Executive Summary

Build a local-first sync framework that establishes **SwiftData as the single source of truth** for the application, with a robust bidirectional sync engine that keeps Firestore in sync. This architectural shift improves debugging capabilities, data consistency, and provides a clearer data flow throughout the application.

### Key Insight
This is NOT primarily about offline capabilities - it's about **architectural clarity**. By making local storage the single source of truth, we eliminate the ambiguity of "where is this data?" and "which value is correct?" that causes bugs in the current dual-source architecture.

---

## Problem Statement

### Current Architecture Issues

**Dual Source of Truth:**
```
Current (Confusing):
    ViewModel reads from Firestore listener
         ↓
    ViewModel also reads from SwiftData cache
         ↓
    Which one is correct? Depends on timing, network, cache state
         ↓
    Bugs happen when these get out of sync
```

**Problems:**
1. **Debugging is hard:** "Did this bug happen because Firestore had stale data, or SwiftData had stale data?"
2. **Inconsistent data flow:** Sometimes data comes from cache, sometimes from Firestore
3. **Manual cache management:** Each ViewModel explicitly caches, easy to forget or do wrong
4. **No guarantees:** Cache can be arbitrarily stale with no way to know
5. **Race conditions:** Listener updates and cache updates can conflict

### Desired Architecture

**Single Source of Truth:**
```
New (Clear):
    ViewModel reads from Repository
         ↓
    Repository ALWAYS reads from SwiftData (local DB)
         ↓
    Sync Engine keeps Firestore in sync (background)
         ↓
    Single source of truth = easier debugging
```

**Benefits:**
1. **Predictable data flow:** All reads from local DB, all writes go through Repository
2. **Better debugging:** "Bug = check local DB state" (one place to look)
3. **Automatic caching:** Sync engine handles it, ViewModels don't worry
4. **Consistency guarantees:** Local DB is always internally consistent
5. **Easier testing:** Mock Repository, don't need Firestore in tests

---

## Goals & Non-Goals

### Goals
1. ✅ **Single Source of Truth:** SwiftData is the authoritative data source
2. ✅ **Repository Pattern:** Clean interface between ViewModels and data layer
3. ✅ **Bidirectional Sync:** Local changes sync to Firestore, Firestore changes sync to local
4. ✅ **Conflict Resolution:** Last-Write-Wins with server timestamp
5. ✅ **Better Debugging:** Clear data flow, easy to inspect local DB state
6. ✅ **Maintain Real-Time:** Keep Firestore listeners for instant updates
7. ✅ **Brief Offline Support:** Works for minutes without network (bonus, not primary goal)

### Non-Goals
1. ❌ Extended offline support (hours/days) - not needed for AI features
2. ❌ Large cache sizes - conservative approach (100MB)
3. ❌ Complex conflict resolution (CRDT, manual merge) - LWW is sufficient
4. ❌ Message editing - append-only log
5. ❌ Multi-device sync optimization - basic sync is enough for now
6. ❌ Migration from existing data - clean slate deployment

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  ChatView    │  │ConversationList│ │   Other Views   │  │
│  │              │  │     View      │  │                  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↕ @Published
┌─────────────────────────────────────────────────────────────┐
│                      VIEW MODEL LAYER                        │
│                                                               │
│  ┌──────────────┐  ┌────────────────────┐                   │
│  │ChatViewModel │  │ConversationList    │                   │
│  │              │  │   ViewModel        │                   │
│  └──────────────┘  └────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
                            ↕ Repository Protocol
┌─────────────────────────────────────────────────────────────┐
│                    REPOSITORY LAYER (NEW)                    │
│                                                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │Message          │  │Conversation     │  │User         │ │
│  │Repository       │  │Repository       │  │Repository   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                               │
│  Protocol-based, mockable, single entry point per model     │
└─────────────────────────────────────────────────────────────┘
            ↕ Read/Write                    ↕ Sync Operations
┌──────────────────────┐              ┌─────────────────────────┐
│   LOCAL DATABASE     │              │    SYNC ENGINE (NEW)    │
│   (SwiftData)        │              │                         │
│                      │              │  ┌──────────────────┐  │
│  ✓ Single Source     │←─────────────┤  │  Sync Worker     │  │
│    of Truth          │              │  └──────────────────┘  │
│  ✓ Fast Queries      │              │  ┌──────────────────┐  │
│  ✓ Consistent State  │              │  │  Conflict        │  │
│                      │              │  │  Resolver        │  │
│                      │              │  └──────────────────┘  │
└──────────────────────┘              └─────────────────────────┘
                                                  ↕
                                    ┌─────────────────────────┐
                                    │   FIRESTORE (Backend)   │
                                    │                         │
                                    │  ✓ Real-time Listeners  │
                                    │  ✓ Cloud backup         │
                                    │  ✓ Multi-device sync    │
                                    └─────────────────────────┘
```

### Data Flow: Read Operations

```
User opens ChatView
    ↓
ChatViewModel.init()
    ↓
messageRepository.observeMessages(conversationId)
    ↓
Repository queries SwiftData (local DB)
    ↓
Return AsyncStream<[Message]> from local DB
    ↓
ViewModel updates @Published var messages
    ↓
SwiftUI renders instantly (no network wait)

In Background:
    Sync Engine listens to Firestore
    ↓
    New message arrives from Firestore
    ↓
    Sync Engine writes to SwiftData
    ↓
    SwiftData triggers AsyncStream update
    ↓
    ViewModel receives update
    ↓
    SwiftUI re-renders
```

**Key Insight:** ViewModels NEVER directly access Firestore. They only talk to Repository, which only talks to SwiftData.

### Data Flow: Write Operations

```
User sends message
    ↓
ChatViewModel.sendMessage(text)
    ↓
messageRepository.createMessage(message)
    ↓
Repository writes to SwiftData FIRST (optimistic)
    ↓
Return immediately to ViewModel
    ↓
UI updates instantly with "sending" status

In Background:
    Sync Engine detects new local write
    ↓
    Sync Engine pushes to Firestore
    ↓
    On success: Update message status to "sent"
    ↓
    On failure: Mark as "failed", retry later
    ↓
    SwiftData update triggers AsyncStream
    ↓
    ViewModel sees status change
    ↓
    UI shows checkmark
```

**Key Insight:** Write to local DB first, sync to Firestore asynchronously. User never waits for network.

---

## Data Models

### SwiftData Models (Local Database)

#### LocalMessage
```swift
@Model
final class LocalMessage {
    // Identity
    @Attribute(.unique) var id: String              // Firestore ID or local UUID
    var localId: String                              // Local UUID for optimistic updates
    
    // Content
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    
    // Sync State
    var syncStatus: String                           // "synced", "pending", "failed"
    var lastSyncAttempt: Date?
    var syncRetryCount: Int = 0
    
    // Status
    var statusRaw: String                            // MessageStatus enum
    var readBy: [String]
    var deliveredTo: [String]
    
    // Metadata
    var createdAt: Date                              // Local creation time
    var updatedAt: Date                              // Last local update
    var serverTimestamp: Date?                       // Server timestamp (for conflict resolution)
    
    // Relationships
    @Relationship(deleteRule: .nullify) var conversation: LocalConversation?
    
    // Methods
    func toMessage() -> Message { ... }
    static func from(_ message: Message) -> LocalMessage { ... }
}
```

#### LocalConversation
```swift
@Model
final class LocalConversation {
    // Identity
    @Attribute(.unique) var id: String
    
    // Content
    var typeRaw: String                              // "direct" or "group"
    var participantIds: [String]
    var participantsData: Data                       // Encoded [String: ParticipantInfo]
    var groupName: String?
    var groupImageUrl: String?
    var createdBy: String?
    
    // Last Message (denormalized for performance)
    var lastMessageText: String?
    var lastMessageSenderId: String?
    var lastMessageSenderName: String?
    var lastMessageTimestamp: Date?
    
    // Sync State
    var syncStatus: String
    var lastSyncAttempt: Date?
    var serverTimestamp: Date?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \LocalMessage.conversation)
    var messages: [LocalMessage]?
    
    // Methods
    func toConversation() -> Conversation { ... }
    static func from(_ conversation: Conversation) -> LocalConversation { ... }
}
```

#### LocalUser
```swift
@Model
final class LocalUser {
    // Identity
    @Attribute(.unique) var id: String               // Firebase Auth UID
    
    // Profile
    var email: String
    var displayName: String
    var profileImageUrl: String?
    
    // Presence
    var isOnline: Bool
    var lastSeen: Date?
    
    // Sync State
    var syncStatus: String
    var lastSyncAttempt: Date?
    var serverTimestamp: Date?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // Methods
    func toUser() -> User { ... }
    static func from(_ user: User) -> LocalUser { ... }
}
```

### Sync Status Enum

```swift
enum SyncStatus: String, Codable {
    case synced         // Local matches server
    case pending        // Local write waiting to sync to server
    case failed         // Sync attempt failed, will retry
    case conflict       // Conflict detected (rare with LWW)
}
```

---

## Repository Pattern

### Protocol Definition

```swift
// Generic repository protocol
protocol Repository {
    associatedtype Entity
    associatedtype ID
    
    // Reactive observation
    func observe() -> AsyncStream<[Entity]>
    func observe(id: ID) -> AsyncStream<Entity?>
    
    // CRUD operations
    func create(_ entity: Entity) async throws -> Entity
    func read(id: ID) async throws -> Entity?
    func readAll() async throws -> [Entity]
    func update(_ entity: Entity) async throws
    func delete(id: ID) async throws
}

// Message-specific repository
protocol MessageRepositoryProtocol: Repository where Entity == Message, ID == String {
    // Message-specific queries
    func observeMessages(conversationId: String) -> AsyncStream<[Message]>
    func getMessages(conversationId: String, limit: Int) async throws -> [Message]
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int) async throws -> [Message]
    
    // Write operations
    func sendMessage(conversationId: String, text: String, senderId: String, senderName: String) async throws -> Message
    func markMessagesAsRead(messageIds: [String], userId: String) async throws
    func markMessagesAsDelivered(messageIds: [String], userId: String) async throws
}

// Conversation-specific repository
protocol ConversationRepositoryProtocol: Repository where Entity == Conversation, ID == String {
    func observeConversations(userId: String) -> AsyncStream<[Conversation]>
    func createDirectConversation(userId: String, otherUserId: String) async throws -> Conversation
    func createGroupConversation(creatorId: String, participantIds: [String], groupName: String?) async throws -> Conversation
    func updateLastMessage(conversationId: String, message: Message) async throws
}

// User-specific repository
protocol UserRepositoryProtocol: Repository where Entity == User, ID == String {
    func observeUser(userId: String) -> AsyncStream<User?>
    func updatePresence(userId: String, isOnline: Bool) async throws
    func updateProfile(userId: String, displayName: String?, profileImageUrl: String?) async throws
}
```

### Repository Implementation

```swift
@MainActor
class MessageRepository: MessageRepositoryProtocol {
    
    // Dependencies
    private let localDB: LocalDatabase              // SwiftData wrapper
    private let syncEngine: SyncEngine
    
    init(localDB: LocalDatabase, syncEngine: SyncEngine) {
        self.localDB = localDB
        self.syncEngine = syncEngine
    }
    
    // Observe messages for a conversation (reactive)
    func observeMessages(conversationId: String) -> AsyncStream<[Message]> {
        return AsyncStream { continuation in
            // Query SwiftData and observe changes
            let query = localDB.observeQuery(
                entity: LocalMessage.self,
                predicate: #Predicate { $0.conversationId == conversationId },
                sortBy: [SortDescriptor(\.timestamp)]
            )
            
            for await localMessages in query {
                let messages = localMessages.map { $0.toMessage() }
                continuation.yield(messages)
            }
        }
    }
    
    // Send message (write to local first, sync later)
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String
    ) async throws -> Message {
        // Create local message
        let localId = UUID().uuidString
        let message = Message(
            id: nil,                            // No Firestore ID yet
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            status: .sending,
            readBy: [senderId],
            deliveredTo: [],
            localId: localId
        )
        
        // Write to SwiftData FIRST
        let localMessage = LocalMessage.from(message)
        localMessage.syncStatus = SyncStatus.pending.rawValue
        try await localDB.insert(localMessage)
        
        // Trigger sync in background (fire and forget)
        Task.detached {
            await self.syncEngine.syncMessage(localId: localId)
        }
        
        // Return immediately (optimistic)
        return message
    }
    
    // Read operations always from local DB
    func getMessages(conversationId: String, limit: Int) async throws -> [Message] {
        let localMessages = try await localDB.fetch(
            entity: LocalMessage.self,
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.timestamp)],
            limit: limit
        )
        return localMessages.map { $0.toMessage() }
    }
}
```

---

## Sync Engine Design

### Sync Engine Components

```swift
@MainActor
class SyncEngine {
    
    // Dependencies
    private let localDB: LocalDatabase
    private let firebaseService: FirebaseService
    private let conflictResolver: ConflictResolver
    
    // State
    private var isSyncing: Bool = false
    private var syncQueue: [SyncOperation] = []
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Initialization
    
    func start() {
        // Start Firestore listeners for each collection
        startMessageListener()
        startConversationListener()
        startUserListener()
        
        // Start periodic sync worker
        startSyncWorker()
        
        // Observe network connectivity
        observeNetworkChanges()
    }
    
    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Pull Sync (Firestore → Local DB)
    
    private func startMessageListener() {
        let listener = firebaseService.db
            .collectionGroup("messages")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    await self.handleMessageSnapshot(snapshot, error)
                }
            }
        
        listeners.append(listener)
    }
    
    private func handleMessageSnapshot(_ snapshot: QuerySnapshot?, _ error: Error?) async {
        guard let snapshot = snapshot else { return }
        
        // Process each document change
        for change in snapshot.documentChanges {
            let firestoreMessage = try? change.document.data(as: Message.self)
            guard let firestoreMessage = firestoreMessage else { continue }
            
            switch change.type {
            case .added, .modified:
                // Check if we have this message locally
                let localMessage = try? await localDB.fetchOne(
                    entity: LocalMessage.self,
                    predicate: #Predicate { $0.id == firestoreMessage.id }
                )
                
                if let localMessage = localMessage {
                    // Message exists locally - check for conflicts
                    await handleMessageConflict(local: localMessage, remote: firestoreMessage)
                } else {
                    // New message from Firestore - insert to local DB
                    let newLocal = LocalMessage.from(firestoreMessage)
                    newLocal.syncStatus = SyncStatus.synced.rawValue
                    newLocal.serverTimestamp = firestoreMessage.timestamp
                    try? await localDB.insert(newLocal)
                }
                
            case .removed:
                // Delete from local DB
                try? await localDB.delete(
                    entity: LocalMessage.self,
                    predicate: #Predicate { $0.id == firestoreMessage.id }
                )
            }
        }
    }
    
    // MARK: - Push Sync (Local DB → Firestore)
    
    func syncMessage(localId: String) async {
        // Fetch local message
        guard let localMessage = try? await localDB.fetchOne(
            entity: LocalMessage.self,
            predicate: #Predicate { $0.localId == localId }
        ) else {
            return
        }
        
        // Skip if already synced
        guard localMessage.syncStatus == SyncStatus.pending.rawValue else {
            return
        }
        
        do {
            // Convert to Firestore message
            let message = localMessage.toMessage()
            
            // Write to Firestore
            let firestoreId = try await firebaseService.sendMessage(
                conversationId: message.conversationId,
                text: message.text,
                senderId: message.senderId,
                senderName: message.senderName
            )
            
            // Update local message with Firestore ID
            localMessage.id = firestoreId
            localMessage.syncStatus = SyncStatus.synced.rawValue
            localMessage.statusRaw = MessageStatus.sent.rawValue
            localMessage.serverTimestamp = Date()
            try await localDB.update(localMessage)
            
        } catch {
            // Sync failed - mark as failed, will retry later
            localMessage.syncStatus = SyncStatus.failed.rawValue
            localMessage.lastSyncAttempt = Date()
            localMessage.syncRetryCount += 1
            try? await localDB.update(localMessage)
            
            print("❌ Sync failed for message \(localId): \(error)")
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func handleMessageConflict(local: LocalMessage, remote: Message) async {
        // For messages, we use append-only log - no conflicts possible
        // Just update local with remote data if server timestamp is newer
        
        if let serverTime = remote.timestamp,
           let localServerTime = local.serverTimestamp,
           serverTime > localServerTime {
            // Remote is newer - update local
            local.statusRaw = remote.status.rawValue
            local.readBy = remote.readBy
            local.deliveredTo = remote.deliveredTo
            local.serverTimestamp = serverTime
            local.syncStatus = SyncStatus.synced.rawValue
            try? await localDB.update(local)
        }
    }
    
    // MARK: - Periodic Sync Worker
    
    private func startSyncWorker() {
        Task {
            while !Task.isCancelled {
                // Wait 10 seconds between sync attempts
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                
                // Sync pending operations
                await syncPendingOperations()
            }
        }
    }
    
    private func syncPendingOperations() async {
        // Find all pending messages
        let pendingMessages = try? await localDB.fetch(
            entity: LocalMessage.self,
            predicate: #Predicate { $0.syncStatus == SyncStatus.pending.rawValue }
        )
        
        // Sync each message
        for message in pendingMessages ?? [] {
            await syncMessage(localId: message.localId)
        }
        
        // Also sync failed messages (with exponential backoff)
        let failedMessages = try? await localDB.fetch(
            entity: LocalMessage.self,
            predicate: #Predicate {
                $0.syncStatus == SyncStatus.failed.rawValue &&
                $0.syncRetryCount < 5  // Max 5 retries
            }
        )
        
        for message in failedMessages ?? [] {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s
            let backoffDelay = pow(2.0, Double(message.syncRetryCount))
            if let lastAttempt = message.lastSyncAttempt,
               Date().timeIntervalSince(lastAttempt) > backoffDelay {
                await syncMessage(localId: message.localId)
            }
        }
    }
    
    // MARK: - Network Observation
    
    private func observeNetworkChanges() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self, isConnected else { return }
                
                // Network restored - trigger immediate sync
                Task { @MainActor in
                    await self.syncPendingOperations()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
```

### Conflict Resolution Strategy

**Last-Write-Wins (LWW) with Server Timestamp**

```swift
class ConflictResolver {
    
    // Resolve message conflict (append-only, so minimal conflicts)
    func resolveMessage(local: LocalMessage, remote: Message) -> LocalMessage {
        // Messages are append-only - just sync status fields
        // Use server timestamp to determine which status is newer
        
        if let remoteTime = remote.timestamp,
           let localTime = local.serverTimestamp,
           remoteTime > localTime {
            // Remote wins - update status fields
            local.statusRaw = remote.status.rawValue
            local.readBy = remote.readBy
            local.deliveredTo = remote.deliveredTo
            local.serverTimestamp = remoteTime
        }
        // Local timestamp is newer - keep local values
        
        local.syncStatus = SyncStatus.synced.rawValue
        return local
    }
    
    // Resolve conversation conflict (LWW)
    func resolveConversation(local: LocalConversation, remote: Conversation) -> LocalConversation {
        // Use server timestamp to determine winner
        
        if let remoteTime = remote.updatedAt,
           let localTime = local.serverTimestamp,
           remoteTime > localTime {
            // Remote wins - replace local with remote data
            return LocalConversation.from(remote)
        }
        
        // Local wins - keep local data, mark as pending sync
        local.syncStatus = SyncStatus.pending.rawValue
        return local
    }
    
    // Resolve user conflict (field-level merge for profile)
    func resolveUser(local: LocalUser, remote: User) -> LocalUser {
        // For user profiles, we can do field-level merge
        // Profile fields use LWW, but presence always uses server value
        
        // Presence always from server (real-time)
        local.isOnline = remote.isOnline
        local.lastSeen = remote.lastSeen
        
        // Profile fields use LWW
        if let remoteTime = local.serverTimestamp,
           let localTime = local.serverTimestamp,
           remoteTime > localTime {
            local.displayName = remote.displayName
            local.profileImageUrl = remote.profileImageUrl
            local.serverTimestamp = remoteTime
        }
        
        local.syncStatus = SyncStatus.synced.rawValue
        return local
    }
}
```

---

## ViewModel Integration

### Before (Current Architecture)

```swift
class ChatViewModel: ObservableObject {
    @Published var allMessages: [Message] = []
    
    private let messageService = MessageService()
    private var listener: ListenerRegistration?
    
    init(conversationId: String) {
        // Listen to Firestore directly
        listener = messageService.listenToMessages(conversationId) { [weak self] messages in
            self?.allMessages = messages
        }
    }
    
    func sendMessage(_ text: String) {
        // Manual optimistic update
        let tempMessage = Message(...)
        allMessages.append(tempMessage)
        
        // Send to Firestore
        Task {
            try await messageService.sendMessage(...)
        }
    }
}
```

**Problems:**
- ViewModel talks directly to Firestore
- Manual cache management
- Optimistic updates require complex merge logic
- Hard to test (need Firestore emulator)

### After (Repository Pattern)

```swift
class ChatViewModel: ObservableObject {
    @Published var allMessages: [Message] = []
    
    private let messageRepository: MessageRepositoryProtocol
    private var observationTask: Task<Void, Never>?
    
    init(conversationId: String, messageRepository: MessageRepositoryProtocol) {
        self.messageRepository = messageRepository
        
        // Observe messages from repository (always from local DB)
        observationTask = Task {
            for await messages in messageRepository.observeMessages(conversationId: conversationId) {
                await MainActor.run {
                    self.allMessages = messages
                }
            }
        }
    }
    
    func sendMessage(_ text: String) {
        // No manual optimistic update needed!
        // Repository writes to local DB immediately, we observe the change
        Task {
            try await messageRepository.sendMessage(
                conversationId: conversationId,
                text: text,
                senderId: currentUserId,
                senderName: currentUserName
            )
            // That's it! Repository handles optimistic update, sync, etc.
        }
    }
    
    deinit {
        observationTask?.cancel()
    }
}
```

**Benefits:**
- ViewModel only talks to Repository
- No manual cache management
- Optimistic updates automatic (repository writes to local DB first)
- Easy to test (mock repository)
- Cleaner code

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
**Goal:** Set up local database and repository pattern

**Tasks:**
1. **SwiftData Models** (2 days)
   - Define `LocalMessage`, `LocalConversation`, `LocalUser`
   - Add sync status fields
   - Create conversion methods (`toMessage()`, `from()`)
   - Write unit tests

2. **Local Database Wrapper** (1 day)
   - Create `LocalDatabase` class wrapping SwiftData ModelContext
   - Implement CRUD operations
   - Implement reactive queries with AsyncStream
   - Write unit tests

3. **Repository Pattern** (2 days)
   - Define protocols (`MessageRepositoryProtocol`, etc.)
   - Implement repositories with local DB access
   - NO sync yet - just local DB operations
   - Write unit tests with mock local DB

**Success Criteria:**
- ✅ All SwiftData models compile and pass tests
- ✅ Repositories can read/write to local DB
- ✅ AsyncStream observation works
- ✅ Unit tests pass (100% coverage for repositories)

**Deliverable:** Working repository layer (no sync yet)

---

### Phase 2: Sync Engine - Pull (Week 2)
**Goal:** Implement Firestore → Local DB sync

**Tasks:**
1. **Firestore Listeners** (2 days)
   - Set up collection listeners (messages, conversations, users)
   - Handle snapshot events (added, modified, removed)
   - Write to local DB on Firestore changes
   - Handle errors and retries

2. **Conflict Resolution** (1 day)
   - Implement LWW conflict resolver
   - Test with simulated conflicts
   - Verify server timestamp logic

3. **Integration Testing** (2 days)
   - Test Firestore → Local DB sync
   - Verify real-time updates
   - Test with multiple conversations
   - Test conflict scenarios

**Success Criteria:**
- ✅ Firestore changes appear in local DB within 1 second
- ✅ Conflicts resolved correctly (LWW)
- ✅ No data loss in sync process
- ✅ Integration tests pass

**Deliverable:** Working pull sync (Firestore → Local)

---

### Phase 3: Sync Engine - Push (Week 3)
**Goal:** Implement Local DB → Firestore sync

**Tasks:**
1. **Pending Operation Queue** (2 days)
   - Detect pending writes in local DB
   - Queue sync operations
   - Implement retry logic with exponential backoff
   - Handle sync failures gracefully

2. **Push Sync Implementation** (2 days)
   - Push messages to Firestore
   - Push conversation updates to Firestore
   - Push user updates to Firestore
   - Update sync status on success/failure

3. **Network Observation** (1 day)
   - Integrate with NetworkMonitor
   - Trigger sync on network reconnection
   - Pause sync when offline
   - Test offline → online transitions

**Success Criteria:**
- ✅ Local writes sync to Firestore within 5 seconds (when online)
- ✅ Offline writes queue and sync on reconnection
- ✅ Retry logic works (exponential backoff)
- ✅ No duplicate writes to Firestore

**Deliverable:** Working bidirectional sync

---

### Phase 4: ViewModel Migration (Week 4)
**Goal:** Migrate ViewModels to use repositories

**Tasks:**
1. **ChatViewModel Migration** (1 day)
   - Replace MessageService with MessageRepository
   - Remove manual cache management
   - Test real-time message updates
   - Verify optimistic UI still works

2. **ConversationListViewModel Migration** (1 day)
   - Replace ConversationService with ConversationRepository
   - Remove manual unread count calculation (move to repository)
   - Test conversation list updates

3. **Other ViewModels** (1 day)
   - Migrate any remaining ViewModels
   - Remove old service layer usage
   - Update dependency injection

4. **Integration Testing** (2 days)
   - End-to-end testing of entire app
   - Test send message flow
   - Test create conversation flow
   - Test offline scenarios
   - Performance testing

**Success Criteria:**
- ✅ All ViewModels use repositories
- ✅ No direct Firestore access from ViewModels
- ✅ App works identically to before (from user perspective)
- ✅ All integration tests pass
- ✅ Performance acceptable (local DB reads < 50ms)

**Deliverable:** Fully migrated app with repository pattern

---

### Phase 5: Cleanup & Optimization (Week 5)
**Goal:** Remove old code, optimize, and document

**Tasks:**
1. **Remove Old Services** (1 day)
   - Delete MessageService (replace with MessageRepository)
   - Delete ConversationService (replace with ConversationRepository)
   - Keep FirebaseService for auth and FCM
   - Update imports throughout codebase

2. **Cache Management** (1 day)
   - Implement cache size limits (100MB)
   - Implement cache eviction (oldest messages first)
   - Add cache stats/monitoring
   - Test with large datasets

3. **Performance Optimization** (1 day)
   - Profile SwiftData queries
   - Add database indexes if needed
   - Optimize sync loop (batch operations)
   - Reduce main thread blocking

4. **Documentation** (2 days)
   - Update architecture diagrams
   - Document repository pattern usage
   - Add inline code documentation
   - Create migration guide for future developers
   - Update README

**Success Criteria:**
- ✅ Old services removed, code compiles
- ✅ Cache stays under 100MB
- ✅ App performance is good (smooth scrolling)
- ✅ Documentation complete

**Deliverable:** Production-ready sync framework

---

## Testing Strategy

### Unit Tests

**Repository Layer:**
```swift
// Test message repository with mock local DB
class MessageRepositoryTests: XCTestCase {
    var repository: MessageRepository!
    var mockLocalDB: MockLocalDatabase!
    
    func testSendMessage_WritesToLocalDBFirst() async throws {
        // Arrange
        let text = "Hello"
        
        // Act
        let message = try await repository.sendMessage(
            conversationId: "conv123",
            text: text,
            senderId: "user1",
            senderName: "Alice"
        )
        
        // Assert
        XCTAssertNotNil(message.localId)
        XCTAssertEqual(message.status, .sending)
        XCTAssertEqual(mockLocalDB.insertedMessages.count, 1)
        XCTAssertEqual(mockLocalDB.insertedMessages.first?.text, text)
    }
    
    func testObserveMessages_ReturnsLocalDBChanges() async throws {
        // Test that observing messages returns AsyncStream from local DB
        // ...
    }
}
```

**Sync Engine:**
```swift
class SyncEngineTests: XCTestCase {
    func testHandleFirestoreSnapshot_InsertsNewMessage() async throws {
        // Test Firestore → Local DB sync
        // ...
    }
    
    func testSyncMessage_PushesToFirestore() async throws {
        // Test Local DB → Firestore sync
        // ...
    }
    
    func testConflictResolution_LastWriteWins() async throws {
        // Test LWW conflict resolution
        // ...
    }
}
```

### Integration Tests

**End-to-End Message Flow:**
```swift
class MessageFlowIntegrationTests: XCTestCase {
    func testSendMessage_AppearsInRecipientChat() async throws {
        // 1. User A sends message
        // 2. Verify writes to local DB immediately
        // 3. Verify syncs to Firestore
        // 4. Verify User B's local DB receives update
        // 5. Verify User B's ViewModel receives update
    }
    
    func testOfflineMessage_SyncsOnReconnection() async throws {
        // 1. Go offline
        // 2. Send message
        // 3. Verify queued in local DB
        // 4. Go online
        // 5. Verify syncs to Firestore
    }
}
```

### Performance Tests

```swift
class PerformanceTests: XCTestCase {
    func testMessageRepository_ReadPerformance() {
        measure {
            // Fetch 1000 messages from local DB
            // Should complete in < 50ms
        }
    }
    
    func testSyncEngine_BulkSync() {
        // Sync 100 messages
        // Verify completes in < 5 seconds
    }
}
```

---

## Success Metrics

### Correctness Metrics
- **Zero Data Loss:** No messages lost during sync
- **Conflict Resolution:** 100% of conflicts resolved via LWW
- **Sync Accuracy:** Local DB and Firestore eventually consistent within 5 seconds

### Performance Metrics
- **Read Latency:** Local DB reads < 50ms (p99)
- **Write Latency:** Local DB writes < 10ms (p99)
- **Sync Latency:** Pending operations sync to Firestore < 5 seconds (when online)
- **Memory Usage:** < 100MB cache size maintained

### Developer Experience Metrics
- **Code Reduction:** 30% fewer lines in ViewModels (no manual cache management)
- **Test Coverage:** 90%+ unit test coverage for repositories
- **Debugging Time:** Reduce time to diagnose data bugs by 50% (single source of truth)

---

## Debugging & Monitoring

### Sync Status UI (Developer Tool)

```swift
// Debug view to inspect sync state
struct SyncStatusView: View {
    @ObservedObject var syncEngine: SyncEngine
    
    var body: some View {
        List {
            Section("Sync Status") {
                HStack {
                    Text("Is Syncing")
                    Spacer()
                    Text(syncEngine.isSyncing ? "Yes" : "No")
                }
                HStack {
                    Text("Pending Operations")
                    Spacer()
                    Text("\(syncEngine.pendingOperationCount)")
                }
                HStack {
                    Text("Failed Operations")
                    Spacer()
                    Text("\(syncEngine.failedOperationCount)")
                }
            }
            
            Section("Cache Stats") {
                HStack {
                    Text("Messages Cached")
                    Spacer()
                    Text("\(syncEngine.messageCacheCount)")
                }
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text("\(syncEngine.cacheSizeFormatted)")
                }
            }
            
            Section("Actions") {
                Button("Force Sync Now") {
                    Task {
                        await syncEngine.syncPendingOperations()
                    }
                }
                Button("Clear Cache") {
                    Task {
                        await syncEngine.clearCache()
                    }
                }
            }
        }
    }
}
```

### Logging Strategy

```swift
// Structured logging for sync operations
enum SyncLogEvent {
    case syncStarted(entityType: String, operation: String)
    case syncSucceeded(entityType: String, operation: String, duration: TimeInterval)
    case syncFailed(entityType: String, operation: String, error: Error)
    case conflictDetected(entityType: String, resolution: String)
    case cacheEvicted(entityType: String, count: Int)
}

class SyncLogger {
    static func log(_ event: SyncLogEvent) {
        // Log to console in debug, send to analytics in production
        switch event {
        case .syncStarted(let type, let op):
            print("🔄 Sync started: \(type).\(op)")
        case .syncSucceeded(let type, let op, let duration):
            print("✅ Sync succeeded: \(type).\(op) in \(duration)s")
        case .syncFailed(let type, let op, let error):
            print("❌ Sync failed: \(type).\(op) - \(error)")
        case .conflictDetected(let type, let resolution):
            print("⚠️ Conflict: \(type) resolved via \(resolution)")
        case .cacheEvicted(let type, let count):
            print("🗑️ Cache evicted: \(count) \(type) objects")
        }
    }
}
```

---

## Migration Plan

### Pre-Migration Checklist
- [ ] All unit tests written and passing
- [ ] Integration tests written and passing
- [ ] Performance benchmarks meet targets
- [ ] Documentation complete
- [ ] Code review completed
- [ ] Sync status debug UI ready

### Migration Steps

**Step 1: Deploy Sync Framework (Week 1)**
- Deploy repository layer and sync engine
- Keep old services running in parallel
- Use feature flag to enable new system for internal testing
- Monitor logs for any issues

**Step 2: Internal Testing (Week 2)**
- Enable for 100% of internal users
- Test all major flows (send message, create conversation, etc.)
- Monitor sync metrics
- Fix any bugs found

**Step 3: Gradual Rollout (Week 3-4)**
- Enable for 10% of external users
- Monitor for 48 hours
- If stable, increase to 50%
- Monitor for 48 hours
- If stable, increase to 100%

**Step 4: Cleanup (Week 5)**
- Remove feature flag
- Remove old service layer
- Clean up unused code
- Update documentation

### Rollback Plan

If critical issues found:
1. Disable feature flag immediately
2. App falls back to old Firestore-direct approach
3. Investigate and fix issues
4. Re-enable after fix verified

**No data loss:** Both systems write to Firestore, so rollback is safe.

---

## Open Questions

### Technical Questions
1. **SwiftData Performance:** Is SwiftData fast enough for 1000+ messages? (Benchmark in Phase 1)
2. **Background Sync:** Can we use BGTaskScheduler for reliable background sync? (Research in Phase 3)
3. **Cache Eviction:** Should we evict by time (>30 days) or by size (>100MB)? (Decide in Phase 5)

### Product Questions
1. **Sync UI:** Should users see sync status? Or keep it hidden? (Design decision)
2. **Offline Indicator:** Show "Offline" banner when network is down? (UX decision)
3. **Failed Sync:** Show UI for failed messages? Or auto-retry silently? (Product decision)

---

## Risks & Mitigations

### Risk 1: SwiftData Performance
**Risk:** SwiftData queries too slow for large datasets  
**Impact:** High - app feels laggy  
**Likelihood:** Medium - SwiftData is relatively new  
**Mitigation:**
- Benchmark early in Phase 1
- If too slow, switch to Core Data or Realm
- Use indexes on frequently queried fields

### Risk 2: Sync Bugs
**Risk:** Sync engine has bugs causing data inconsistency  
**Impact:** High - users see wrong data  
**Likelihood:** Medium - sync is complex  
**Mitigation:**
- Extensive unit and integration tests
- Gradual rollout with monitoring
- Keep old system as fallback (feature flag)

### Risk 3: Battery Drain
**Risk:** Background sync drains battery  
**Impact:** Medium - poor user experience  
**Likelihood:** Low - sync is efficient  
**Mitigation:**
- Use NetworkMonitor to pause sync when offline
- Batch sync operations (not one-by-one)
- Profile battery usage in testing

### Risk 4: Timeline Overrun
**Risk:** Implementation takes longer than 5 weeks  
**Impact:** Medium - delays other features  
**Likelihood:** Medium - sync is complex  
**Mitigation:**
- Break into phases (can ship partial solution)
- Prioritize critical path (messages first, then conversations/users)
- Reduce scope if needed (drop cache eviction, advanced monitoring)

---

## Future Enhancements (Post-MVP)

### Phase 6+: Advanced Features

**Multi-Device Sync Optimization**
- Sync only deltas (not full documents)
- Use last sync timestamp to fetch changes
- Reduce bandwidth and battery usage

**Full-Text Search**
- Add FTS (Full-Text Search) index to SwiftData
- Search messages offline
- Much faster than Firestore queries

**Attachments & Media**
- Sync message attachments (images, files)
- Smart caching (only download when viewed)
- Thumbnail generation for images

**Advanced Conflict Resolution**
- CRDT for richer data types
- Operational Transform for collaborative editing
- Manual conflict resolution UI

**Analytics & Monitoring**
- Track sync success rate
- Monitor cache hit rate
- Alert on sync failures

---

## Appendix

### Related Documents
- `/architecture.md` - Overall system architecture
- `/architecture-dataflow-overview.md` - Current data flow (to be updated)
- `/memory-bank/systemPatterns.md` - Architectural patterns
- `/memory-bank/techContext.md` - Technology stack

### References
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)
- [Offline-First Architecture](https://offlinefirst.org/)
- [Conflict-Free Replicated Data Types](https://crdt.tech/)

---

**Document Version:** 1.0  
**Last Updated:** October 22, 2025  
**Owner:** Engineering Team  
**Status:** Ready for Review

