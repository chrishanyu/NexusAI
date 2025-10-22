# PRD: In-App Notification Banners - PR #13

## Introduction/Overview

Implement custom in-app notification banners that appear at the top of the screen when a new message arrives in a different conversation while the user has the app open. This provides immediate notification feedback without requiring Apple Developer account, APNs configuration, or physical devices.

**Problem:** Users with the app open need to know when new messages arrive in conversations they're not currently viewing. Without push notifications (which require Apple Developer account), users miss messages from other conversations.

**Goal:** Display elegant, tappable notification banners at the top of the screen when messages arrive in background conversations, providing instant awareness and quick navigation without leaving the app.

**Scope:** This PRD covers PR #13 from the building phases, implementing in-app notification banners that work on simulator and don't require APNs setup. Real FCM push notifications (for backgrounded/killed app states) will be added post-MVP once Apple Developer account is available.

---

## Goals

1. **Real-Time In-App Alerts:** Show banner when message arrives in a different conversation
2. **Rich Notification Content:** Display sender name, message preview, and profile picture
3. **Quick Navigation:** Tap banner to navigate directly to that conversation
4. **Auto-Dismiss:** Banner disappears after 4 seconds if not interacted with
5. **Elegant Animations:** Smooth slide-down and slide-up transitions
6. **Non-Intrusive:** Doesn't block UI, can be swiped away
7. **Works Everywhere:** Appears on any screen (conversation list, chat, settings, etc.)

---

## User Stories

### As a User in a Conversation
- **Story 1:** While I'm chatting with Alice, if Bob sends me a message, I want to see a banner at the top so I know Bob messaged me
- **Story 2:** I want to tap the banner to quickly switch to Bob's conversation without losing my place
- **Story 3:** If I'm focused on my current chat, I want the banner to auto-dismiss so it doesn't stay in the way

### As a User on Conversation List
- **Story 4:** While browsing my conversation list, if a new message arrives, I want to see a banner with the sender and message preview
- **Story 5:** I want to tap the banner to open that conversation immediately

### As a User Browsing the App
- **Story 6:** No matter what screen I'm on, I want to see notification banners for new messages
- **Story 7:** I want to swipe the banner up to dismiss it manually if I don't want to respond right away

---

## Functional Requirements

### FR-1: Banner Trigger Logic

1. The app SHALL listen to new messages across all conversations via Firestore
2. A banner SHALL appear when a new message is received where:
   - The sender is NOT the current user
   - The message's conversationId is DIFFERENT from the currently open conversation (if any)
   - The app is in the foreground (active state)
3. The banner SHALL NOT appear for:
   - Messages sent by the current user
   - Messages in the currently open conversation (already visible)
   - Messages received when app is backgrounded (requires FCM - post-MVP)
4. If multiple messages arrive rapidly, each SHALL trigger a separate banner (queue-based)

### FR-2: Banner Content & Design

5. The banner SHALL display:
   - Profile picture (left side, circular, 40pt diameter)
   - Sender's display name (bold, primary text color)
   - Message preview (first 50 characters, secondary text color)
   - Conversation type indicator (optional: "in Group Name" for groups)
6. The banner SHALL have:
   - White/adaptive background with subtle shadow
   - 16pt padding on all sides
   - Rounded corners (12pt radius)
   - 60pt height (enough for 2 lines of text)
7. The banner SHALL be positioned:
   - At the top of the screen below the status bar
   - Horizontally centered with 16pt margins on left/right
   - Above all other UI content (z-index priority)

### FR-3: Banner Animations

8. **Appear Animation:**
   - Slides down from top over 0.3 seconds
   - Uses spring animation with slight bounce
9. **Disappear Animation:**
   - Slides up and fades out over 0.25 seconds
   - Smooth ease-out timing
10. **Swipe Gesture:**
   - User can swipe up to manually dismiss
   - Requires minimum 50pt swipe distance
   - Animates dismissal on swipe release

### FR-4: Banner Interactions

11. **Tap Action:**
    - Tapping anywhere on the banner navigates to that conversation
    - Banner dismisses immediately on tap
    - Navigation uses the existing NavigationPath system
12. **Auto-Dismiss:**
    - Banner automatically dismisses after 4 seconds if not interacted with
    - Timer starts when banner appears
    - Timer cancels if user interacts with banner
13. **Manual Dismiss:**
    - Swipe up gesture dismisses banner
    - Tap X button (optional) dismisses banner

### FR-5: Banner Queue Management

14. If multiple banners arrive while one is showing:
    - Queue subsequent banners
    - Show next banner after previous dismisses
    - Maximum queue size of 3 (drop oldest if exceeded)
15. If user navigates to a queued conversation before its banner shows:
    - Remove that banner from queue
    - Don't show banner for conversation user is now viewing

### FR-6: Technical Implementation

16. The banner SHALL be implemented as a custom SwiftUI View
17. The banner SHALL use ZStack overlay at the app root level (NexusApp or ContentView)
18. A NotificationBannerManager (ObservableObject) SHALL:
    - Listen to all message changes via Firestore
    - Determine if a banner should show
    - Manage banner queue and display state
    - Track currently open conversation to filter
19. Banner state SHALL be published to trigger UI updates
20. The implementation SHALL use `.transition()` and `.animation()` modifiers

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in PR #13:

1. **System Push Notifications:** No notifications when app is backgrounded/killed (requires Apple Developer account - post-MVP)
2. **Lock Screen Notifications:** App must be open to see banners
3. **Notification Sounds:** In-app banners are silent (visual only)
4. **Notification Badges:** No app icon badge count (requires APNs)
5. **Notification History:** No log of past banners shown
6. **Rich Media:** No images/videos in banner (text only)
7. **Action Buttons:** No quick reply or action buttons in banner
8. **Custom Banner Styles:** Single consistent design (no per-conversation customization)
9. **Notification Settings:** No per-conversation muting or preferences

---

## Design Considerations

### Banner Visual Design

**Layout:**
```
┌─────────────────────────────────────────────┐
│  👤  Alice Johnson                          │
│      Hey, can you review the document?      │
└─────────────────────────────────────────────┘
```

**Dimensions:**
- Width: Screen width - 32pt (16pt margins on each side)
- Height: 60pt
- Top position: Safe area top + 8pt
- Background: White with 0.95 opacity + shadow
- Corner radius: 12pt
- Shadow: 0px 2px 8px rgba(0,0,0,0.15)

**Typography:**
- Sender name: 15pt, bold, primary text color
- Message preview: 13pt, regular, secondary text color
- Max 1 line for name, 1 line for message (truncate with "...")

**Profile Picture:**
- 40pt x 40pt circular image
- Left-aligned with 12pt padding from banner edge
- Fallback to initials if no image

### Animation Specifications

**Slide Down (Appear):**
```swift
.transition(.move(edge: .top).combined(with: .opacity))
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: showBanner)
```

**Slide Up (Dismiss):**
```swift
.transition(.move(edge: .top).combined(with: .opacity))
.animation(.easeOut(duration: 0.25), value: showBanner)
```

**Swipe Gesture:**
```swift
.gesture(
    DragGesture()
        .onEnded { value in
            if value.translation.height < -50 {
                dismissBanner()
            }
        }
)
```

---

## Technical Considerations

### Architecture

**New Components:**

1. **NotificationBannerManager.swift** (ViewModel/Service)
   - `@Published var currentBanner: BannerData?`
   - `@Published var bannerQueue: [BannerData] = []`
   - `var currentConversationId: String?` (to filter)
   - `func listenForMessages()` - Firestore listener
   - `func showBanner(message:)` - Add to queue/show
   - `func dismissBanner()` - Dismiss current
   - `func setCurrentConversation(id:)` - Update filter

2. **NotificationBannerView.swift** (SwiftUI View)
   - Displays banner content
   - Handles tap gesture
   - Handles swipe gesture
   - Shows profile picture, name, message

3. **BannerData.swift** (Model)
   - `conversationId: String`
   - `senderId: String`
   - `senderName: String`
   - `messageText: String`
   - `profileImageUrl: String?`
   - `timestamp: Date`

### Integration Points

**Update NexusApp.swift or ContentView:**
```swift
@StateObject private var bannerManager = NotificationBannerManager()

var body: some View {
    ZStack {
        // Main content
        ConversationListView()
            .environmentObject(bannerManager)
        
        // Banner overlay
        VStack {
            if let banner = bannerManager.currentBanner {
                NotificationBannerView(banner: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        bannerManager.handleBannerTap()
                    }
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bannerManager.currentBanner != nil)
    }
}
```

**Update ChatView:**
```swift
.onAppear {
    bannerManager.setCurrentConversation(id: conversationId)
}
.onDisappear {
    bannerManager.setCurrentConversation(id: nil)
}
```

### Firestore Listener

```swift
func listenForMessages() {
    db.collectionGroup("messages")
        .order(by: "timestamp", descending: true)
        .limit(to: 1)
        .addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documentChanges else { return }
            
            for change in documents where change.type == .added {
                let message = try? change.document.data(as: Message.self)
                self.handleNewMessage(message)
            }
        }
}

func handleNewMessage(_ message: Message?) {
    guard let message = message else { return }
    
    // Filter: don't show banner for own messages
    guard message.senderId != currentUserId else { return }
    
    // Filter: don't show banner for currently open conversation
    guard message.conversationId != currentConversationId else { return }
    
    // Show banner
    let bannerData = BannerData(from: message)
    showBanner(bannerData)
}
```

---

## Success Metrics

### Functional Success
- ✅ Banner appears when new message arrives in different conversation
- ✅ Banner shows sender name and message preview
- ✅ Tapping banner navigates to correct conversation
- ✅ Banner auto-dismisses after 4 seconds
- ✅ Banner can be swiped up to dismiss manually
- ✅ No banner for messages in currently open conversation
- ✅ No banner for user's own messages
- ✅ Multiple banners queue correctly
- ✅ Animations are smooth and elegant

### User Experience Success
- ✅ Banner is visually appealing and on-brand
- ✅ Banner doesn't block critical UI elements
- ✅ Banner provides enough information to be useful
- ✅ Tap target is large enough (entire banner)
- ✅ Auto-dismiss timing feels right (not too fast, not too slow)

---

## Testing Checklist

### Banner Display
- [ ] Open app and login
- [ ] Open conversation with Alice (Device A)
- [ ] Send message from Bob (Device B or Firestore console)
- [ ] Verify banner appears at top of screen
- [ ] Verify banner shows Bob's name and message text
- [ ] Verify banner auto-dismisses after 4 seconds

### Banner Interaction
- [ ] Banner appears for new message
- [ ] Tap banner → navigates to that conversation
- [ ] Banner appears for new message
- [ ] Swipe banner up → dismisses immediately

### Filtering Logic
- [ ] User is viewing conversation with Alice
- [ ] Alice sends a message
- [ ] Verify NO banner appears (already in that conversation)
- [ ] Bob sends a message
- [ ] Verify banner DOES appear (different conversation)

### Multiple Messages
- [ ] Rapidly send 3 messages from different senders
- [ ] Verify banners queue and show sequentially
- [ ] Each banner displays correct sender/message

### Edge Cases
- [ ] Send message from ConversationListView → banner appears
- [ ] Send message from SettingsView → banner appears
- [ ] User's own message → no banner
- [ ] Very long message text → truncates with "..."

---

## Acceptance Criteria

### Must Have
- [ ] NotificationBannerManager created with Firestore listener
- [ ] NotificationBannerView created with proper styling
- [ ] BannerData model created
- [ ] Banner appears for messages in different conversations
- [ ] Banner filters out current conversation's messages
- [ ] Banner filters out user's own messages
- [ ] Tap banner navigates to conversation
- [ ] Banner auto-dismisses after 4 seconds
- [ ] Slide-down animation works smoothly
- [ ] Slide-up animation works smoothly

### Should Have
- [ ] Swipe up gesture to dismiss
- [ ] Banner queue for multiple messages
- [ ] Profile picture displayed in banner
- [ ] Message text truncates elegantly
- [ ] Banner has subtle shadow for depth

### Nice to Have
- [ ] Queue size limit (max 3)
- [ ] Subtle haptic feedback on tap
- [ ] Sound effect on banner appear (optional)
- [ ] Custom banner for group messages ("John in Team Chat")

---

## Implementation Steps

### Phase 1: Create Banner Components
1. Create `BannerData.swift` model
2. Create `NotificationBannerManager.swift` service
3. Create `NotificationBannerView.swift` UI component
4. Test basic banner display (hardcoded data)

### Phase 2: Integrate Firestore Listener
5. Add collectionGroup listener to NotificationBannerManager
6. Implement message filtering logic
7. Test banner triggers on new messages
8. Verify filtering works correctly

### Phase 3: Add Banner to App Root
9. Integrate NotificationBannerManager in NexusApp or ContentView
10. Add ZStack overlay for banner display
11. Pass environment object to child views
12. Test banner appears globally

### Phase 4: Implement Navigation
13. Add tap gesture handler in NotificationBannerView
14. Trigger navigation via NotificationManager (reuse existing)
15. Test navigation from banner tap
16. Verify banner dismisses after navigation

### Phase 5: Polish & Animations
17. Implement slide-down animation
18. Implement slide-up animation
19. Add swipe gesture for manual dismiss
20. Implement auto-dismiss timer (4 seconds)
21. Test animations on different screen sizes

---

## Dependencies & Prerequisites

### Must Be Complete Before Starting
- ✅ **PR #5-8:** Conversation list and chat screens exist for navigation
- ✅ **PR #7:** Message sending works (to trigger banners)
- ✅ **Notification Infrastructure:** NotificationManager exists (can reuse for navigation)

### What's New in This PR
- ❌ NotificationBannerManager (NEW)
- ❌ NotificationBannerView (NEW)
- ❌ BannerData model (NEW)
- ❌ Firestore collectionGroup listener (NEW)
- ❌ Banner display logic and filtering (NEW)

---

**Last Updated:** October 22, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PR #13 - In-App Notification Banners  
**Branch:** `feature/in-app-notifications`

---

**Priority:** 🟡 MEDIUM-HIGH - Enhances UX, works without Apple Developer account  
**Complexity:** ⭐⭐⭐ Medium (3/5)  
**Estimated Effort:** 2-3 hours

---

## Future Enhancement: Real Push Notifications

**Post-MVP (Once Apple Developer Account Available):**
- Implement FCM token registration
- Deploy Cloud Functions for notification delivery
- Add APNs configuration
- Test on physical devices
- Real push notifications for backgrounded/killed app states

**See:** `/tasks/prd-push-notifications-fcm-FUTURE.md` for full FCM implementation details.

