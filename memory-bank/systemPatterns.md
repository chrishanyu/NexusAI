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

### 9. AI-Powered Feature Pattern (Action Items)
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

