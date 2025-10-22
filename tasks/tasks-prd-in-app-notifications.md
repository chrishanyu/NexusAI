# Task List: In-App Notification Banners

**PRD Reference:** `/tasks/prd-in-app-notifications.md`  
**Branch:** `feature/in-app-notifications`  
**PR:** #13

---

## Relevant Files

### Already Created (Can Reuse)
- `NexusAI/ViewModels/NotificationManager.swift` - ✅ Can reuse for navigation coordination
- `NexusAI/Services/NotificationService.swift` - ⚠️ Not needed (was for FCM)
- `NexusAI/AppDelegate.swift` - ⚠️ Not needed (was for FCM)

### To Be Created
- `NexusAI/Models/BannerData.swift` - Model for banner content
- `NexusAI/Services/NotificationBannerManager.swift` - Manages banner display and Firestore listening
- `NexusAI/Views/Components/NotificationBannerView.swift` - SwiftUI banner component

### To Be Modified
- `NexusAI/NexusAIApp.swift` or `NexusAI/ContentView.swift` - Add banner overlay with ZStack
- `NexusAI/Views/Chat/ChatView.swift` - Track current conversation to filter banners
- `NexusAI/Views/ConversationList/ConversationListView.swift` - Pass banner manager

### Notes

- No Apple Developer account required ✅
- Works perfectly on simulator ✅
- Uses existing Firestore listeners ✅
- Reuses NotificationManager for navigation ✅
- In-app only (app must be in foreground) ℹ️

---

## Tasks

- [x] 1.0 Create Banner Data Model and Manager Service
  - [x] 1.1 Create `Models/BannerData.swift` with properties (conversationId, senderId, senderName, messageText, profileImageUrl, timestamp)
  - [x] 1.2 Add Identifiable and Equatable conformance to BannerData
  - [x] 1.3 Add convenience initializer `init(from message: Message)` to create from Message model
  - [x] 1.4 Create `Services/NotificationBannerManager.swift` as ObservableObject
  - [x] 1.5 Add `@Published var currentBanner: BannerData?` property
  - [x] 1.6 Add `@Published var bannerQueue: [BannerData] = []` property
  - [x] 1.7 Add `var currentConversationId: String?` property to track open conversation
  - [x] 1.8 Add `var currentUserId: String` property (from Auth)
  - [x] 1.9 Add weak reference to NotificationManager for navigation coordination

- [x] 2.0 Implement Firestore Listener for New Messages
  - [x] 2.1 Add `listenForMessages()` method to NotificationBannerManager
  - [x] 2.2 Use `collectionGroup("messages")` to listen across all conversations
  - [x] 2.3 Order by timestamp descending and limit to recent messages
  - [x] 2.4 Add snapshot listener to detect new message additions (`.added` changes)
  - [x] 2.5 Parse message data in listener callback
  - [x] 2.6 Call `handleNewMessage()` for each new message detected
  - [x] 2.7 Add error handling for listener failures
  - [x] 2.8 Start listener when NotificationBannerManager initializes

- [x] 3.0 Implement Banner Filtering and Queue Logic
  - [x] 3.1 Implement `handleNewMessage(_ message: Message)` method
  - [x] 3.2 Filter: Skip if message.senderId == currentUserId (own messages)
  - [x] 3.3 Filter: Skip if message.conversationId == currentConversationId (already in that chat)
  - [x] 3.4 Create BannerData from message
  - [x] 3.5 Implement `showBanner(_ bannerData: BannerData)` method
  - [x] 3.6 If currentBanner is nil, set immediately and show
  - [x] 3.7 If currentBanner exists, add to bannerQueue (max size 3)
  - [x] 3.8 Implement `dismissBanner()` method to clear currentBanner
  - [x] 3.9 When banner dismissed, check queue and show next if available
  - [x] 3.10 Implement `setCurrentConversation(id: String?)` to update filter

- [x] 4.0 Create Banner UI Component
  - [x] 4.1 Create `Views/Components/NotificationBannerView.swift`
  - [x] 4.2 Accept BannerData as parameter
  - [x] 4.3 Layout: HStack with profile picture (40pt circle) on left
  - [x] 4.4 Layout: VStack with sender name (bold, 15pt) and message preview (regular, 13pt)
  - [x] 4.5 Use ProfileImageView component for profile picture (reuse existing if available)
  - [x] 4.6 Truncate message text to 50 characters with "..." if longer
  - [x] 4.7 Style: White background with 0.95 opacity, 12pt corner radius
  - [x] 4.8 Add shadow: .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
  - [x] 4.9 Set frame: height 60pt, maxWidth: .infinity with 16pt horizontal padding
  - [x] 4.10 Position at top with padding(.top, 8) from safe area

- [x] 5.0 Add Banner Animations and Gestures
  - [x] 5.1 Add `.transition(.move(edge: .top).combined(with: .opacity))` to NotificationBannerView
  - [x] 5.2 Wrap banner appearance in `.animation(.spring(response: 0.3, dampingFraction: 0.7))`
  - [x] 5.3 Add tap gesture to entire banner view
  - [x] 5.4 Tap gesture calls `handleBannerTap()` method
  - [x] 5.5 Implement swipe up gesture with DragGesture
  - [x] 5.6 Dismiss banner if swipe translation.height < -50
  - [x] 5.7 Implement auto-dismiss timer (4 seconds) using `Task.sleep`
  - [x] 5.8 Cancel timer if user interacts with banner
  - [x] 5.9 Test animations on different screen sizes

- [x] 6.0 Integrate Banner into App Root
  - [x] 6.1 Decide integration point: NexusApp.swift or ContentView.swift
  - [x] 6.2 Add `@StateObject private var bannerManager = NotificationBannerManager()` 
  - [x] 6.3 Pass NotificationManager reference to BannerManager in init
  - [x] 6.4 Wrap main content in ZStack
  - [x] 6.5 Add VStack overlay for banner at top of ZStack
  - [x] 6.6 Use `if let banner = bannerManager.currentBanner` to conditionally show
  - [x] 6.7 Pass bannerManager as environment object: `.environmentObject(bannerManager)`
  - [x] 6.8 Verify banner appears above all other content

- [x] 7.0 Implement Banner Tap Navigation
  - [x] 7.1 Add `handleBannerTap()` method to NotificationBannerManager
  - [x] 7.2 Get conversationId from currentBanner
  - [x] 7.3 Call NotificationManager's `navigateToConversation(conversationId:)` method
  - [x] 7.4 Call `dismissBanner()` immediately after navigation triggered
  - [x] 7.5 Test: Tap banner → navigates to correct conversation
  - [x] 7.6 Verify banner dismisses immediately on tap

- [x] 8.0 Track Current Conversation to Filter Banners
  - [x] 8.1 Update ChatView to accept bannerManager as environment object
  - [x] 8.2 Add `.onAppear { bannerManager.setCurrentConversation(id: conversationId) }`
  - [x] 8.3 Add `.onDisappear { bannerManager.setCurrentConversation(id: nil) }`
  - [x] 8.4 Test: Open conversation with Alice → Alice sends message → No banner
  - [x] 8.5 Test: Open conversation with Alice → Bob sends message → Banner appears
  - [x] 8.6 Test: Leave conversation → Banners work again for that conversation

- [ ] 9.0 Test All Scenarios
  - [ ] 9.1 Test: ConversationListView open → New message → Banner appears
  - [ ] 9.2 Test: ChatView open (Alice) → Bob sends message → Banner appears
  - [ ] 9.3 Test: ChatView open (Alice) → Alice sends message → No banner
  - [ ] 9.4 Test: User sends own message → No banner
  - [ ] 9.5 Test: Banner auto-dismisses after 4 seconds
  - [ ] 9.6 Test: Tap banner → Navigates to conversation
  - [ ] 9.7 Test: Swipe up banner → Dismisses immediately
  - [ ] 9.8 Test: Multiple rapid messages → Banners queue correctly
  - [ ] 9.9 Test: Long message text → Truncates with "..."
  - [ ] 9.10 Test: Different screen sizes (iPhone SE, Pro Max)
  - [ ] 9.11 Verify animations are smooth
  - [ ] 9.12 Verify no console errors or warnings

