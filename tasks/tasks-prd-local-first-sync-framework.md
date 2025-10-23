# Task List: Local-First Sync Framework Implementation

**Based on:** `prd-local-first-sync-framework.md`  
**Status:** Planning - Ready for implementation

---

## Relevant Files

### Core Sync Framework (✅ Task 1.0 Complete)
- ✅ `NexusAI/Data/SyncStatus.swift` - Sync status enum (synced, pending, failed, conflict)
- ✅ `NexusAI/Data/LocalDatabase.swift` - SwiftData wrapper with CRUD operations and AsyncStream
- ✅ `NexusAI/Data/Models/LocalMessage.swift` - SwiftData model for messages
- ✅ `NexusAI/Data/Models/LocalConversation.swift` - SwiftData model for conversations
- ✅ `NexusAI/Data/Models/LocalUser.swift` - SwiftData model for users
- `NexusAI/Data/Repositories/MessageRepository.swift` - Message repository implementation
- `NexusAI/Data/Repositories/ConversationRepository.swift` - Conversation repository implementation
- `NexusAI/Data/Repositories/UserRepository.swift` - User repository implementation
- `NexusAI/Data/Repositories/Protocols/MessageRepositoryProtocol.swift` - Message repository protocol
- `NexusAI/Data/Repositories/Protocols/ConversationRepositoryProtocol.swift` - Conversation repository protocol
- `NexusAI/Data/Repositories/Protocols/UserRepositoryProtocol.swift` - User repository protocol
- `NexusAI/Sync/SyncEngine.swift` - Main sync engine coordinator
- `NexusAI/Sync/ConflictResolver.swift` - Conflict resolution logic (Last-Write-Wins)
- `NexusAI/Sync/SyncStatus.swift` - Sync status enum and models
- `NexusAI/Sync/SyncLogger.swift` - Structured logging for sync operations

### Updated ViewModels
- `NexusAI/ViewModels/ChatViewModel.swift` - Migrated to use MessageRepository
- `NexusAI/ViewModels/ConversationListViewModel.swift` - Migrated to use ConversationRepository
- `NexusAI/ViewModels/AuthViewModel.swift` - Migrated to use UserRepository

### Testing (✅ Task 1.0 Tests Complete)
- ✅ `NexusAITests/Data/LocalDatabaseTests.swift` - Unit tests for local database CRUD operations
- ✅ `NexusAITests/Data/Models/LocalMessageTests.swift` - Unit tests for LocalMessage conversion methods
- ✅ `NexusAITests/Data/Models/LocalConversationTests.swift` - Unit tests for LocalConversation conversion methods
- ✅ `NexusAITests/Data/Models/LocalUserTests.swift` - Unit tests for LocalUser conversion methods
- `NexusAITests/Data/Repositories/MessageRepositoryTests.swift` - Unit tests for MessageRepository
- `NexusAITests/Sync/SyncEngineTests.swift` - Unit tests for sync engine
- `NexusAITests/Sync/ConflictResolverTests.swift` - Unit tests for conflict resolution
- `NexusAITests/Integration/SyncIntegrationTests.swift` - End-to-end integration tests

### Debug Tools
- `NexusAI/Views/Debug/SyncStatusView.swift` - Debug UI for inspecting sync state
- `NexusAI/Views/Debug/CacheStatsView.swift` - Debug UI for cache statistics

### Deprecated (To be removed in Task 7)
- `NexusAI/Services/MessageService.swift` - Will be replaced by MessageRepository
- `NexusAI/Services/ConversationService.swift` - Will be replaced by ConversationRepository
- `NexusAI/Services/MessageQueueService.swift` - Functionality absorbed into SyncEngine

---

## Tasks

- [x] 1.0 **Database Layer Foundation** - Create SwiftData models and local database wrapper as single source of truth
  - [x] 1.1 Create `SyncStatus` enum for tracking sync state (synced, pending, failed, conflict)
  - [x] 1.2 Define `LocalMessage` SwiftData model with sync fields (id, localId, syncStatus, serverTimestamp, etc.)
  - [x] 1.3 Define `LocalConversation` SwiftData model with sync fields and denormalized lastMessage
  - [x] 1.4 Define `LocalUser` SwiftData model with sync fields and presence data
  - [x] 1.5 Add conversion methods (`toMessage()`, `from()`) to each local model
  - [x] 1.6 Create `LocalDatabase` class wrapping SwiftData ModelContainer and ModelContext
  - [x] 1.7 Implement generic CRUD operations in LocalDatabase (insert, update, delete, fetch, fetchOne)
  - [x] 1.8 Implement reactive query method using AsyncStream for real-time observations
  - [x] 1.9 Write unit tests for LocalMessage conversion methods
  - [x] 1.10 Write unit tests for LocalConversation conversion methods
  - [x] 1.11 Write unit tests for LocalUser conversion methods
  - [x] 1.12 Write unit tests for LocalDatabase CRUD operations
  - [x] 1.13 Write unit tests for LocalDatabase AsyncStream observations (NOTE: AsyncStream requires integration testing)
  - [x] 1.14 Verify all tests pass and models compile without errors

- [x] 2.0 **Repository Pattern Implementation** - Build protocol-based repository layer for clean data access
  - [x] 2.1 Create `MessageRepositoryProtocol` with methods: observe, sendMessage, markAsRead, markAsDelivered
  - [x] 2.2 Create `ConversationRepositoryProtocol` with methods: observe, create, updateLastMessage
  - [x] 2.3 Create `UserRepositoryProtocol` with methods: observe, updatePresence, updateProfile
  - [x] 2.4 Implement `MessageRepository` reading/writing ONLY from LocalDatabase (no Firestore yet)
  - [x] 2.5 Implement `ConversationRepository` reading/writing ONLY from LocalDatabase
  - [x] 2.6 Implement `UserRepository` reading/writing ONLY from LocalDatabase
  - [x] 2.7 Add observeMessages(conversationId:) returning AsyncStream<[Message]>
  - [x] 2.8 Add sendMessage() writing to local DB with status .pending
  - [x] 2.9 Add pagination methods (getMessagesBefore) to MessageRepository
  - [x] 2.10 Create `MockMessageRepository` for testing
  - [x] 2.11 Create `MockConversationRepository` for testing
  - [x] 2.12 Create `MockUserRepository` for testing
  - [x] 2.13 Write unit tests for MessageRepository with mock LocalDatabase
  - [x] 2.14 Write unit tests for ConversationRepository with mock LocalDatabase
  - [x] 2.15 Write unit tests for UserRepository with mock LocalDatabase
  - [x] 2.16 Test AsyncStream observation triggers on local DB changes
  - [x] 2.17 Verify repositories work without any network/Firestore dependency

- [ ] 3.0 **Sync Engine - Pull Sync** - Implement Firestore → Local DB synchronization with conflict resolution
  - [ ] 3.1 Create `ConflictResolver` class with LWW (Last-Write-Wins) strategy
  - [ ] 3.2 Implement `resolveMessage()` comparing server timestamps
  - [ ] 3.3 Implement `resolveConversation()` using LWW for all fields
  - [ ] 3.4 Implement `resolveUser()` with field-level merge (presence always from server)
  - [ ] 3.5 Create `SyncEngine` class with LocalDatabase and FirebaseService dependencies
  - [ ] 3.6 Implement `startMessageListener()` using Firestore collectionGroup("messages")
  - [ ] 3.7 Handle Firestore snapshot DocumentChange.added - insert to local DB if new
  - [ ] 3.8 Handle Firestore snapshot DocumentChange.modified - check for conflicts, resolve, update local DB
  - [ ] 3.9 Handle Firestore snapshot DocumentChange.removed - delete from local DB
  - [ ] 3.10 Implement `startConversationListener()` for conversations collection
  - [ ] 3.11 Implement `startUserListener()` for users collection (presence updates)
  - [ ] 3.12 Add error handling and retry logic for listener failures
  - [ ] 3.13 Implement `start()` method to start all listeners
  - [ ] 3.14 Implement `stop()` method to remove all listeners
  - [ ] 3.15 Write unit tests for ConflictResolver LWW logic
  - [ ] 3.16 Write unit tests for message snapshot handling with mock Firestore data
  - [ ] 3.17 Write integration test: Firestore change appears in LocalDatabase within 1 second
  - [ ] 3.18 Test conflict scenarios (local and remote both modified)
  - [ ] 3.19 Verify no data loss during pull sync

- [ ] 4.0 **Sync Engine - Push Sync** - Implement Local DB → Firestore synchronization with retry logic
  - [ ] 4.1 Implement `syncMessage(localId:)` to push pending messages to Firestore
  - [ ] 4.2 Update local message with Firestore ID and status .synced on success
  - [ ] 4.3 Mark message as .failed and increment retryCount on sync failure
  - [ ] 4.4 Implement exponential backoff for retry (1s, 2s, 4s, 8s, 16s, max 5 retries)
  - [ ] 4.5 Implement `syncConversation()` to push conversation updates to Firestore
  - [ ] 4.6 Implement `syncUser()` to push user profile updates to Firestore
  - [ ] 4.7 Create `startSyncWorker()` background task running every 10 seconds
  - [ ] 4.8 Query LocalDatabase for all entities with syncStatus == .pending
  - [ ] 4.9 Query LocalDatabase for failed entities eligible for retry (backoff check)
  - [ ] 4.10 Integrate NetworkMonitor to pause sync when offline
  - [ ] 4.11 Implement `observeNetworkChanges()` to trigger immediate sync on reconnection
  - [ ] 4.12 Add sync queue ordering (messages by timestamp, oldest first)
  - [ ] 4.13 Prevent duplicate Firestore writes (check if already synced)
  - [ ] 4.14 Write unit tests for exponential backoff logic
  - [ ] 4.15 Write unit tests for pending operation detection
  - [ ] 4.16 Write integration test: offline message syncs on network reconnection
  - [ ] 4.17 Test retry logic with simulated Firestore failures
  - [ ] 4.18 Verify bidirectional sync works (pull + push together)

- [ ] 5.0 **ViewModel Migration** - Migrate all ViewModels from direct Firestore access to Repository pattern
  - [ ] 5.1 Add feature flag `isLocalFirstSyncEnabled` to Constants
  - [ ] 5.2 Update ChatViewModel to accept MessageRepositoryProtocol in init
  - [ ] 5.3 Replace MessageService.listenToMessages with messageRepository.observeMessages
  - [ ] 5.4 Replace manual optimistic update logic with repository.sendMessage (handles optimistic automatically)
  - [ ] 5.5 Remove manual cache management from ChatViewModel (repository handles it)
  - [ ] 5.6 Update ConversationListViewModel to accept ConversationRepositoryProtocol
  - [ ] 5.7 Replace ConversationService with conversationRepository.observe
  - [ ] 5.8 Remove manual unread count calculation (move to repository)
  - [ ] 5.9 Update AuthViewModel to use UserRepository for profile updates
  - [ ] 5.10 Update all ViewModel initializers to inject repositories
  - [ ] 5.11 Create RepositoryFactory for dependency injection
  - [ ] 5.12 Update NexusAIApp to create repositories and inject into ViewModels
  - [ ] 5.13 Add feature flag check: if disabled, use old services (rollback path)
  - [ ] 5.14 Initialize and start SyncEngine in NexusAIApp.init()
  - [ ] 5.15 Test ChatView with new repository-based ChatViewModel
  - [ ] 5.16 Test ConversationListView with new repository-based ViewModel
  - [ ] 5.17 Verify message sending still works (optimistic UI)
  - [ ] 5.18 Verify real-time updates still work (AsyncStream observations)
  - [ ] 5.19 Test offline message queueing and sync on reconnection
  - [ ] 5.20 Verify read receipts still work through repository

- [ ] 6.0 **Integration Testing & Validation** - End-to-end testing of complete sync framework
  - [ ] 6.1 Write integration test: User A sends message → User B receives within 1 second
  - [ ] 6.2 Write integration test: Send 20 rapid messages → all sync correctly, no duplicates
  - [ ] 6.3 Write integration test: Go offline → send message → go online → message syncs
  - [ ] 6.4 Write integration test: Create conversation → appears in both users' lists
  - [ ] 6.5 Write integration test: Update user profile → syncs to all devices
  - [ ] 6.6 Write integration test: Conflict scenario → LWW resolves correctly
  - [ ] 6.7 Test pagination: Load 100+ messages, verify scroll position maintained
  - [ ] 6.8 Test app lifecycle: Background → foreground, verify sync resumes
  - [ ] 6.9 Test force quit → reopen, verify local data persists
  - [ ] 6.10 Performance test: Query 1000 messages from local DB < 50ms
  - [ ] 6.11 Performance test: Write message to local DB < 10ms
  - [ ] 6.12 Performance test: Sync 100 pending messages < 5 seconds
  - [ ] 6.13 Memory test: Cache stays under 100MB with 1000+ messages
  - [ ] 6.14 Test network interruption during sync (mid-operation disconnect)
  - [ ] 6.15 Test sync status transitions (pending → synced → failed → retry)
  - [ ] 6.16 Verify no memory leaks (Instruments profiling)
  - [ ] 6.17 Test on iOS 17.0 (minimum supported version)
  - [ ] 6.18 Document any edge cases or known issues discovered

- [ ] 7.0 **Cleanup & Optimization** - Remove old services, optimize performance, add monitoring
  - [ ] 7.1 Remove `MessageService.swift` (fully replaced by MessageRepository)
  - [ ] 7.2 Remove `ConversationService.swift` (fully replaced by ConversationRepository)
  - [ ] 7.3 Remove `MessageQueueService.swift` (functionality in SyncEngine)
  - [ ] 7.4 Remove `LocalStorageService.swift` (replaced by LocalDatabase)
  - [ ] 7.5 Search codebase for any remaining references to old services, update to repositories
  - [ ] 7.6 Implement cache size monitoring (calculate total SwiftData storage used)
  - [ ] 7.7 Implement cache eviction policy: delete oldest messages when > 100MB
  - [ ] 7.8 Add SwiftData indexes for frequently queried fields (conversationId, timestamp, syncStatus)
  - [ ] 7.9 Optimize sync loop: batch Firestore writes (multiple messages in one batch)
  - [ ] 7.10 Profile SwiftData query performance with Instruments
  - [ ] 7.11 Optimize message merge logic (reduce array operations)
  - [ ] 7.12 Add SyncEngine performance metrics (sync latency, conflict rate, cache hit rate)
  - [ ] 7.13 Implement `clearCache()` method for debug/testing
  - [ ] 7.14 Add cache statistics: message count, conversation count, cache size
  - [ ] 7.15 Test cache eviction: verify oldest messages deleted when limit reached
  - [ ] 7.16 Verify app performance is acceptable (smooth scrolling, no jank)
  - [ ] 7.17 Run performance benchmarks, compare to baseline (before sync framework)
  - [ ] 7.18 Fix any performance regressions found

- [ ] 8.0 **Documentation & Developer Tools** - Update architecture docs and create debugging tools
  - [ ] 8.1 Create `SyncStatusView` debug UI showing sync state (is syncing, pending count, failed count)
  - [ ] 8.2 Add cache stats display (message count, cache size, last sync time)
  - [ ] 8.3 Add "Force Sync Now" button for manual sync trigger
  - [ ] 8.4 Add "Clear Cache" button for testing
  - [ ] 8.5 Create `SyncLogger` with structured logging (syncStarted, syncSucceeded, syncFailed, conflictDetected)
  - [ ] 8.6 Add console logging for sync operations (debug builds only)
  - [ ] 8.7 Update `architecture-dataflow-overview.md` with new sync framework architecture
  - [ ] 8.8 Add section explaining Repository Pattern implementation
  - [ ] 8.9 Add diagrams showing sync flow (pull and push)
  - [ ] 8.10 Document conflict resolution strategy (LWW with examples)
  - [ ] 8.11 Update `systemPatterns.md` with Repository Pattern details
  - [ ] 8.12 Create developer guide: "How to Use Repositories in ViewModels"
  - [ ] 8.13 Document debugging workflow: "How to Debug Sync Issues"
  - [ ] 8.14 Add inline code documentation (doc comments) for all public repository methods
  - [ ] 8.15 Add inline code documentation for SyncEngine public methods
  - [ ] 8.16 Update README with sync framework overview
  - [ ] 8.17 Create migration guide for future developers adding new models
  - [ ] 8.18 Document feature flag usage and rollback procedure

---

**Detailed sub-tasks generated!**

**Total:** 8 parent tasks, 134 sub-tasks covering:
- ✅ SwiftData models with sync state tracking
- ✅ Repository pattern with protocols for testability
- ✅ Bidirectional sync (Firestore ↔ Local DB)
- ✅ Conflict resolution (Last-Write-Wins)
- ✅ Network monitoring and offline queue
- ✅ Feature flag for safe rollout
- ✅ Unit tests built incrementally
- ✅ Integration testing and performance validation
- ✅ Cache management (100MB limit)
- ✅ Debug tools and comprehensive documentation

Ready to start implementation? Each sub-task is atomic and testable.

