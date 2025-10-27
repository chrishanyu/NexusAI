# System Patterns & Architecture

## Architectural Overview

NexusAI follows a clean **MVVM (Model-View-ViewModel)** architecture with a service layer for business logic and Firebase integration. The architecture is designed for:
- Real-time data synchronization
- Offline-first operation
- Optimistic UI updates
- Scalability for AI features

## Layer Responsibilities

### 1. View Layer (SwiftUI)
**Purpose:** Pure presentation, no business logic

**Components:**
- `LoginView`, `SignUpView` - Authentication screens
- `ConversationListView` - Main conversation list
- `ChatView` - Individual/group chat screen
- `MessageBubbleView`, `MessageInputView` - Chat components
- `ProfileImageView`, `OnlineStatusIndicator` - Reusable components

**Patterns:**
- Views observe ViewModels via `@ObservedObject` or `@StateObject`
- Use `@State` for local UI state only
- Delegate user actions to ViewModels
- No direct Firebase/service calls

**iOS 26 Specific Patterns:**
- Use `.scrollPosition(id:anchor:)` instead of `.defaultScrollAnchor()` for better scroll control
- Apply `.scrollTargetLayout()` to enable precise scroll positioning with LazyVStack
- Track initial load states to prevent unwanted scroll animations on view appearance
- Leverage modern SwiftUI scroll APIs introduced in iOS 26

**Example:**
```swift
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var scrollPosition: String?
    @State private var isInitialLoad = true
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageView(message: message)
                        .id(message.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPosition, anchor: .bottom)
        .onChange(of: messages.count) { oldCount, newCount in
            if isInitialLoad {
                isInitialLoad = false
                scrollPosition = messages.last?.id
                return
            }
            // Handle new messages
        }
    }
}
```

### 2. ViewModel Layer
**Purpose:** Presentation logic, state management, coordinate services

**Components:**
- `AuthViewModel` - Authentication state, login/signup logic
- `ConversationListViewModel` - Conversation list state, filtering
- `ChatViewModel` - Message list, sending, typing indicators
- `PresenceManager` - Global presence state management
- `NotificationManager` - Push notification handling

**Patterns:**
- Conform to `ObservableObject`
- Expose `@Published` properties for Views
- Call Services for data operations
- Transform service data for UI consumption
- Handle loading and error states

**Example:**
```swift
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let messageService: MessageService
    private var listener: ListenerRegistration?
    
    func sendMessage(_ text: String) {
        // Optimistic UI: add message immediately
        let tempMessage = Message(localId: UUID().uuidString, ...)
        messages.append(tempMessage)
        
        // Send to Firebase
        Task {
            await messageService.sendMessage(text, in: conversationId)
        }
    }
}
```

### 3. Service Layer
**Purpose:** Business logic, Firebase operations, data transformation

**Components:**
- `FirebaseService` - Firebase initialization, configuration
- `AuthService` - User authentication, profile management
- `MessageService` - Message CRUD, real-time listeners
- `ConversationService` - Conversation CRUD, participant management
- `PresenceService` - Online/offline status, typing indicators
- `NotificationService` - FCM token, notification handling
- `LocalStorageService` - SwiftData persistence
- `MessageQueueService` - Offline message queue

**Patterns:**
- Services are stateless (except singletons)
- Return Swift Concurrency types (`async throws`)
- Transform Firestore documents to Swift models
- Handle Firestore listeners and subscriptions
- Abstract Firebase details from ViewModels

**Example:**
```swift
class MessageService {
    private let db = Firestore.firestore()
    
    func sendMessage(_ text: String, in conversationId: String) async throws {
        let message = Message(...)
        try await db.collection("conversations/\(conversationId)/messages")
            .addDocument(from: message)
    }
    
    func listenToMessages(in conversationId: String, 
                         onChange: @escaping ([Message]) -> Void) 
        -> ListenerRegistration {
        return db.collection("conversations/\(conversationId)/messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                onChange(messages)
            }
    }
}
```

### 4. Model Layer
**Purpose:** Data structures, business entities

**Components:**
- `User` - User profile data
- `Conversation` - Conversation metadata
- `Message` - Individual message
- `MessageStatus` - Message delivery status enum
- `TypingIndicator` - Typing state

**Patterns:**
- Conform to `Codable` for Firestore encoding/decoding
- Conform to `Identifiable` for SwiftUI lists
- Use `@DocumentID` for Firestore IDs
- Immutable where possible (`let` over `var`)
- Nested types for related data (e.g., `Conversation.ParticipantInfo`)

**Example:**
```swift
struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    let conversationId: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
    var status: MessageStatus
    var readBy: [String]
    var deliveredTo: [String]
    var localId: String? // For optimistic UI
}
```

## Key Architectural Patterns

### 1. Optimistic UI Pattern
**Purpose:** Instant feedback, WhatsApp-like experience

**Flow:**
```
1. User action (send message)
2. Create temporary model with localId
3. Update UI immediately (optimistic)
4. Persist to local storage (SwiftData)
5. Send to Firestore (async)
6. On success: Replace temp with real ID
7. On failure: Show error, offer retry
```

**Implementation:**
```swift
// Step 2-3: Optimistic update
let tempMessage = Message(
    id: nil,
    localId: UUID().uuidString,
    status: .sending,
    ...
)
messages.append(tempMessage)

// Step 5: Background sync
Task {
    do {
        let realId = try await messageService.sendMessage(tempMessage)
        // Step 6: Update with real ID
        if let index = messages.firstIndex(where: { $0.localId == tempMessage.localId }) {
            messages[index].id = realId
            messages[index].status = .sent
        }
    } catch {
        // Step 7: Handle error
        if let index = messages.firstIndex(where: { $0.localId == tempMessage.localId }) {
            messages[index].status = .failed
        }
    }
}
```

### 2. Real-Time Sync Pattern
**Purpose:** Instant message delivery, live updates

**Flow:**
```
1. ViewModel subscribes to Firestore listener
2. Firestore sends snapshot on every change
3. Service decodes documents to models
4. ViewModel merges new messages with local optimistic messages
5. Published property updates
6. SwiftUI re-renders
```

**Implementation:**
```swift
// In ViewModel
func startListening() {
    listener = messageService.listenToMessages(in: conversationId) { [weak self] newMessages in
        self?.mergeMessages(newMessages)
    }
}

func mergeMessages(_ newMessages: [Message]) {
    // Remove optimistic messages that now have real IDs
    messages = messages.filter { $0.id != nil || $0.status == .sending }
    
    // Add new messages from Firestore
    for message in newMessages {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
        }
    }
    
    messages.sort { $0.timestamp < $1.timestamp }
}
```

### 3. Offline-First Pattern
**Purpose:** Work seamlessly without network

**Flow:**
```
1. User sends message while offline
2. Save to MessageQueueService (SwiftData)
3. Show "sending" status
4. NetworkMonitor detects reconnection
5. MessageQueueService flushes queue
6. Messages sent to Firestore
7. Real-time listener updates UI
```

**Implementation:**
```swift
// In MessageService
func sendMessage(_ message: Message) async throws {
    if NetworkMonitor.shared.isConnected {
        try await sendToFirestore(message)
    } else {
        await messageQueue.enqueue(message)
    }
}

// In MessageQueueService
func flushQueue() async {
    let queuedMessages = await getQueuedMessages()
    for message in queuedMessages {
        do {
            try await messageService.sendToFirestore(message)
            await removeFromQueue(message)
        } catch {
            // Keep in queue, retry later
        }
    }
}
```

### 4. Robust Presence Management Pattern (RTDB + Firestore Hybrid)
**Purpose:** Reliable online/offline status tracking with server-side disconnect detection

**Architecture:**
```
RTDB (presence/{userId})     Firestore (users/{userId})
├── isOnline: Bool           └── isOnline: Bool (synced)
├── lastSeen: Timestamp      
├── lastHeartbeat: Timestamp
└── onDisconnect() callback
```

**Key Features:**
- Server-side disconnect detection via `onDisconnect()`
- Heartbeat mechanism (30s interval) to detect stale connections
- Offline queue with automatic retry using Swift Actor
- iOS background task integration for reliable offline updates
- Stale presence detection (>60s = offline)

**Flow:**
```
1. Login/Auth → initializePresence(for: userId)
   ├── Set up RTDB reference: presence/{userId}
   ├── Register onDisconnect() callback (server-side)
   ├── Start 30s heartbeat timer
   └── Set user online

2. Heartbeat (every 30s)
   └── Update lastHeartbeat timestamp in RTDB

3. App backgrounds → setUserOffline(delay: 0)
   ├── iOS background task ensures completion
   ├── Write offline to RTDB immediately
   └── Sync to Firestore

4. App force-quit/crash
   └── onDisconnect() automatically sets offline (server-side!)

5. Network disconnects
   ├── Queue presence updates in PresenceQueue (Actor)
   ├── NetworkMonitor detects reconnection
   └── Auto-flush queue when online

6. Listen to presence
   ├── RTDB listener for real-time updates
   ├── Check heartbeat staleness (>60s = offline)
   └── Update UI with online/offline status
```

**Implementation:**
```swift
// Singleton service
class RealtimePresenceService {
    static let shared = RealtimePresenceService()
    
    private let rtdb: DatabaseReference
    private let firestore: Firestore
    private var heartbeatTimer: Timer?
    private var presenceRef: DatabaseReference?
    private let presenceQueue = PresenceQueue() // Actor
    
    // Initialize on login
    func initializePresence(for userId: String) {
        presenceRef = rtdb.child("presence").child(userId)
        setupConnectionStateMonitoring(userId: userId) // onDisconnect setup
        startHeartbeat(userId: userId)
    }
    
    // Set user online
    func setUserOnline(userId: String) async throws {
        let data: [String: Any] = [
            "isOnline": true,
            "lastSeen": ServerValue.timestamp(),
            "lastHeartbeat": ServerValue.timestamp()
        ]
        try await presenceRef?.setValue(data)
        try await updateFirestorePresence(userId: userId, isOnline: true)
    }
    
    // Set user offline (immediate for background)
    func setUserOffline(userId: String, delay: TimeInterval = 0) async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        let data: [String: Any] = [
            "isOnline": false,
            "lastSeen": ServerValue.timestamp(),
            "lastHeartbeat": ServerValue.timestamp()
        ]
        try await presenceRef?.setValue(data)
        try await updateFirestorePresence(userId: userId, isOnline: false)
    }
    
    // Listen to presence with stale detection
    func listenToPresence(userId: String, 
                         onChange: @escaping (Bool, Date?) -> Void) -> DatabaseHandle {
        let ref = rtdb.child("presence").child(userId)
        return ref.observe(.value) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let isOnline = data["isOnline"] as? Bool else {
                onChange(false, nil)
                return
            }
            
            // Check for stale presence (>60s since last heartbeat)
            if let heartbeat = data["lastHeartbeat"] as? TimeInterval {
                let heartbeatDate = Date(timeIntervalSince1970: heartbeat / 1000)
                let isStale = Date().timeIntervalSince(heartbeatDate) > 60
                
                if isStale && isOnline {
                    onChange(false, nil) // Stale = offline
                    return
                }
            }
            
            let lastSeen = (data["lastSeen"] as? TimeInterval).map { 
                Date(timeIntervalSince1970: $0 / 1000) 
            }
            onChange(isOnline, lastSeen)
        }
    }
    
    // Connection monitoring + onDisconnect setup
    private func setupConnectionStateMonitoring(userId: String) {
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] snapshot in
            guard let connected = snapshot.value as? Bool, connected,
                  let presenceRef = self?.presenceRef else { return }
            
            // Register server-side onDisconnect callback
            let disconnectData: [String: Any] = [
                "isOnline": false,
                "lastSeen": ServerValue.timestamp(),
                "lastHeartbeat": ServerValue.timestamp()
            ]
            presenceRef.onDisconnectSetValue(disconnectData)
            
            // Set online now that we're connected
            Task {
                try? await self?.setUserOnline(userId: userId)
            }
        }
    }
    
    // Heartbeat to keep presence fresh
    private func startHeartbeat(userId: String) {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
            [weak self] _ in
            guard let presenceRef = self?.presenceRef else { return }
            presenceRef.child("lastHeartbeat").setValue(ServerValue.timestamp())
        }
        heartbeatTimer?.fire()
    }
}

// Thread-safe offline queue using Actor
actor PresenceQueue {
    private struct QueuedUpdate {
        let userId: String
        let isOnline: Bool
        let timestamp: Date
    }
    
    private var queue: [String: QueuedUpdate] = [:] // Deduplicate by userId
    
    func enqueue(userId: String, isOnline: Bool) {
        queue[userId] = QueuedUpdate(userId: userId, isOnline: isOnline, timestamp: Date())
    }
    
    func flushQueue(using service: RealtimePresenceService) async {
        guard !queue.isEmpty else { return }
        let updates = queue.values.sorted { $0.timestamp < $1.timestamp }
        queue.removeAll()
        
        for update in updates {
            do {
                if update.isOnline {
                    try await service.setUserOnline(userId: update.userId)
                } else {
                    try await service.setUserOffline(userId: update.userId, delay: 0)
                }
            } catch {
                queue[update.userId] = update // Re-queue if failed
            }
        }
    }
}

// App lifecycle integration
// In NexusAIApp.swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    guard let userId = authViewModel.currentUser?.id else { return }
    
    Task {
        let presenceService = RealtimePresenceService.shared
        
        switch newPhase {
        case .active:
            presenceService.initializePresence(for: userId)
            try await presenceService.setUserOnline(userId: userId)
            
        case .background:
            // iOS background task ensures completion
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            
            try await presenceService.setUserOffline(userId: userId, delay: 0)
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            
        case .inactive:
            break // Don't change presence
        }
    }
}
```

**Why RTDB over Firestore for Presence:**
1. **onDisconnect()** - Server-side callbacks not available in Firestore
2. **Lower latency** - RTDB optimized for real-time updates
3. **No listener limits** - Firestore has 10-user "in" query limit
4. **Connection monitoring** - `.info/connected` node in RTDB
5. **Heartbeat efficiency** - Simple timestamp updates every 30s

**Trade-offs:**
- More complex (two databases instead of one)
- Additional Firebase SDK dependency
- Requires careful sync between RTDB and Firestore

### 5. Singleton Services Pattern
**Purpose:** Global state management, avoid duplication

**Singletons:**
- `FirebaseService.shared` - Firebase configuration
- `PresenceManager.shared` - Global presence state
- `NotificationManager.shared` - Notification handling
- `NetworkMonitor.shared` - Network connectivity

**Why Singletons Here:**
- Firebase needs single initialization
- Presence state is app-wide
- Network status is global
- Notification handling is app-level

**Anti-Pattern Warning:**
Don't overuse singletons. Services like `MessageService`, `ConversationService` should be instantiated (injectable for testing).

### 6. Protocol-Based Dependency Injection
**Purpose:** Enable unit testing with mock implementations, decouple ViewModels from concrete services

**Flow:**
```
1. Define protocol for service (e.g., AuthServiceProtocol)
2. Concrete service conforms to protocol (AuthService)
3. Mock service conforms to protocol (MockAuthService)
4. ViewModel depends on protocol, not concrete type
5. Tests inject mock, production injects real service
```

**Implementation:**
```swift
// Step 1: Define protocol
protocol AuthServiceProtocol {
    func signInWithGoogle() async throws -> User
    func signOut() throws
}

// Step 2: Concrete service conforms
class AuthService: AuthServiceProtocol {
    func signInWithGoogle() async throws -> User {
        // Real Firebase implementation
    }
}

// Step 3: Mock service conforms
class MockAuthService: AuthServiceProtocol {
    var shouldSucceed = true
    var mockUser: User?
    
    func signInWithGoogle() async throws -> User {
        if shouldSucceed, let user = mockUser {
            return user
        }
        throw AuthError.googleSignInFailed("Mock error")
    }
}

// Step 4: ViewModel depends on protocol
class AuthViewModel: ObservableObject {
    private let authService: AuthServiceProtocol
    
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }
}

// Step 5: Testing
let mockService = MockAuthService()
mockService.shouldSucceed = true
mockService.mockUser = User(...)
let viewModel = AuthViewModel(authService: mockService)
```

### 7. Environment Object Propagation
**Purpose:** Share ViewModels across view hierarchy without manual passing

**Flow:**
```
1. Create ViewModel as @StateObject at app level
2. Inject as .environmentObject() to root view
3. Access in child views with @EnvironmentObject
4. SwiftUI automatically provides same instance
```

**Implementation:**
```swift
// App level
@main
struct NexusAIApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

// Child view
struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        Button("Sign In") {
            Task {
                await authViewModel.signIn()
            }
        }
    }
}
```

### 8. Google Sign-In Integration Pattern
**Purpose:** Convert Google OAuth credentials to Firebase Auth credentials

**Flow:**
```
1. Get root view controller (required by GoogleSignIn SDK)
2. Call GIDSignIn.sharedInstance.signIn()
3. Receive GIDGoogleUser with OAuth tokens
4. Create Firebase credential from Google ID token
5. Sign in to Firebase Auth with credential
6. Create/update user profile in Firestore
7. Return User model to ViewModel
```

**Implementation:**
```swift
func signInWithGoogle() async throws -> User {
    // Step 1: Get root view controller
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        throw AuthError.googleSignInFailed("No root view controller")
    }
    
    // Step 2-3: Google Sign-In
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    guard let idToken = result.user.idToken?.tokenString else {
        throw AuthError.googleSignInFailed("No ID token")
    }
    
    // Step 4: Create Firebase credential
    let credential = GoogleAuthProvider.credential(
        withIDToken: idToken,
        accessToken: result.user.accessToken.tokenString
    )
    
    // Step 5: Firebase Auth
    let authResult = try await Auth.auth().signIn(with: credential)
    
    // Step 6: Firestore profile
    return try await createOrUpdateUserInFirestore(firebaseUser: authResult.user)
}
```

## Data Flow Diagrams

### Message Sending Flow
```
User types message
    ↓
MessageInputView
    ↓
ChatViewModel.sendMessage()
    ↓
├─> Add to messages array (optimistic)
│   └─> SwiftUI updates immediately
    ↓
MessageService.sendMessage()
    ↓
├─> Save to MessageQueue (if offline)
│   └─> Retry later
    ↓
└─> Write to Firestore
    └─> Update conversation.lastMessage
        └─> Trigger Cloud Function (notifications)
```

### Real-Time Message Delivery
```
User A sends message
    ↓
Firestore: conversations/{id}/messages
    ↓
Snapshot listener fires
    ↓
User B's MessageService receives update
    ↓
Decode to Message model
    ↓
ChatViewModel.messages published
    ↓
ChatView re-renders
    ↓
New MessageBubbleView appears
```

### Offline Recovery Flow
```
Device goes offline
    ↓
NetworkMonitor detects disconnect
    ↓
User sends 3 messages
    ↓
Each saved to MessageQueue (SwiftData)
    ↓
UI shows "sending" status
    ↓
Device reconnects
    ↓
NetworkMonitor detects connection
    ↓
MessageQueue.flushQueue() triggered
    ↓
Messages sent to Firestore sequentially
    ↓
UI updates to "sent" status
```

## Component Relationships

### Authentication Flow
```
LoginView
    ↓
AuthViewModel
    ↓
AuthService
    ↓
├─> Firebase Auth (authentication)
└─> Firestore users collection (profile)
```

### Chat Flow
```
ConversationListView
    ↓
ConversationListViewModel
    ↓
ConversationService
    ↓
Firestore conversations collection
    ↓
ChatView
    ↓
ChatViewModel
    ↓
├─> MessageService (messages)
├─> PresenceService (typing, online status)
└─> LocalStorageService (caching)
```

## Error Handling Strategy

### Levels of Error Handling

**1. Service Layer:**
- Catch Firebase errors
- Transform to custom error types
- Throw to ViewModel

**2. ViewModel Layer:**
- Catch service errors
- Set `@Published var error: Error?`
- Provide retry methods

**3. View Layer:**
- Display error alerts
- Show retry buttons
- Degrade gracefully (cached data)

**Example:**
```swift
// Service
enum MessageError: LocalizedError {
    case networkFailure
    case unauthorized
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .networkFailure: return "No network connection"
        case .unauthorized: return "Not authorized to send messages"
        case .invalidData: return "Invalid message data"
        }
    }
}

// ViewModel
@Published var error: Error?

func sendMessage(_ text: String) {
    Task {
        do {
            try await messageService.sendMessage(text)
        } catch {
            self.error = error
        }
    }
}

// View
.alert(item: $viewModel.error) { error in
    Alert(
        title: Text("Error"),
        message: Text(error.localizedDescription),
        primaryButton: .default(Text("Retry"), action: viewModel.retrySend),
        secondaryButton: .cancel()
    )
}
```

## Concurrency Patterns

### Swift Concurrency (async/await)
- All Firebase operations use `async throws`
- ViewModels use `Task { }` for async work
- Avoid completion handlers (legacy pattern)

**Example:**
```swift
// Good: Swift Concurrency
func loadConversations() async throws -> [Conversation] {
    let snapshot = try await db.collection("conversations").getDocuments()
    return snapshot.documents.compactMap { try? $0.data(as: Conversation.self) }
}

// Avoid: Completion handlers (legacy)
func loadConversations(completion: @escaping ([Conversation]?, Error?) -> Void) {
    db.collection("conversations").getDocuments { snapshot, error in
        // ...
    }
}
```

### Combine (for real-time streams)
- Use for Firestore listeners
- Transform to `@Published` properties
- Cancel subscriptions on deinit

**Example:**
```swift
private var cancellables = Set<AnyCancellable>()

func startListening() {
    messageService.messagesPublisher(for: conversationId)
        .sink { [weak self] messages in
            self?.messages = messages
        }
        .store(in: &cancellables)
}
```

## Testing Patterns

### Service Testing
- Mock Firestore with in-memory data
- Test success and failure paths
- Verify data transformations

### ViewModel Testing
- Mock services with test implementations
- Verify published state changes
- Test error handling

### UI Testing
- Use Xcode UI Tests for critical flows
- Test optimistic UI updates
- Verify navigation and user actions

## iOS 26 Platform Considerations

### Apple's Versioning Change
**Important:** Apple changed its iOS versioning strategy after iOS 18 to align with macOS and other operating systems. The versioning now matches the year of release:
- **iOS 18** → Last version under old numbering system
- **iOS 26** → Direct successor (released in 2026)
- **Versions 19-25** were skipped to align with the year-based naming scheme

This unified approach ensures version consistency across Apple's ecosystem (iOS, macOS, iPadOS, visionOS, etc.). All Apple operating systems now use matching version numbers.

### SwiftUI Changes in iOS 26

#### ScrollView API Evolution
iOS 26 introduced significant improvements to `ScrollView` control:

1. **Deprecated Patterns:**
   - `.defaultScrollAnchor()` has behavioral inconsistencies
   - May cause unwanted scroll animations on initial load
   - Does not prevent programmatic scrolls from overriding default position

2. **Recommended Patterns:**
   - Use `.scrollPosition(id: Binding<ID?>, anchor: UnitPoint)` for explicit control
   - Apply `.scrollTargetLayout()` to LazyVStack for precise positioning
   - Bind scroll position to @State variable for reactive updates

3. **Common Issues & Solutions:**
   - **Problem:** View scrolls on entry even with anchor set
   - **Solution:** Track `isInitialLoad` state and skip animations during first data load
   - **Problem:** onChange fires during initial message population
   - **Solution:** Guard against initial load in onChange handlers

#### Best Practices for Chat Views
```swift
// Track initial load to prevent unwanted scrolling
@State private var isInitialLoad = true

.onChange(of: messages.count) { old, new in
    if isInitialLoad {
        isInitialLoad = false
        scrollPosition = messages.last?.id
        return // Skip animated scroll
    }
    // Normal scroll behavior for new messages
}
```

### Backward Compatibility
- App targets iOS 26.0+ for deployment
- Minimum supported version is iOS 17.0+
- Use `@available(iOS 26, *)` for iOS 26-specific APIs
- Maintain fallback implementations for older iOS versions

### 9. RAG-Powered Global AI Assistant Pattern (Nexus)
**Purpose:** Answer user questions by semantically searching conversation history and generating informed responses

**Architecture:**
```
User asks question
    ↓
GlobalAIViewModel.sendQuery()
    ↓
RAGService.query() → ragQuery Cloud Function
    ↓
Backend Pipeline:
├── 1. Embed query (text-embedding-3-small)
├── 2. Search Firestore embeddings (cosine similarity)
├── 3. Retrieve top K relevant messages
├── 4. Build augmented prompt:
│   ├── System prompt (Nexus identity)
│   ├── Conversation history (last 10 Q&A pairs)
│   ├── RAG context (relevant messages)
│   └── User question
├── 5. Call GPT-4 with augmented prompt
└── 6. Return answer + sources
    ↓
GlobalAIViewModel processes response
    ↓
UI displays answer with source cards
    ↓
User taps source → Navigate to original message
```

**Key Components:**

**1. Vector Embeddings for Semantic Search:**
```javascript
// Cloud Function: embedNewMessage.js
exports.embedNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    
    // Generate embedding using OpenAI
    const embedding = await openai.embeddings.create({
      model: "text-embedding-3-small",
      input: message.text,
    });
    
    // Store in Firestore
    await admin.firestore().collection("messageEmbeddings").add({
      messageId: event.params.messageId,
      conversationId: event.params.conversationId,
      embedding: embedding.data[0].embedding, // 1536 dimensions
      text: message.text,
      senderId: message.senderId,
      senderName: message.senderName,
      timestamp: message.timestamp,
    });
  }
);
```

**2. Semantic Search with Cosine Similarity:**
```javascript
// Cloud Function: ragSearch.js
function cosineSimilarity(vecA, vecB) {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

exports.ragSearch = onCall(async (request) => {
  const { query, userId, topK = 5 } = request.data;
  
  // 1. Embed the query
  const queryEmbedding = await generateEmbedding(query);
  
  // 2. Fetch user's message embeddings
  const embeddings = await fetchUserEmbeddings(userId);
  
  // 3. Calculate similarity scores
  const scoredMessages = embeddings.map(msg => ({
    ...msg,
    score: cosineSimilarity(queryEmbedding, msg.embedding)
  }));
  
  // 4. Sort by relevance and return top K
  return scoredMessages
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
});
```

**3. RAG Pipeline with Conversation History:**
```javascript
// Cloud Function: ragQuery.js
const NEXUS_SYSTEM_PROMPT = `You are Nexus, an AI assistant...`;

function buildAugmentedPrompt(userQuestion, relevantMessages, conversationHistory) {
  const messages = [
    { role: "system", content: NEXUS_SYSTEM_PROMPT }
  ];
  
  // Add conversation history (last 10 Q&A pairs)
  conversationHistory.slice(-10).forEach(turn => {
    messages.push({ role: "user", content: turn.question });
    messages.push({ role: "assistant", content: turn.answer });
  });
  
  // Add current query with RAG context
  const ragContext = formatRAGContext(relevantMessages);
  messages.push({
    role: "user",
    content: `${ragContext}\n\nUser Question: ${userQuestion}`
  });
  
  return messages;
}

exports.ragQuery = onCall(async (request) => {
  const { question, userId, conversationHistory = [] } = request.data;
  
  // 1. Semantic search
  const searchResults = await ragSearch({ query: question, userId, topK: 5 });
  
  // 2. Build augmented prompt (ALWAYS, even if searchResults is empty)
  const messages = buildAugmentedPrompt(question, searchResults, conversationHistory);
  
  // 3. Generate answer with GPT-4
  const completion = await openai.chat.completions.create({
    model: "gpt-4-turbo-preview",
    messages: messages,
    temperature: 0.7,
  });
  
  const answer = completion.choices[0].message.content;
  
  // 4. Return answer + sources
  return {
    answer: answer,
    sources: searchResults.map(msg => ({
      conversationId: msg.conversationId,
      messageId: msg.messageId,
      excerpt: msg.text.substring(0, 150),
      senderName: msg.senderName,
      timestamp: msg.timestamp,
      relevanceScore: msg.score,
    })),
    queryTime: new Date().toISOString(),
  };
});
```

**4. iOS Client Integration:**
```swift
// RAGService.swift
class RAGService {
    private let functions = Functions.functions()
    
    func query(question: String, conversationHistory: [[String: String]]? = nil) async throws -> RAGResponse {
        let ragQuery = functions.httpsCallable("ragQuery")
        
        let requestData: [String: Any] = [
            "question": question,
            "conversationHistory": conversationHistory ?? []
        ]
        
        let result = try await ragQuery.call(requestData)
        return try processResponse(result)
    }
}

// GlobalAIViewModel.swift
@MainActor
class GlobalAIViewModel: ObservableObject {
    @Published var messages: [ConversationMessage] = []
    private let ragService: RAGService
    
    func sendQuery(_ text: String) {
        // Add user message
        let userMessage = ConversationMessage(content: text, isFromUser: true)
        messages.append(userMessage)
        
        Task {
            do {
                // Build conversation history
                let history = buildConversationHistory()
                
                // Query RAG backend
                let response = try await ragService.query(
                    question: text,
                    conversationHistory: history
                )
                
                // Add AI response with sources
                let aiMessage = ConversationMessage(
                    content: response.answer,
                    isFromUser: false,
                    sources: response.sources
                )
                messages.append(aiMessage)
            } catch {
                // Handle error
            }
        }
    }
    
    private func buildConversationHistory() -> [[String: String]] {
        // Extract last 10 Q&A pairs
        var history: [[String: String]] = []
        for message in messages.suffix(20) {
            if message.isFromUser {
                history.append(["question": message.content])
            } else {
                if var last = history.last, last["question"] != nil {
                    history[history.count - 1]["answer"] = message.content
                }
            }
        }
        return history
    }
}
```

**5. Source Attribution UI:**
```swift
// SourceMessageCard.swift
struct SourceMessageCard: View {
    let source: SourceMessage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Conversation name
                Text(source.conversationName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Message excerpt
                Text(source.excerpt)
                    .font(.subheadline)
                    .lineLimit(3)
                
                HStack {
                    // Sender and timestamp
                    Text(source.senderName)
                    Text("•")
                    Text(source.timestamp.formatted())
                    
                    Spacer()
                    
                    // Relevance score
                    Text("\(Int(source.relevanceScore * 100))% match")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// Navigation logic
func navigateToMessage(conversationId: String, messageId: String) {
    // 1. Switch to Chat tab
    NotificationCenter.default.post(name: .switchToChatTab, object: nil)
    
    // 2. Navigate to conversation and highlight message
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(
            name: .jumpToMessage,
            object: nil,
            userInfo: ["conversationId": conversationId, "messageId": messageId]
        )
    }
}
```

**Trade-offs:**
- **Pro:** Natural language Q&A over entire conversation history
- **Pro:** Semantic search finds relevant messages even with different wording
- **Pro:** Multi-turn conversations with context retention
- **Pro:** Source attribution for transparency
- **Con:** Requires Cloud Functions (deployment complexity)
- **Con:** OpenAI API costs (~$0.01-0.03 per query)
- **Con:** Latency: 2-5 seconds per query (embedding + search + GPT-4)
- **Con:** Embeddings only for new messages (historical messages not embedded)
- **Con:** No real-time updates (embeddings generated on message create)

**Performance Characteristics:**
- Embedding generation: ~200-500ms (text-embedding-3-small)
- Semantic search: ~500-1000ms (Firestore query + cosine similarity)
- GPT-4 generation: ~1-3 seconds (depends on prompt length)
- Total latency: ~2-5 seconds
- Embedding dimensions: 1536
- Top K results: 5 messages
- Conversation history: Last 10 Q&A pairs
- Cost: ~$0.01 (embedding) + $0.02 (GPT-4) = $0.03 per query

**Critical Implementation Notes:**
1. **Always Call GPT-4:** Even when RAG finds zero results, GPT-4 naturally explains limitations
2. **Conversation History:** Passed from client to maintain multi-turn context
3. **Unified System Prompt:** Ensures consistent AI behavior across follow-ups
4. **Error Handling:** Helpful messages instead of generic errors for out-of-scope queries
5. **Cross-Tab Navigation:** Uses NotificationCenter to coordinate tab switching + message jumping

---

### 10. Per-Conversation AI Assistant Pattern
**Purpose:** Provide contextual AI assistance scoped to individual conversations

**Architecture:**
```
User taps brain icon (🧠)
    ↓
AIAssistantView (sheet modal)
    ↓
AIAssistantViewModel
    ↓
├── Build conversation context (messages + participants)
├── Call AIService.sendMessage(prompt, context)
│   ├── Unified system prompt (6 capabilities)
│   └── GPT-4 with conversation context
├── Save user message → AIMessageRepository
├── Get AI response
└── Save AI response → AIMessageRepository
    ↓
Observation pattern updates UI
    ↓
Persistent AI conversation history
```

**Key Components:**

**1. Unified System Prompt (Single Source of Truth):**
```swift
// AIService.swift
private let unifiedSystemPrompt = """
You are an intelligent assistant integrated into a team messaging app called NexusAI...

CORE CAPABILITIES:
1. **Summarization**: Provide concise summaries of conversation threads
2. **Action Item Extraction**: Identify tasks, commitments, and responsibilities
3. **Decision Tracking**: Recognize when decisions are made
4. **Priority Analysis**: Determine urgency based on keywords and context
5. **Deadline Detection**: Extract all time commitments and due dates
6. **Natural Q&A**: Answer questions about the conversation context

CONVERSATION CONTEXT PROVIDED:
- Full message history with participant names
- Participant information and roles
- Conversation metadata and timestamps

RESPONSE GUIDELINES:
- Be concise but thorough
- Use clear formatting: bullet points, numbering, structure
- Reference specific messages or participants when relevant
- If information isn't in the conversation, state that clearly
...
"""
```

**2. AI Message Repository Pattern:**
```swift
// AIMessageRepository.swift
class AIMessageRepository: AIMessageRepositoryProtocol {
    private let database: LocalDatabase
    
    // Save AI or user message
    func saveMessage(text: String, isFromAI: Bool, conversationId: String) async throws {
        let localMessage = LocalAIMessage(
            text: text,
            isFromAI: isFromAI,
            timestamp: Date(),
            conversationId: conversationId
        )
        try database.context.insert(localMessage)
        try database.context.save()
        database.notifyChanges()
    }
    
    // Real-time observation with AsyncStream
    func observeMessages(conversationId: String) -> AsyncStream<[LocalAIMessage]> {
        AsyncStream { continuation in
            let center = NotificationCenter.default
            let observer = center.addObserver(
                forName: LocalDatabase.dataDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task {
                    let messages = try? await self?.fetchMessages(for: conversationId)
                    continuation.yield(messages ?? [])
                }
            }
            
            // Initial fetch
            Task {
                let messages = try? await fetchMessages(for: conversationId)
                continuation.yield(messages ?? [])
            }
            
            continuation.onTermination = { _ in
                center.removeObserver(observer)
            }
        }
    }
}
```

**3. ViewModel with Observation:**
```swift
// AIAssistantViewModel.swift
@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [LocalAIMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let aiService: AIService
    private let repository: AIMessageRepository
    private var observationTask: Task<Void, Never>?
    
    init(conversationId: String) {
        self.conversationId = conversationId
        self.repository = RepositoryFactory.shared.aiMessageRepository
        self.aiService = AIService()
        
        // Start observing messages
        startObservingMessages()
    }
    
    private func startObservingMessages() {
        observationTask = Task { @MainActor in
            let stream = repository.observeMessages(conversationId: conversationId)
            for await messages in stream {
                self.messages = messages
            }
        }
    }
    
    func sendMessage(text: String, conversation: Conversation, messages: [Message]) async {
        // Build context
        let context = aiService.buildConversationContext(
            conversation: conversation,
            messages: messages
        )
        
        // Save user message
        try await repository.saveMessage(text: text, isFromAI: false, conversationId: conversationId)
        
        // Get AI response
        let aiResponse = try await aiService.sendMessage(prompt: text, conversationContext: context)
        
        // Save AI response
        try await repository.saveMessage(text: aiResponse, isFromAI: true, conversationId: conversationId)
    }
}
```

**4. UI with Suggested Prompts:**
```swift
// AIAssistantView.swift
struct AIAssistantView: View {
    @StateObject private var viewModel: AIAssistantViewModel
    let conversation: Conversation?
    let messages: [Message]
    
    private let suggestedPrompts: [SuggestedPrompt] = [
        SuggestedPrompt(
            title: "Summarize thread",
            icon: "doc.text.fill",
            userMessage: "Please provide a concise summary of this conversation..."
        ),
        SuggestedPrompt(
            title: "Extract action items",
            icon: "checklist",
            userMessage: "Extract all action items, tasks, and commitments..."
        ),
        SuggestedPrompt(
            title: "What decisions were made?",
            icon: "checkmark.circle.fill",
            userMessage: "What decisions, agreements, or conclusions were made..."
        ),
        SuggestedPrompt(
            title: "Any deadlines?",
            icon: "calendar",
            userMessage: "Are there any deadlines, due dates, or time-sensitive..."
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    // Suggested prompts (if no messages)
                    if !viewModel.hasMessages {
                        suggestedPromptsView
                    }
                    
                    // Messages
                    ForEach(viewModel.messages) { message in
                        AIMessageBubbleView(message: message)
                    }
                }
                
                // Input bar
                MessageInputView(text: $userInput, onSend: {
                    await viewModel.sendMessage(
                        text: userInput,
                        conversation: conversation,
                        messages: messages
                    )
                })
            }
        }
    }
}
```

**Trade-offs:**
- **Pro:** All 6 AI capabilities in one conversational interface
- **Pro:** Persistent conversation history per chat
- **Pro:** Unified system prompt = consistent behavior
- **Pro:** Repository pattern enables testability
- **Con:** Uses Config.plist (demo only - should be server-side for production)
- **Con:** GPT-4 API costs (~$0.01-0.02 per query)
- **Con:** Latency: 2-3 seconds per query

**Performance Characteristics:**
- Query time: ~2-3 seconds (GPT-4 API call)
- Persistence: <100ms (SwiftData)
- UI updates: Instant (observation pattern)
- Cost: ~$0.01-0.02 per query

**Critical Implementation Notes:**
1. **Unified System Prompt:** All capabilities defined in one place for consistency
2. **Observation Pattern:** Real-time UI updates via AsyncStream
3. **Repository Pattern:** Clean separation between business logic and persistence
4. **Conversation Context:** Full message history passed to GPT-4 for informed responses
5. **Demo API Key:** Uses Config.plist - must move to Cloud Functions for production

**Distinction from Other AI Features:**
- **Per-Conversation AI (🧠):** Analyzes CURRENT conversation only
- **Nexus AI (✨):** Searches across ALL conversations using RAG
- **Action Items (✓):** Extracts structured tasks (same AIService, different method)

---

### 11. AI-Powered Feature Pattern (Action Items)
**Purpose:** Extract structured data from conversations using GPT-4 with JSON parsing

**Architecture:**
```
User triggers extraction
    ↓
ViewModel.extractItems()
    ↓
AIService.extractActionItems()
    ├── Build prompt with conversation context
    ├── Request structured JSON output
    ├── Parse GPT-4 response
    └── Return ActionItem array
    ↓
Repository.save(items)
    ↓
SwiftData persistence
    ↓
Observation stream updates UI
```

**Key Components:**

**1. Structured Prompt Engineering:**
```swift
func buildExtractionPrompt(participantNames: String, messageContext: String) -> String {
    """
    Analyze this conversation and extract action items in STRICT JSON format.
    
    Participants: \(participantNames)
    
    Rules:
    1. Output ONLY a JSON array (no markdown, no explanations)
    2. Match assignee names EXACTLY from participant list
    3. Parse deadlines to ISO8601 format
    4. Determine priority from urgency keywords
    
    JSON Schema:
    [
      {
        "task": "Clear description",
        "assignee": "Exact participant name or null",
        "deadline": "ISO8601 date or null",
        "priority": "high" | "medium" | "low",
        "messageId": "Source message ID"
      }
    ]
    
    Conversation:
    \(messageContext)
    """
}
```

**2. JSON Parsing with Error Handling:**
```swift
struct ActionItemJSON: Codable {
    let task: String
    let assignee: String?
    let deadline: String? // ISO8601
    let priority: String
    let messageId: String
}

func parseActionItems(from jsonString: String, conversationId: String) throws -> [ActionItem] {
    // Strip markdown code blocks
    let cleanedJSON = jsonString
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Parse JSON
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    let jsonItems = try decoder.decode([ActionItemJSON].self, from: Data(cleanedJSON.utf8))
    
    // Convert to ActionItem models
    return jsonItems.map { json in
        ActionItem(
            conversationId: conversationId,
            task: json.task,
            assignee: json.assignee,
            deadline: parseDate(json.deadline),
            priority: Priority(rawValue: json.priority) ?? .medium,
            messageId: json.messageId
        )
    }
}
```

**3. Repository Pattern with Manual Sorting:**
```swift
// SwiftData SortDescriptor doesn't work well with Bool and optional Date
// Implement manual in-memory sorting instead
func fetch(for conversationId: String) async throws -> [ActionItem] {
    let descriptor = FetchDescriptor<LocalActionItem>(
        predicate: #Predicate { $0.conversationId == conversationId }
    )
    let localItems = try database.context.fetch(descriptor)
    
    // Manual sorting: incomplete first, then by deadline, then by extractedAt
    let items = localItems.map { $0.toActionItem() }
    return items.sorted { lhs, rhs in
        // Incomplete items first
        if lhs.isComplete != rhs.isComplete {
            return !lhs.isComplete
        }
        // Then by deadline (items with deadlines first)
        if lhs.deadline != nil && rhs.deadline == nil { return true }
        if lhs.deadline == nil && rhs.deadline != nil { return false }
        if let lhsDeadline = lhs.deadline, let rhsDeadline = rhs.deadline {
            return lhsDeadline < rhsDeadline
        }
        // Finally by extraction time
        return lhs.extractedAt > rhs.extractedAt
    }
}
```

**4. Observation Pattern for Real-Time Updates:**
```swift
// Repository provides AsyncStream for real-time updates
func observeActionItems(for conversationId: String) -> AsyncStream<[ActionItem]> {
    AsyncStream { continuation in
        let center = NotificationCenter.default
        let observer = center.addObserver(
            forName: LocalDatabase.dataDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                let items = try? await self?.fetch(for: conversationId)
                continuation.yield(items ?? [])
            }
        }
        
        // Initial fetch
        Task {
            let items = try? await fetch(for: conversationId)
            continuation.yield(items ?? [])
        }
        
        continuation.onTermination = { _ in
            center.removeObserver(observer)
        }
    }
}

// ViewModel subscribes
private func observeItems() {
    let stream = repository.observeActionItems(for: conversationId)
    Task {
        for await updatedItems in stream {
            self.items = updatedItems
        }
    }
}
```

**5. Lifecycle-Aware ViewModel Management:**
```swift
// ❌ BAD: Creates new ViewModel on every sheet re-evaluation
.sheet(isPresented: $showingActionItems) {
    let viewModel = ActionItemViewModel(conversationId: conversationId)
    ConversationActionItemsSheet(viewModel: viewModel, isPresented: $showingActionItems)
}

// ✅ GOOD: ViewModel initialized once in ChatView init
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var actionItemViewModel: ActionItemViewModel
    
    init(conversationId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
        _actionItemViewModel = StateObject(wrappedValue: ActionItemViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        // ...
        .sheet(isPresented: $showingActionItems) {
            ConversationActionItemsSheet(
                viewModel: actionItemViewModel,  // Reuse same instance
                isPresented: $showingActionItems
            )
        }
        .onChange(of: showingActionItems) { _, isShowing in
            if isShowing {
                actionItemViewModel.setConversationData(
                    messages: viewModel.allMessages,
                    conversation: viewModel.conversation
                )
            }
        }
    }
}
```

**Trade-offs:**
- **Pro:** Structured data from unstructured conversations
- **Pro:** Repository pattern enables testability
- **Pro:** Observation pattern provides real-time updates
- **Con:** GPT-4 API calls cost money and take 2-5 seconds
- **Con:** Manual sorting needed (SwiftData limitations)
- **Con:** JSON parsing can fail if GPT-4 doesn't follow schema

**Performance:**
- Extraction: ~2-5 seconds (GPT-4 API call)
- Parsing: <100ms (JSON decode)
- Persistence: <100ms (SwiftData)
- UI Updates: Instant (observation pattern)

## Future Architectural Considerations

### AI Integration
- ✅ `AIService` layer implemented with GPT-4
- ✅ ViewModels call AIService for action items extraction
- ✅ Structured JSON output with error handling
- 🚧 Future: Add summaries, decision tracking, priority detection

### Modularization
- Extract core messaging into framework
- Separate AI features into module
- Share models between modules

### Multi-Platform
- Keep Models and Services platform-agnostic
- Separate UI layer for each platform
- Share business logic across iOS, Android, Web

