# Nexus MVP - Product Requirements Document

## Executive Summary

**Product Name:** Nexus  
**Target:** Remote Team Professionals  
**Platform:** iOS (Swift + SwiftUI)  
**Backend:** Firebase (Firestore, Auth, Cloud Functions, FCM)  
**Timeline:** 24 hours  
**Goal:** Production-quality messaging infrastructure with real-time sync, offline support, and group chat

---

## MVP Success Criteria (Hard Gates)

### Core Messaging
- ✅ One-on-one chat functionality
- ✅ Real-time message delivery between 2+ users
- ✅ Message persistence (survives app restarts)
- ✅ Optimistic UI updates (instant message appearance)
- ✅ Online/offline status indicators
- ✅ Message timestamps
- ✅ User authentication (email/password)

### Group Features
- ✅ Basic group chat (3+ users)
- ✅ Message read receipts
- ✅ Push notifications (foreground minimum)

### Deployment
- ✅ Running on local simulator with deployed Firebase backend
- ✅ TestFlight build (stretch goal for MVP)

---

## Technical Architecture

### Stack Overview
```
iOS App (Swift)
├── SwiftUI (UI Layer)
├── SwiftData (Local Persistence)
├── Firebase SDK
│   ├── FirebaseAuth
│   ├── FirebaseFirestore
│   └── FirebaseMessaging (FCM)
└── Combine (Reactive Programming)

Backend (Firebase)
├── Firestore (Real-time Database)
├── Firebase Auth
├── Cloud Functions (Future: AI Integration)
└── Firebase Cloud Messaging
```

---

## Database Schema (Firestore)

### Collection: `users`
```json
{
  "userId": "string (auto-generated)",
  "email": "string",
  "displayName": "string",
  "profileImageUrl": "string (optional)",
  "isOnline": "boolean",
  "lastSeen": "timestamp",
  "fcmToken": "string (for push notifications)",
  "createdAt": "timestamp"
}
```

### Collection: `conversations`
```json
{
  "conversationId": "string (auto-generated)",
  "type": "string ('direct' | 'group')",
  "participantIds": ["userId1", "userId2", ...],
  "participants": {
    "userId1": {
      "displayName": "string",
      "profileImageUrl": "string"
    }
  },
  "lastMessage": {
    "text": "string",
    "senderId": "string",
    "timestamp": "timestamp"
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  
  // Group-specific fields
  "groupName": "string (optional)",
  "groupImageUrl": "string (optional)"
}
```

### Collection: `conversations/{conversationId}/messages`
```json
{
  "messageId": "string (auto-generated)",
  "senderId": "string",
  "senderName": "string",
  "text": "string",
  "timestamp": "timestamp",
  "status": "string ('sending' | 'sent' | 'delivered' | 'read')",
  "readBy": ["userId1", "userId2"],
  "deliveredTo": ["userId1", "userId2"],
  "localId": "string (for optimistic updates)"
}
```

### Collection: `typingIndicators`
```json
{
  "conversationId": "string",
  "userId": "string",
  "isTyping": "boolean",
  "timestamp": "timestamp"
}
```

---

## Core Features Breakdown

### 1. Authentication Flow
**Screens:**
- Launch Screen
- Login Screen (email/password)
- Sign Up Screen
- Profile Setup Screen (display name, optional photo)

**Logic:**
- FirebaseAuth email/password authentication
- Store user profile in Firestore `users` collection
- Generate and store FCM token on login
- Set `isOnline: true` on successful auth

---

### 2. Conversation List Screen
**UI Components:**
- Navigation bar with title "Nexus"
- Search bar (filter conversations)
- List of conversations sorted by `updatedAt`
- FAB (Floating Action Button) to start new conversation
- Empty state for new users

**Each Conversation Cell Shows:**
- Profile picture (individual or group)
- Display name or group name
- Last message preview
- Timestamp (smart formatting: "2m", "Yesterday", "12/24")
- Unread badge count
- Online status indicator (for direct chats)
- Read receipt indicator

**Real-time Updates:**
- Listen to Firestore changes on `conversations` where `participantIds` contains current user
- Update UI immediately on new messages
- Sort conversations by most recent activity

---

### 3. Chat Screen (One-on-One)
**UI Components:**
- Navigation bar with recipient name and online status
- Message list (reverse chronological)
- Message input bar with text field and send button
- Typing indicator ("John is typing...")
- Pull-to-refresh for loading older messages

**Message Bubble:**
- Sent messages: Right-aligned, blue background
- Received messages: Left-aligned, gray background
- Sender name (in groups)
- Message text
- Timestamp
- Status indicator (sending/sent/delivered/read)

**Message States:**
- **Sending:** Gray checkmark, message in local DB
- **Sent:** Single checkmark, confirmed by server
- **Delivered:** Double checkmark, received by recipient
- **Read:** Blue double checkmark

**Optimistic UI Updates:**
1. User types message and hits send
2. Message immediately appears in UI with "sending" state
3. Message saved to local SwiftData with temporary `localId`
4. Message sent to Firestore
5. On success, update local message with server `messageId`
6. On failure, show retry option

---

### 4. Group Chat Screen
**Additional Features:**
- Group name in navigation bar
- Sender name above each message bubble
- Participant list view (tap navigation bar)
- Read receipts show "Read by 3/5"

**Group Creation:**
- Select multiple contacts from user list
- Set group name (optional, defaults to participant names)
- Create conversation with `type: 'group'`

---

### 5. Real-Time Sync Logic

**Message Delivery Flow:**
```
User A sends message
    ↓
1. Add to local SwiftData (optimistic UI)
    ↓
2. Write to Firestore conversations/{id}/messages
    ↓
3. Update conversations/{id}/lastMessage
    ↓
4. Firestore triggers Cloud Function (future: AI processing)
    ↓
5. Cloud Function sends FCM notification to User B
    ↓
6. User B's app receives push notification
    ↓
7. User B's app listens to Firestore, message appears
    ↓
8. User B's app updates message status to 'delivered'
    ↓
9. User A sees delivered status update
```

**Firestore Listeners:**
- Conversation list: Listen to all conversations for current user
- Chat screen: Listen to messages in current conversation
- Typing indicators: Listen to typing status (debounced)
- User presence: Listen to participant online status

---

### 6. Offline Support

**Local Persistence (SwiftData):**
- Cache all conversations and messages locally
- On app launch, show cached data immediately
- Sync with Firestore in background

**Offline Message Queue:**
- When offline, messages save to local queue
- Show "sending" state
- On reconnect, flush queue to Firestore
- Handle conflicts (rare, but check timestamp)

**Firestore Offline Persistence:**
```swift
let settings = Firestore.firestore().settings
settings.isPersistenceEnabled = true
Firestore.firestore().settings = settings
```

---

### 7. Push Notifications (FCM)

**Implementation:**
1. Request notification permissions on first launch
2. Store FCM token in user profile
3. Cloud Function triggered on new message:

```javascript
exports.sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = context.params.conversationId;
    
    // Get conversation participants
    const conversationDoc = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .get();
    
    const participants = conversationDoc.data().participantIds;
    const recipientIds = participants.filter(id => id !== message.senderId);
    
    // Get FCM tokens
    const users = await admin.firestore()
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', recipientIds)
      .get();
    
    const tokens = users.docs.map(doc => doc.data().fcmToken);
    
    // Send notification
    await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: {
        title: message.senderName,
        body: message.text
      },
      data: {
        conversationId: conversationId,
        type: 'new_message'
      }
    });
  });
```

---

### 8. Presence & Typing Indicators

**Online/Offline Status:**
- Set `isOnline: true` on app foreground
- Set `isOnline: false` on app background (with 5s grace period)
- Update `lastSeen` timestamp on status change
- Use Firebase Realtime Database for low-latency presence (optional optimization)

**Typing Indicator:**
- On text input change, write to `typingIndicators` collection
- Set 3-second expiration
- Other users listen to typing status
- Show "John is typing..." with animated dots

---

### 9. Read Receipts

**Logic:**
1. When user opens chat screen, mark all messages as read
2. Update each unread message: add userId to `readBy` array
3. Update conversation's unread count for current user
4. Sender sees blue double checkmark when all recipients have read

**Firestore Query:**
```swift
// Mark messages as read
messages
  .where("conversationId", isEqualTo: conversationId)
  .where("readBy", notIn: [currentUserId])
  .get { snapshot in
    snapshot.documents.forEach { doc in
      doc.reference.updateData([
        "readBy": FieldValue.arrayUnion([currentUserId])
      ])
    }
  }
```

---

## SwiftUI Project Structure

```
NexusApp/
├── NexusApp.swift (App entry point)
├── Models/
│   ├── User.swift
│   ├── Conversation.swift
│   ├── Message.swift
│   └── MessageStatus.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ConversationListViewModel.swift
│   ├── ChatViewModel.swift
│   └── PresenceManager.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── ConversationList/
│   │   ├── ConversationListView.swift
│   │   └── ConversationRowView.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubbleView.swift
│   │   ├── MessageInputView.swift
│   │   └── TypingIndicatorView.swift
│   └── Profile/
│       └── ProfileView.swift
├── Services/
│   ├── FirebaseService.swift
│   ├── MessageService.swift
│   ├── NotificationService.swift
│   └── LocalStorageService.swift
├── Utilities/
│   ├── Extensions.swift
│   ├── Constants.swift
│   └── DateFormatter+Extensions.swift
└── Resources/
    ├── GoogleService-Info.plist
    └── Assets.xcassets
```

---

## Build Checklist

### Project Setup
- [ ] Create Xcode project with SwiftUI
- [ ] Install Firebase SDK via SPM
- [ ] Configure Firebase project (Auth, Firestore, FCM)
- [ ] Add `GoogleService-Info.plist`
- [ ] Set up basic navigation structure
- [ ] Configure Firestore security rules

### Authentication
- [ ] Build Login/SignUp UI
- [ ] Implement FirebaseAuth integration
- [ ] Create User model and Firestore sync
- [ ] Store FCM token on login
- [ ] Test auth flow on simulator

### Conversation List
- [ ] Create Conversation model
- [ ] Build ConversationListView UI
- [ ] Implement Firestore listener for conversations
- [ ] Add "New Conversation" flow
- [ ] Implement local caching with SwiftData
- [ ] Test conversation creation between 2 users

### Chat Screen (Core Feature)
- [ ] Build ChatView UI with message bubbles
- [ ] Implement Message model
- [ ] Create MessageService for send/receive
- [ ] Add optimistic UI updates
- [ ] Implement Firestore message listener
- [ ] Add typing indicator logic
- [ ] Test real-time messaging on 2 devices
- [ ] Test offline queuing and sync

### Group Chat & Read Receipts
- [ ] Add group conversation creation flow
- [ ] Implement multi-participant message delivery
- [ ] Add read receipt tracking
- [ ] Update message status indicators
- [ ] Test group chat with 3+ users
- [ ] Test read receipt updates

### Push Notifications & Presence
- [ ] Request notification permissions
- [ ] Deploy Cloud Function for FCM
- [ ] Test foreground notifications
- [ ] Implement presence system (online/offline)
- [ ] Add last seen timestamps
- [ ] Test notifications on background/killed app

### Testing & Polish
- [ ] Test all MVP requirements checklist
- [ ] Test offline scenarios thoroughly
- [ ] Test app lifecycle (background, foreground, force quit)
- [ ] Fix critical bugs
- [ ] Add error handling and loading states
- [ ] Prepare TestFlight build
- [ ] Document setup instructions

---

## Testing Checklist

### Real-Time Messaging
- [ ] Send message from User A → appears on User B instantly
- [ ] Send 20+ rapid messages → all deliver correctly
- [ ] Messages persist after app restart
- [ ] Messages appear in correct order

### Offline Scenarios
- [ ] User A offline → User B sends message → User A comes online → message appears
- [ ] User A sends message while offline → queues → sends on reconnect
- [ ] Airplane mode test: toggle on/off, messages sync

### App Lifecycle
- [ ] Background app → receive notification → tap → opens to correct chat
- [ ] Force quit app → reopen → conversations and messages load
- [ ] Switch between apps rapidly → no data loss

### Group Chat
- [ ] Create group with 3 users
- [ ] All participants see messages in real-time
- [ ] Read receipts show "Read by X/Y"
- [ ] Typing indicators work in group

### Edge Cases
- [ ] Very long message (500+ characters)
- [ ] Send message to user who is offline for 5+ minutes
- [ ] Multiple conversations updating simultaneously
- [ ] User deletes and reinstalls app (cloud sync)

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Conversations: users can only access conversations they're part of
    match /conversations/{conversationId} {
      allow read: if request.auth.uid in resource.data.participantIds;
      allow create: if request.auth.uid in request.resource.data.participantIds;
      allow update: if request.auth.uid in resource.data.participantIds;
      
      // Messages within conversations
      match /messages/{messageId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow create: if request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow update: if request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
      }
    }
    
    // Typing indicators
    match /typingIndicators/{indicatorId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Key Technical Decisions

### Why SwiftData + Firestore?
- SwiftData: Fast local reads, offline-first UX
- Firestore: Real-time sync, multi-device support
- Hybrid approach: Best of both worlds

### Why Optimistic UI?
- WhatsApp-like instant feedback
- Users don't wait for network round-trip
- Critical for messaging app feel

### Why Cloud Functions for Notifications?
- Keep FCM server key secure (not in iOS app)
- Centralized notification logic
- Easier to add AI processing later (post-MVP)

### Why No End-to-End Encryption (Yet)?
- Focus on messaging infrastructure first
- E2EE adds significant complexity
- Can add in post-MVP iterations

---

## Post-MVP: AI Integration Path

After MVP passes, you'll add AI features for Remote Team Professionals:

**Required Features (All 5):**
1. Thread summarization ("Summarize last 50 messages")
2. Action item extraction ("What tasks were mentioned?")
3. Smart search ("Find discussions about Q4 goals")
4. Priority message detection (Flag urgent messages)
5. Decision tracking ("What decisions were made?")

**Advanced Feature (Choose 1):**
- **Option A:** Multi-step agent (Plans team offsites autonomously)
- **Option B:** Proactive assistant (Auto-suggests meeting times)

**AI Architecture:**
- Cloud Functions call OpenAI/Claude API
- Use function calling for tool use
- RAG pipeline: Retrieve relevant messages → Send to LLM → Return structured response
- Add "AI Assistant" chat or contextual UI triggers

---

## Success Metrics

### MVP Success = All These Work:
1. ✅ Two physical devices chatting in real-time
2. ✅ Group chat with 3+ participants working
3. ✅ Offline → online sync without message loss
4. ✅ App force-quit → reopen → data persists
5. ✅ Push notifications received (foreground minimum)
6. ✅ Read receipts updating correctly
7. ✅ Typing indicators showing in real-time
8. ✅ 20+ rapid messages all deliver correctly
9. ✅ Poor network conditions handled gracefully
10. ✅ TestFlight build deployed (or simulator with clear local setup)

---

## Resources & References

**Firebase Setup:**
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firestore Swift Guide](https://firebase.google.com/docs/firestore/quickstart)
- [FCM iOS Integration](https://firebase.google.com/docs/cloud-messaging/ios/client)

**SwiftUI + Combine:**
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)

**Testing:**
- Use 2 physical iPhones for real-world testing
- Network Link Conditioner for poor connection simulation
- Firebase Emulator Suite for local backend testing

---

## Final Notes

**What Makes This MVP Production-Quality:**
1. Messages never get lost (optimistic UI + retry logic)
2. Works offline (local persistence + sync)
3. Feels instant (real-time listeners + optimistic updates)
4. Handles edge cases (app lifecycle, poor network, rapid messages)
5. Scalable architecture (ready for AI features post-MVP)

**The MVP is NOT About:**
- Beautiful UI (functional > pretty at this stage)
- Advanced features (media, voice, video can wait)
- Perfect code (ship fast, refactor later)

**The MVP IS About:**
- Proving your messaging infrastructure is rock-solid
- Demonstrating real-time sync works reliably
- Showing offline scenarios are handled gracefully
- Building foundation for AI features (post-MVP)

Remember: A simple chat app that never loses messages beats a feature-rich app with flaky delivery. Nail the fundamentals first.

---

**You got this. Ship the MVP in 24 hours. 🚀**
