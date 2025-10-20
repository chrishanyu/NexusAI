# Nexus MVP - PR Breakdown

## Project File Structure

```
Nexus/
├── Nexus.xcodeproj
├── Nexus/
│   ├── NexusApp.swift
│   ├── Info.plist
│   ├── GoogleService-Info.plist
│   │
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── MessageStatus.swift
│   │   └── TypingIndicator.swift
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── ConversationListViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── PresenceManager.swift
│   │   └── NotificationManager.swift
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── ProfileSetupView.swift
│   │   │
│   │   ├── ConversationList/
│   │   │   ├── ConversationListView.swift
│   │   │   ├── ConversationRowView.swift
│   │   │   └── NewConversationView.swift
│   │   │
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── MessageBubbleView.swift
│   │   │   ├── MessageInputView.swift
│   │   │   ├── TypingIndicatorView.swift
│   │   │   └── MessageStatusView.swift
│   │   │
│   │   ├── Group/
│   │   │   ├── CreateGroupView.swift
│   │   │   ├── GroupInfoView.swift
│   │   │   └── ParticipantListView.swift
│   │   │
│   │   └── Components/
│   │       ├── ProfileImageView.swift
│   │       ├── OnlineStatusIndicator.swift
│   │       └── LoadingView.swift
│   │
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── AuthService.swift
│   │   ├── MessageService.swift
│   │   ├── ConversationService.swift
│   │   ├── NotificationService.swift
│   │   ├── PresenceService.swift
│   │   ├── LocalStorageService.swift
│   │   └── MessageQueueService.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   │   ├── Date+Extensions.swift
│   │   │   ├── String+Extensions.swift
│   │   │   └── View+Extensions.swift
│   │   ├── Constants.swift
│   │   └── NetworkMonitor.swift
│   │
│   └── Resources/
│       └── Assets.xcassets/
│           ├── AppIcon.appiconset/
│           ├── Colors/
│           └── Images/
│
├── firebase/
│   ├── functions/
│   │   ├── package.json
│   │   ├── index.js
│   │   └── src/
│   │       ├── notifications.js
│   │       └── utils.js
│   │
│   ├── firestore.rules
│   └── firebase.json
│
├── .gitignore
└── README.md
```

---

## PR Checklist

### **PR #1: Project Setup & Firebase Configuration**
**Branch:** `feature/project-setup`

Initialize Xcode project with SwiftUI, add Firebase SDK via SPM, configure Firebase services (Auth, Firestore, FCM), set up folder structure, create Firestore security rules, and add initial documentation.

**Key Files:**
- `NexusApp.swift`
- `GoogleService-Info.plist`
- `firebase/firestore.rules`
- `.gitignore`
- `README.md`

---

### **PR #2: Core Models & Constants**
**Branch:** `feature/core-models`

Define all data models (User, Conversation, Message, MessageStatus, TypingIndicator) with Codable conformance. Create app constants file with Firestore collection names, colors, and configuration. Add date formatting extensions for smart timestamp display.

**Key Files:**
- `Models/User.swift`
- `Models/Conversation.swift`
- `Models/Message.swift`
- `Models/MessageStatus.swift`
- `Models/TypingIndicator.swift`
- `Utilities/Constants.swift`
- `Utilities/Extensions/Date+Extensions.swift`

---

### **PR #3: Firebase Services Layer**
**Branch:** `feature/firebase-services`

Create service layer for all Firebase interactions: FirebaseService singleton, AuthService for authentication, ConversationService for conversation CRUD, MessageService for messaging operations, PresenceService for online/offline status, and LocalStorageService using SwiftData for local persistence.

**Key Files:**
- `Services/FirebaseService.swift`
- `Services/AuthService.swift`
- `Services/ConversationService.swift`
- `Services/MessageService.swift`
- `Services/PresenceService.swift`
- `Services/LocalStorageService.swift`

---

### **PR #4: Authentication Flow**
**Branch:** `feature/authentication`

Build complete authentication system with AuthViewModel, LoginView, SignUpView, and ProfileSetupView. Implement email/password authentication with Firebase, input validation, error handling, and user profile storage in Firestore. Update app navigation to show login or conversation list based on auth state.

**Key Files:**
- `ViewModels/AuthViewModel.swift`
- `Views/Auth/LoginView.swift`
- `Views/Auth/SignUpView.swift`
- `Views/Auth/ProfileSetupView.swift`
- `NexusApp.swift` (navigation logic)

---

### **PR #5: Conversation List Screen**
**Branch:** `feature/conversation-list`

Build conversation list screen with ConversationListViewModel, ConversationListView, and ConversationRowView. Implement real-time Firestore listeners, search/filter functionality, pull-to-refresh, and empty states. Create reusable components for profile images and online status indicators. Add new conversation flow.

**Key Files:**
- `ViewModels/ConversationListViewModel.swift`
- `Views/ConversationList/ConversationListView.swift`
- `Views/ConversationList/ConversationRowView.swift`
- `Views/ConversationList/NewConversationView.swift`
- `Views/Components/ProfileImageView.swift`
- `Views/Components/OnlineStatusIndicator.swift`

---

### **PR #6: Chat Screen UI**
**Branch:** `feature/chat-ui`

Create chat screen UI components: ChatView, MessageBubbleView, MessageInputView, MessageStatusView, and TypingIndicatorView. Style message bubbles with proper alignment for sent/received messages. Add navigation from conversation list to chat screen. Implement scroll-to-bottom functionality.

**Key Files:**
- `ViewModels/ChatViewModel.swift` (basic structure)
- `Views/Chat/ChatView.swift`
- `Views/Chat/MessageBubbleView.swift`
- `Views/Chat/MessageInputView.swift`
- `Views/Chat/MessageStatusView.swift`
- `Views/Chat/TypingIndicatorView.swift`

---

### **PR #7: Message Sending & Optimistic UI**
**Branch:** `feature/message-sending`

Implement message sending with optimistic UI updates. Messages appear instantly in UI with "sending" status, then update to "sent" after Firestore confirmation. Add message queue for offline scenarios with retry logic. Create network monitor utility. Handle send errors gracefully with retry options.

**Key Files:**
- `Services/MessageService.swift` (sendMessage implementation)
- `Services/MessageQueueService.swift`
- `ViewModels/ChatViewModel.swift` (optimistic UI logic)
- `Utilities/NetworkMonitor.swift`

---

### **PR #8: Real-Time Message Sync**
**Branch:** `feature/realtime-messages`

Add Firestore snapshot listeners for real-time message delivery. Implement message listening in MessageService and ChatViewModel. Merge local optimistic messages with Firestore messages. Add auto-scroll on new messages and pull-to-refresh for loading older messages with pagination.

**Key Files:**
- `Services/MessageService.swift` (listenToMessages)
- `ViewModels/ChatViewModel.swift` (listener subscription)
- `Views/Chat/ChatView.swift` (scroll and refresh logic)

---

### **PR #9: Typing Indicators**
**Branch:** `feature/typing-indicators`

Implement typing indicators with Firestore. Add debounced typing detection (500ms delay, 3s expiration). Display animated "Name is typing..." indicator in chat screen. Create typing indicator cleanup logic to remove expired indicators.

**Key Files:**
- `Services/MessageService.swift` (setTyping, listenToTypingIndicators)
- `ViewModels/ChatViewModel.swift` (typing state)
- `Views/Chat/MessageInputView.swift` (trigger typing)
- `Views/Chat/TypingIndicatorView.swift` (animation)

---

### **PR #10: Read Receipts & Message Status**
**Branch:** `feature/read-receipts`

Implement read receipts by updating `readBy` array when user opens chat. Add message status tracking: sending → sent → delivered → read. Update MessageStatusView with checkmark icons (single, double, blue double). Display unread badge counts in conversation list.

**Key Files:**
- `Services/MessageService.swift` (markMessagesAsRead, updateMessageStatus)
- `ViewModels/ChatViewModel.swift` (mark as read on view appear)
- `Views/Chat/MessageStatusView.swift` (status icons)
- `Services/ConversationService.swift` (unread count)
- `Views/ConversationList/ConversationRowView.swift` (unread badge)

---

### **PR #11: Online Presence System**
**Branch:** `feature/presence-system`

Create PresenceManager to track online/offline status and last seen timestamps. Update user presence on app foreground/background with 5-second grace period. Listen to participant presence in chat screen. Display online status in navigation bar and conversation list.

**Key Files:**
- `ViewModels/PresenceManager.swift`
- `Services/PresenceService.swift`
- `NexusApp.swift` (app lifecycle listeners)
- `ViewModels/ChatViewModel.swift` (presence listening)
- `Views/Chat/ChatView.swift` (status display)
- `Views/Components/OnlineStatusIndicator.swift`

---

### **PR #12: Group Chat Functionality**
**Branch:** `feature/group-chat`

Add group chat creation with CreateGroupView for multi-selecting participants. Create GroupInfoView and ParticipantListView. Update MessageBubbleView to show sender names in group chats. Implement group-specific read receipts ("Read by 3/5"). Add group creation logic to ConversationService.

**Key Files:**
- `Views/Group/CreateGroupView.swift`
- `Views/Group/GroupInfoView.swift`
- `Views/Group/ParticipantListView.swift`
- `Services/ConversationService.swift` (createGroupConversation)
- `Views/Chat/MessageBubbleView.swift` (sender name display)
- `Views/Chat/MessageStatusView.swift` (group read receipts)

---

### **PR #13: Push Notifications - iOS**
**Branch:** `feature/push-notifications`

Implement iOS push notifications with Firebase Cloud Messaging. Request notification permissions, register device for notifications, store FCM token in user profile. Handle notification taps to navigate to correct chat. Add AppDelegate for notification delegation.

**Key Files:**
- `ViewModels/NotificationManager.swift`
- `Services/NotificationService.swift`
- `AppDelegate.swift`
- `NexusApp.swift` (notification handling)
- `Services/AuthService.swift` (FCM token storage)

---

### **PR #14: Cloud Functions for Notifications**
**Branch:** `feature/cloud-functions`

Deploy Firebase Cloud Functions to send push notifications. Create function triggered on new messages that fetches recipient FCM tokens and sends notifications. Add error handling and logging. Configure Firebase project for Functions.

**Key Files:**
- `firebase/functions/package.json`
- `firebase/functions/index.js`
- `firebase/functions/src/notifications.js`
- `firebase/functions/src/utils.js`
- `firebase/firebase.json`

---

### **PR #15: Offline Support & Message Queue**
**Branch:** `feature/offline-support`

Enable Firestore offline persistence for local caching. Implement message queue that stores messages when offline and flushes on reconnect. Add network status monitoring. Display cached data on app launch. Show offline indicator in UI.

**Key Files:**
- `Services/FirebaseService.swift` (offline persistence)
- `Services/MessageQueueService.swift` (queue and flush)
- `Services/LocalStorageService.swift` (local cache)
- `Utilities/NetworkMonitor.swift` (network status)
- `ViewModels/ConversationListViewModel.swift` (cached data)
- `ViewModels/ChatViewModel.swift` (offline handling)

---

### **PR #16: Error Handling & Loading States**
**Branch:** `feature/error-handling`

Add comprehensive error handling to all ViewModels and Services. Create LoadingView component. Add loading states to auth, conversation list, and chat screens. Implement error alerts with retry options. Add timeout handling for network requests.

**Key Files:**
- `Views/Components/LoadingView.swift`
- `Utilities/Extensions/View+Extensions.swift` (error alerts)
- All ViewModel files (error handling)
- All Service files (error catching)

---

### **PR #17: UI Polish & Styling**
**Branch:** `feature/ui-polish`

Improve UI aesthetics with custom color scheme, animations, and haptic feedback. Add app icon. Polish message bubbles and conversation rows. Add smooth transitions and animations. Test dark mode appearance. Improve empty states with better messaging.

**Key Files:**
- `Utilities/Constants.swift` (color scheme)
- `Resources/Assets.xcassets/Colors/`
- `Resources/Assets.xcassets/AppIcon.appiconset/`
- `Views/Chat/MessageBubbleView.swift` (styling)
- `Views/Chat/MessageInputView.swift` (haptics)
- `Views/ConversationList/ConversationRowView.swift` (polish)

---

### **PR #18: Final Testing & Bug Fixes**
**Branch:** `feature/final-testing`

Comprehensive testing across all MVP requirements: real-time messaging on multiple devices, rapid message sending, offline scenarios, app lifecycle handling, group chat, read receipts, typing indicators, and push notifications. Fix discovered bugs and optimize performance. Prepare TestFlight build.

**Testing Scenarios:**
- Two devices real-time messaging
- 20+ rapid messages
- Offline/online sync
- App background/foreground/force quit
- Group chat with 3+ users
- Poor network conditions
- All notification scenarios

---

## Build Order Recommendation

**Phase 1 - Foundation (PRs 1-3):**
Get project set up with Firebase and core data models.

**Phase 2 - Authentication (PR 4):**
Build auth flow so you can test with real users.

**Phase 3 - Core Messaging (PRs 5-8):**
Build conversation list and basic chat with real-time sync. This is the heart of your MVP.

**Phase 4 - Enhanced Messaging (PRs 9-10):**
Add typing indicators and read receipts.

**Phase 5 - Presence & Groups (PRs 11-12):**
Add online status and group chat functionality.

**Phase 6 - Notifications (PRs 13-14):**
Implement push notifications with Cloud Functions.

**Phase 7 - Reliability (PR 15):**
Add offline support and message queuing.

**Phase 8 - Polish (PRs 16-18):**
Error handling, UI polish, and comprehensive testing.

---

## Critical Path

**Must-Have for MVP Pass:**
- PRs 1-8 (Project setup through real-time messaging)
- PR 10 (Read receipts)
- PR 12 (Group chat)
- PR 13-14 (Push notifications)
- PR 15 (Offline support)

**Important but Can Be Simplified:**
- PR 9 (Typing indicators - nice to have)
- PR 11 (Presence - can be basic)
- PR 16 (Error handling - can be basic)
- PR 17 (UI polish - function over form)

**Focus on:** Making messages reliably deliver in real-time, work offline, and sync properly. Everything else is secondary.
