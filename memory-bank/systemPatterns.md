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

**Example:**
```swift
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    
    var body: some View {
        VStack {
            MessageListView(messages: viewModel.messages)
            MessageInputView(onSend: viewModel.sendMessage)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
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

### 4. Presence Management Pattern
**Purpose:** Track online/offline status, typing indicators

**Flow:**
```
1. App enters foreground → Set isOnline: true
2. App enters background → Wait 5s → Set isOnline: false
3. Update lastSeen timestamp
4. Chat screen listens to participant presence
5. Display online indicator in UI
```

**Implementation:**
```swift
// In PresenceManager
func updatePresence(_ isOnline: Bool) {
    guard let userId = Auth.auth().currentUser?.uid else { return }
    
    Task {
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }
}

// In App Delegate / Scene Delegate
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    PresenceManager.shared.updatePresence(true)
}
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        PresenceManager.shared.updatePresence(false)
    }
}
```

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

## Future Architectural Considerations

### AI Integration
- Add `AIService` layer
- ViewModels call AIService for summaries, action items
- AIService uses Cloud Functions + LLM APIs
- Return structured data to ViewModels

### Modularization
- Extract core messaging into framework
- Separate AI features into module
- Share models between modules

### Multi-Platform
- Keep Models and Services platform-agnostic
- Separate UI layer for each platform
- Share business logic across iOS, Android, Web

