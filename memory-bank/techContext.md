# Technical Context

## Technology Stack

### Frontend (iOS)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Reactive Programming:** Combine
- **Local Persistence:** SwiftData
- **Architecture:** MVVM (Model-View-ViewModel)
- **Authentication:** Google Sign-In SDK + Firebase Auth
- **Target iOS Version:** iOS 26.0+ (current deployment)
- **Minimum iOS Version:** iOS 17.0+ (backward compatibility)
- **Development Tool:** Xcode 15+

#### iOS Versioning Note
Apple changed its iOS versioning strategy after iOS 18 to align with macOS and other operating systems. The versioning now matches the year of release, which is why iOS 26 (released in 2026) was the direct successor to iOS 18. This unified approach ensures version consistency across Apple's ecosystem (iOS, macOS, iPadOS, visionOS, etc.).

### Backend (Firebase)
- **Authentication:** Firebase Auth (Google Sign-In)
- **Database:** Cloud Firestore (NoSQL, real-time)
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Cloud Functions:** Node.js (for notification triggers, future AI integration)
- **Storage:** Firebase Storage (post-MVP for media)

### Development Environment
- **macOS:** 14.0+ (Sonoma or later)
- **Xcode:** 15.0+
- **Package Manager:** Swift Package Manager (SPM)
- **Version Control:** Git
- **Testing:** iOS Simulator (TestFlight/physical device post-MVP)

## Key Dependencies

### Swift Packages (via SPM)
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.18.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
]

// Specific Firebase products:
- FirebaseAuth
- FirebaseFirestore
- FirebaseFirestoreSwift
- FirebaseMessaging
- FirebaseCore

// Google Sign-In:
- GoogleSignIn
- GoogleSignInSwift
```

### Firebase Project Configuration
- **Project ID:** [Configured in GoogleService-Info.plist]
- **Region:** us-central1 (Firestore)
- **Authentication Methods:** Google Sign-In
- **Firestore Mode:** Native mode with offline persistence
- **URL Schemes:** Configured with REVERSED_CLIENT_ID for OAuth callback

## Architecture Patterns

### MVVM Structure
```
View (SwiftUI)
    ↕ ObservableObject + @Published
ViewModel (Business Logic)
    ↕ Async/Await + Combine
Service (Firebase/Local Storage)
    ↕ 
Model (Data Structures)
```

### Key Design Patterns
1. **Repository Pattern:** Services abstract Firebase/local storage
2. **Singleton Services:** FirebaseService, PresenceManager, NotificationManager
3. **Optimistic UI:** Instant local updates, background sync
4. **Observer Pattern:** Firestore snapshot listeners
5. **Message Queue:** Offline-first architecture

## Data Flow

### Message Sending (Optimistic UI)
```
1. User types → MessageInputView
2. ChatViewModel.sendMessage()
3. Create local Message with localId, status: .sending
4. Update UI immediately (optimistic)
5. MessageService.sendMessage()
6. Write to Firestore
7. On success: Update message with Firestore ID, status: .sent
8. On failure: Show retry option
```

### Real-Time Sync
```
1. Firestore snapshot listener in MessageService
2. New message detected
3. Decode to Message model
4. Merge with local messages (dedupe by localId)
5. ChatViewModel updates @Published messages array
6. SwiftUI re-renders MessageBubbleView
```

### Offline Queue
```
1. NetworkMonitor detects offline
2. Messages save to MessageQueueService
3. Queue persisted in SwiftData
4. NetworkMonitor detects online
5. MessageQueueService flushes queue
6. Messages sent to Firestore
7. UI updates on confirmation
```

## Database Schema (Firestore)

### Collections Structure
```
users/
  {userId}/
    - email, displayName, profileImageUrl
    - isOnline, lastSeen
    - fcmToken (for notifications)
    - createdAt

conversations/
  {conversationId}/
    - type: "direct" | "group"
    - participantIds: [userId1, userId2, ...]
    - participants: { userId: { displayName, profileImageUrl } }
    - lastMessage: { text, senderId, senderName, timestamp }
    - groupName, groupImageUrl (if group)
    - createdAt, updatedAt
    
    messages/
      {messageId}/
        - conversationId, senderId, senderName
        - text, timestamp
        - status: "sending" | "sent" | "delivered" | "read"
        - readBy: [userId1, ...]
        - deliveredTo: [userId1, ...]
        - localId (optional, for optimistic UI)

typingIndicators/
  {indicatorId}/
    - conversationId, userId
    - isTyping: boolean
    - timestamp (expires after 3s)
```

### Indexes Required
```javascript
// Composite indexes in Firestore
- conversations: participantIds (array-contains), updatedAt (desc)
- messages: conversationId, timestamp (desc)
- typingIndicators: conversationId, timestamp
```

## Security Rules (Firestore)

```javascript
// Users: read all authenticated, write own only
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}

// Conversations: access only if participant
match /conversations/{conversationId} {
  allow read: if request.auth.uid in resource.data.participantIds;
  allow create: if request.auth.uid in request.resource.data.participantIds;
  allow update: if request.auth.uid in resource.data.participantIds;
  
  match /messages/{messageId} {
    allow read, create, update: if request.auth.uid in 
      get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
  }
}

// Typing indicators: authenticated users only
match /typingIndicators/{indicatorId} {
  allow read, write: if request.auth != null;
}
```

## Technical Decisions & Rationale

### Why SwiftData + Firestore Hybrid?
- **SwiftData:** Fast local reads, instant UI, works offline
- **Firestore:** Real-time sync, multi-device, cloud backup
- **Hybrid:** Best of both - offline-first with cloud sync

### Why Optimistic UI?
- **User Experience:** Messages feel instant (WhatsApp-like)
- **Perceived Performance:** No waiting for network
- **Critical for Messaging:** Users expect instant feedback

### Why Firestore over Realtime Database?
- **Better Querying:** Complex queries, compound indexes
- **Offline Persistence:** Built-in, automatic
- **Scaling:** Auto-scaling, better for large datasets
- **Modern SDK:** Better Swift support

### Why Google Sign-In (Not Email/Password)?
- **User Experience:** Single unified authentication flow
- **Security:** No password management, leverages Google's infrastructure
- **Convenience:** Most users already have Google accounts
- **Data Quality:** Automatically get email, display name, and profile photo
- **MVP Focus:** Simpler flow for users, no password reset or email verification needed

### Why Cloud Functions for Notifications?
- **Security:** FCM server key not in iOS app
- **Scalability:** Handles notification logic server-side
- **Future AI:** Same infrastructure for AI processing
- **Reliability:** Firebase manages infrastructure

## Performance Considerations

### Optimizations
1. **Message Pagination:** Load 50 messages initially, more on scroll
2. **Lazy Loading:** Conversations load participants on-demand
3. **Debounced Typing:** 500ms delay before Firestore write
4. **Cached Queries:** Firestore caches queries automatically
5. **SwiftUI Optimizations:** Use `@State`, `@Published` correctly

### Network Efficiency
- **Firestore Offline Mode:** Reduces redundant network calls
- **Listener Management:** Detach listeners when views disappear
- **Batch Writes:** Update multiple fields in single transaction
- **Compression:** Firestore handles automatically

### Known Limitations
1. **Firestore Costs:** Reads/writes charged per operation
2. **Real-time Limits:** Max 1M concurrent connections per database
3. **Message Size:** Firestore document max 1MB
4. **SwiftData:** Only local, no cloud sync
5. **Simulator Testing:** Push notifications need .apns files

## Testing Strategy

### MVP Testing Approach
- **Unit Tests:** Core service logic (MessageService, ConversationService)
- **Integration Tests:** Firestore read/write operations
- **UI Tests:** Key user flows (login, send message, create group)
- **Manual Testing:** Real-time sync, offline scenarios, app lifecycle

### Testing Scenarios
1. **Real-Time Messaging:** 2 simulators, verify instant delivery
2. **Offline Sync:** Airplane mode on/off, verify queue flush
3. **App Lifecycle:** Background/foreground/force quit, verify persistence
4. **Group Chat:** 3+ participants, verify message delivery
5. **Edge Cases:** Long messages, rapid sends, poor network

### Notification Testing (Simulator)
- Create `.apns` files with notification payloads
- Drag onto simulator to test notification handling
- Verify navigation to correct conversation
- Test foreground, background, and killed states

## Development Workflow

### Setup New Dev Environment
```bash
1. Clone repo
2. Open NexusAI.xcodeproj in Xcode
3. Add GoogleService-Info.plist from Firebase Console
4. Select development team in Signing & Capabilities
5. Build and run (Cmd+R)
```

### Branch Strategy
- `main` - stable, production-ready code
- `feature/*` - new features (per PRs in building-phases.md)
- `bugfix/*` - bug fixes
- `hotfix/*` - critical production fixes

### Code Style
- Swift style guide (standard Apple conventions)
- SwiftLint for linting (optional, not required for MVP)
- Clear variable names, minimal comments
- MVVM separation strictly enforced

## Future Technical Considerations

### AI Integration (Post-MVP)
- **LLM API:** OpenAI GPT-4 or Anthropic Claude
- **RAG Pipeline:** Vector database (Pinecone/Chroma) for message embeddings
- **Function Calling:** LLM triggers actions (create tasks, schedule meetings)
- **Cloud Functions:** Process messages, call LLM APIs, return structured data

### Scalability Path
- **Message Archiving:** Move old messages to cold storage
- **Read Replicas:** Use Firestore read replicas for scaling
- **CDN:** Use Firebase Hosting + CDN for assets
- **Microservices:** Split Cloud Functions by domain

### Multi-Platform
- **Android:** Kotlin + Jetpack Compose (similar architecture)
- **Web:** React/Vue + Firestore JS SDK
- **Desktop:** Electron or Swift for macOS

## Troubleshooting Guide

### Common Issues
1. **Firestore Offline:** Check `settings.isPersistenceEnabled = true`
2. **Listeners Not Triggering:** Verify Firestore rules, check auth state
3. **Message Duplicates:** Check localId deduplication logic
4. **Notifications Not Showing:** Verify UNUserNotificationCenter delegate
5. **Build Errors:** Clean build folder (Cmd+Shift+K), restart Xcode

### Firebase Console URLs
- **Authentication:** `https://console.firebase.google.com/project/[PROJECT_ID]/authentication`
- **Firestore:** `https://console.firebase.google.com/project/[PROJECT_ID]/firestore`
- **Cloud Functions:** `https://console.firebase.google.com/project/[PROJECT_ID]/functions`

## References

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firestore Swift SDK](https://firebase.google.com/docs/firestore/quickstart)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

