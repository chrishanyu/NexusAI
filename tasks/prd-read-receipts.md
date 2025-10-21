# PRD: Read Receipts & Message Status - PR #10

## Introduction/Overview

Implement comprehensive read receipt functionality to show users when their messages have been read by recipients. This includes tracking message status transitions (sending → sent → delivered → read), displaying visual status indicators, and showing unread message counts in the conversation list.

**Problem:** Users currently see basic message status (sending/sent/delivered) but cannot tell if recipients have actually read their messages. This creates uncertainty and requires users to guess whether their messages have been seen.

**Goal:** Implement WhatsApp-style read receipts that give users confidence that their messages have been read, while providing clear visual feedback through status icons and unread badges.

**Scope:** This PRD covers PR #10 from the building phases, building on the basic message status infrastructure already in place from PRs #5-8.

---

## Goals

1. **Read Tracking:** Automatically mark messages as read when a user views them in a chat
2. **Status Indicators:** Display clear visual indicators for all message states (sending/sent/delivered/read)
3. **Unread Counts:** Show accurate unread message counts on conversation rows
4. **Real-Time Updates:** Read receipts update in real-time across all participants' devices
5. **Privacy Respect:** Follow messaging app conventions (read receipts are mutual - if you see them, others see yours)
6. **Group Chat Support:** Handle read receipts appropriately in group conversations (future PR #12)

---

## User Stories

### As a Message Sender (Direct Chat)
- **Story 1:** I want to see when my message has been read so I know the recipient saw it
- **Story 2:** I want to see double blue checkmarks when a message is read so I can distinguish read from delivered
- **Story 3:** I want read receipts to update in real-time so I get immediate feedback
- **Story 4:** I want to see timestamps showing when messages were read (future enhancement)

### As a Message Recipient (Direct Chat)
- **Story 5:** I want my read messages to automatically mark as read when I open a chat so I don't have to manually mark them
- **Story 6:** I want unread message counts to update when I read messages so my conversation list stays accurate
- **Story 7:** I want the conversation list to show unread badges so I know which conversations need attention

### As a User Managing Conversations
- **Story 8:** I want to see unread message counts on conversation rows so I can prioritize which chats to open
- **Story 9:** I want unread counts to clear when I open and view a conversation
- **Story 10:** I want the app to remember what I've read across app restarts so counts don't reset

### As a Group Chat User (PR #12 dependency)
- **Story 11:** I want to see "Read by X/Y" indicators in group chats so I know how many people have seen my message
- **Story 12:** I want to tap read receipts to see which specific group members have read a message

---

## Functional Requirements

### FR-1: Mark Messages as Read

#### Auto-Read on Chat Open
1. When a user opens a chat screen (ChatView appears), the system SHALL identify all unread messages
2. The system SHALL filter for messages where:
   - `senderId` is NOT the current user
   - Current user's ID is NOT in the `readBy` array
3. The system SHALL call `MessageService.markMessagesAsRead()` with the list of unread message IDs
4. The system SHALL update each message's `readBy` array in Firestore using `FieldValue.arrayUnion([currentUserId])`
5. The update SHALL happen asynchronously without blocking UI
6. The system SHALL update message status to `.read` if all participants have read the message

#### Read Receipt Propagation
7. When a message's `readBy` array is updated, Firestore listeners SHALL trigger for all participants
8. The sender's ChatViewModel SHALL receive the updated message with `readBy` array
9. The system SHALL determine if status should change to `.read`:
   - Direct chat: When recipient's ID is in `readBy`
   - Group chat (PR #12): When all recipients' IDs are in `readBy`
10. The UI SHALL update message status indicators in real-time

### FR-2: Message Status Indicators

#### Status Icon Display
11. The MessageStatusView component SHALL display status icons based on message status:
    - **Sending:** Single gray clock icon (⏱︎)
    - **Sent:** Single gray checkmark (✓)
    - **Delivered:** Double gray checkmarks (✓✓)
    - **Read:** Double blue checkmarks (✓✓ in blue)
12. Status icons SHALL be 12pt SF Symbols
13. Status icons SHALL only appear on messages sent by the current user
14. Status icons SHALL appear in the bottom-right corner of message bubbles

#### Status Transitions
15. Message status SHALL follow this progression:
    - `.sending` → `.sent` (when Firestore confirms write)
    - `.sent` → `.delivered` (when recipient's device receives message via listener)
    - `.delivered` → `.read` (when recipient opens chat and views message)
16. Status SHALL never regress (e.g., read cannot go back to delivered)
17. Failed messages SHALL show `.failed` status with retry button

#### Visual Design
18. Gray checkmarks SHALL use `Color.secondary` or equivalent
19. Blue checkmarks SHALL use `Color.blue` or `#007AFF` (iOS blue)
20. Icons SHALL have subtle opacity (0.7-0.8) for non-read states
21. Read status (blue checkmarks) SHALL have full opacity (1.0)

### FR-3: Unread Message Counts

#### Count Calculation
22. The ConversationService SHALL track unread message count per conversation
23. Unread count SHALL be calculated as:
    - Number of messages where `senderId != currentUserId` AND `currentUserId NOT IN readBy`
24. The system SHALL query Firestore for unread counts when loading conversations
25. The system SHALL update unread counts in real-time as messages are sent/read

#### Conversation Model Update
26. The Conversation model SHALL include an `unreadCount: Int` property
27. The system SHALL calculate unread count on the client side (not stored in Firestore)
28. ConversationListViewModel SHALL compute unread counts for each conversation

#### Unread Badge Display
29. ConversationRowView SHALL display an unread badge when `unreadCount > 0`
30. The badge SHALL be a red circle with white text
31. The badge SHALL display:
    - The actual count (1-99) if count ≤ 99
    - "99+" if count > 99
32. The badge SHALL be positioned to the right of the conversation row
33. The badge SHALL have a minimum size of 20pt diameter
34. The badge SHALL expand horizontally for 2+ digit numbers

#### Badge Clear Behavior
35. When a user opens a chat, unread count SHALL update to 0 after messages are marked as read
36. The badge SHALL disappear with a subtle fade animation
37. Unread count SHALL persist across app restarts (calculated from Firestore data)

### FR-4: Read Status Updates

#### Update Trigger
38. The system SHALL mark messages as read in the following scenarios:
    - ChatView `.onAppear()` - mark all unread messages
    - ChatView returns to foreground (if app was backgrounded)
    - New messages arrive while ChatView is visible
39. The system SHALL NOT mark messages as read if:
    - User is viewing a different chat
    - App is in background
    - User has scrolled far up and new message is off-screen

#### Batch Updates
40. The system SHALL batch read receipt updates to minimize Firestore writes
41. When marking multiple messages as read, the system SHALL use a single batch write
42. The system SHALL debounce rapid mark-as-read calls (e.g., 500ms delay)

#### Error Handling
43. If marking messages as read fails, the system SHALL retry silently
44. Failed read receipt updates SHALL NOT block chat functionality
45. The system SHALL log errors but not show user-facing error messages for read receipt failures

### FR-5: Delivered Status (Enhancement)

#### Delivered Logic
46. When a message arrives via Firestore listener, the system SHALL update `deliveredTo` array
47. The system SHALL call `MessageService.markMessageAsDelivered()` with message ID and user ID
48. The system SHALL use `FieldValue.arrayUnion([currentUserId])` to update `deliveredTo`
49. This update SHALL happen automatically in the background

#### Status Display
50. The sender SHALL see double gray checkmarks when message is delivered
51. The system SHALL check if current user is in `deliveredTo` array to determine delivered status
52. Delivered status SHALL not require the recipient to open the chat (just receive via listener)

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in PR #10:

1. **Read Receipt Timestamps:** Not showing "Read at 2:34 PM" (future enhancement)
2. **Disable Read Receipts:** No privacy setting to turn off read receipts (future enhancement)
3. **Typing Indicators:** Handled separately in PR #9
4. **Group Read Receipt Details:** "Read by 3/5" and member lists handled in PR #12
5. **Read Receipt Notifications:** No push notifications when someone reads your message
6. **Last Seen Timestamps:** "Last seen 2h ago" not part of read receipts
7. **Screenshot Detection:** Not tracking if recipient screenshots messages
8. **Read Receipt Revocation:** Cannot "unread" a message once read
9. **Selective Read Receipts:** Cannot mark specific messages as read/unread manually

---

## Design Considerations

### Message Status Icons

#### Visual Style
- **Clock (Sending):** Use SF Symbol "clock.fill"
- **Single Check (Sent):** Use SF Symbol "checkmark"
- **Double Check (Delivered):** Use SF Symbol "checkmark.checkmark" or custom double checkmark
- **Double Blue Check (Read):** Same icon with blue color

#### Positioning
- Icons in bottom-right of message bubble
- 4pt padding from bubble edge
- Aligned with timestamp (optional: show timestamp on tap)

### Unread Badge Design

#### Visual Style
- Red background: `Color.red` or `#FF3B30` (iOS red)
- White text: semibold, 12pt font
- Circular shape for single digits
- Rounded rectangle for multi-digit
- 20pt minimum height, 20pt minimum width
- 6pt padding horizontal

#### Animation
- Badge appears with scale animation (0.5 → 1.0)
- Badge disappears with fade animation (1.0 → 0.0)
- Count updates with smooth number transition

### Accessibility

#### VoiceOver
- Status icons SHALL have descriptive labels:
  - "Sending" / "Sent" / "Delivered" / "Read"
- Unread badge SHALL announce: "X unread messages"
- Conversation rows SHALL include unread count in label

#### Dynamic Type
- Status icons scale with accessibility font sizes
- Unread badge text scales appropriately

---

## Technical Considerations

### Architecture

#### Service Methods

**MessageService:**
```swift
// Mark messages as read
func markMessagesAsRead(messageIds: [String], conversationId: String, userId: String) async throws

// Mark single message as delivered
func markMessageAsDelivered(messageId: String, conversationId: String, userId: String) async throws

// Get unread message count
func getUnreadCount(conversationId: String, userId: String) async throws -> Int
```

**ConversationService:**
```swift
// Calculate unread counts for conversations
func getUnreadCounts(conversationIds: [String], userId: String) async throws -> [String: Int]
```

#### ViewModel Updates

**ChatViewModel:**
```swift
@Published var unreadMessageIds: [String] = []

func markVisibleMessagesAsRead() async {
    let unreadMessages = messages.filter { 
        $0.senderId != currentUserId && !$0.readBy.contains(currentUserId) 
    }
    guard !unreadMessages.isEmpty else { return }
    
    try? await messageService.markMessagesAsRead(
        messageIds: unreadMessages.map { $0.id },
        conversationId: conversationId,
        userId: currentUserId
    )
}
```

**ConversationListViewModel:**
```swift
@Published var conversationUnreadCounts: [String: Int] = [:]

func calculateUnreadCounts() async {
    for conversation in conversations {
        let count = try? await messageService.getUnreadCount(
            conversationId: conversation.id,
            userId: currentUserId
        )
        await MainActor.run {
            conversationUnreadCounts[conversation.id] = count ?? 0
        }
    }
}
```

### Data Model Updates

#### Message Model
```swift
struct Message: Codable, Identifiable {
    // ... existing fields
    var readBy: [String] = []           // User IDs who have read this message
    var deliveredTo: [String] = []      // User IDs who have received this message
    
    // Computed property for status
    var status: MessageStatus {
        if readBy.contains(where: { $0 != senderId }) {
            return .read
        } else if deliveredTo.contains(where: { $0 != senderId }) {
            return .delivered
        } else if id != nil {
            return .sent
        } else {
            return .sending
        }
    }
}
```

#### Conversation Model Enhancement
```swift
struct Conversation: Codable, Identifiable {
    // ... existing fields
    
    // Not stored in Firestore, calculated on client
    var unreadCount: Int {
        get { _unreadCount }
        set { _unreadCount = newValue }
    }
    
    private var _unreadCount: Int = 0
}
```

### Firestore Queries

#### Unread Count Query
```swift
let unreadQuery = db.collection("conversations")
    .document(conversationId)
    .collection("messages")
    .whereField("senderId", isNotEqualTo: currentUserId)
    .whereField("readBy", notArrayContains: currentUserId)

let snapshot = try await unreadQuery.getDocuments()
let unreadCount = snapshot.documents.count
```

#### Batch Read Update
```swift
let batch = db.batch()

for messageId in messageIds {
    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
    
    batch.updateData([
        "readBy": FieldValue.arrayUnion([userId])
    ], forDocument: messageRef)
}

try await batch.commit()
```

### Performance Considerations

1. **Batch Updates:** Mark multiple messages as read in single batch write
2. **Debouncing:** Debounce mark-as-read calls to avoid excessive writes
3. **Client-Side Calculation:** Calculate unread counts on client to avoid Firestore queries
4. **Caching:** Cache unread counts in ConversationListViewModel
5. **Lazy Loading:** Only calculate unread counts for visible conversations

### Real-Time Sync

1. **Firestore Listeners:** Existing message listeners automatically receive `readBy` updates
2. **UI Updates:** ChatViewModel updates status indicators when `readBy` array changes
3. **Conversation List:** ConversationListViewModel recalculates unread counts on message updates

---

## Success Metrics

### Functional Success
- ✅ Messages automatically mark as read when user opens chat
- ✅ Read status (blue checkmarks) displays for read messages
- ✅ Unread badges show correct counts on conversation list
- ✅ Unread badges clear when user opens and views conversation
- ✅ Read receipts update in real-time across devices
- ✅ Status indicators show correct states (sending/sent/delivered/read)
- ✅ Delivered status updates when recipient receives message
- ✅ Unread counts persist across app restarts

### Technical Success
- ✅ Batch writes used for marking multiple messages as read
- ✅ No excessive Firestore reads/writes from read receipts
- ✅ Read receipt updates don't block chat functionality
- ✅ Failed read receipt updates retry silently
- ✅ Unread count queries are efficient

### User Experience Success
- ✅ Status icons are clear and distinguishable
- ✅ Blue checkmarks appear instantly when message is read
- ✅ Unread badges are visually prominent
- ✅ Badge animations are smooth (appear/disappear)
- ✅ VoiceOver accessibility works correctly
- ✅ Status indicators don't clutter message bubbles

---

## Acceptance Criteria

### Must Have
- [ ] Messages automatically mark as read when ChatView appears
- [ ] Read status updates `readBy` array in Firestore
- [ ] Status icons display correctly:
  - [ ] Clock for "sending"
  - [ ] Single checkmark for "sent"
  - [ ] Double gray checkmarks for "delivered"
  - [ ] Double blue checkmarks for "read"
- [ ] Status icons only show on sent messages (not received)
- [ ] Unread badge displays on conversation rows when count > 0
- [ ] Unread badge shows correct count (1-99 or "99+")
- [ ] Unread badge clears when user opens conversation
- [ ] Read receipts update in real-time (sender sees blue checks when recipient reads)
- [ ] Delivered status updates when message received via listener
- [ ] Batch writes used for marking multiple messages as read
- [ ] Unread counts persist across app restarts
- [ ] Read receipt failures handled silently (no user-facing errors)

### Should Have
- [ ] Badge appears/disappears with smooth animation
- [ ] Status icons have appropriate opacity (0.7-0.8 for non-read)
- [ ] Read status (blue) has full opacity (1.0)
- [ ] VoiceOver announces status correctly
- [ ] Debouncing prevents excessive Firestore writes
- [ ] Unread counts calculated efficiently (client-side)

### Nice to Have
- [ ] Status icon tap shows detailed timestamp (future)
- [ ] Unread count updates with animated number transition
- [ ] Haptic feedback when unread badge clears
- [ ] "Mark all as read" gesture (future)

---

## Implementation Notes for Developers

### Key Files to Create

**None** - All files already exist, just need updates

### Key Files to Modify

1. **`Services/MessageService.swift`**
   - Add `markMessagesAsRead()` method
   - Add `markMessageAsDelivered()` method (already partially implemented)
   - Add `getUnreadCount()` query method
   - Implement batch write for read receipts

2. **`Services/ConversationService.swift`**
   - Add `getUnreadCounts()` method
   - Update conversation listener to trigger unread count recalculation

3. **`ViewModels/ChatViewModel.swift`**
   - Add `markVisibleMessagesAsRead()` method
   - Call mark-as-read on `.onAppear()`
   - Call mark-as-read when new messages arrive while chat is visible
   - Update status computation logic

4. **`ViewModels/ConversationListViewModel.swift`**
   - Add `@Published var conversationUnreadCounts: [String: Int]`
   - Add `calculateUnreadCounts()` method
   - Update unread counts when conversations update
   - Pass unread counts to ConversationRowView

5. **`Views/Chat/MessageStatusView.swift`**
   - Update to show 4 status states (currently shows 3)
   - Add double blue checkmark for read status
   - Ensure proper opacity for each state

6. **`Views/Chat/ChatView.swift`**
   - Add `.onAppear { viewModel.markVisibleMessagesAsRead() }`
   - Add `.onReceive(scenePhasePublisher)` to mark as read on foreground

7. **`Views/ConversationList/ConversationRowView.swift`**
   - Add unread badge display (red circle with count)
   - Position badge to the right of row
   - Show badge only when `unreadCount > 0`
   - Add badge animations

8. **`Models/Message.swift`**
   - Verify `readBy` and `deliveredTo` arrays exist
   - Add computed property for dynamic status if needed

9. **`Models/Conversation.swift`**
   - Add `unreadCount` property (not stored in Firestore)
   - Add setter/getter for unread count

### Implementation Steps

#### Phase 1: Message Read Tracking (Core)
1. Update `MessageService.markMessagesAsRead()` with batch write
2. Update `ChatViewModel` to call mark-as-read on appear
3. Test that `readBy` array updates in Firestore
4. Verify real-time updates work (sender sees update)

#### Phase 2: Status Indicators (Visual)
5. Update `MessageStatusView` with 4 states
6. Add blue color for read status
7. Update `MessageBubbleView` to use updated status view
8. Test status transitions in UI

#### Phase 3: Unread Counts (Conversation List)
9. Implement `getUnreadCount()` query in MessageService
10. Add unread count calculation to ConversationListViewModel
11. Add unread badge to ConversationRowView
12. Test badge display and clearing

#### Phase 4: Delivered Status Enhancement
13. Verify `markMessageAsDelivered()` is called in ChatViewModel
14. Update status computation to check `deliveredTo` array
15. Test delivered status display

#### Phase 5: Polish & Optimization
16. Add badge animations
17. Implement debouncing for mark-as-read
18. Add VoiceOver labels
19. Performance testing with many unread messages

### Testing Scenarios

#### Read Receipts
1. **Two-device test:**
   - User A sends message to User B
   - User A sees gray checkmarks (delivered)
   - User B opens chat
   - User A sees blue checkmarks (read)

2. **Batch read:**
   - User B receives 10 messages while offline
   - User B opens chat
   - All 10 messages mark as read in batch
   - User A sees all 10 turn blue

3. **Real-time:**
   - User B is in chat
   - User A sends message
   - User B receives message
   - User A immediately sees blue checkmarks (auto-read)

#### Unread Counts
1. **Badge display:**
   - User B receives 5 new messages
   - Conversation list shows "5" badge
   - User B opens conversation
   - Badge disappears

2. **Count accuracy:**
   - User B receives 150 messages
   - Badge shows "99+"
   - User B opens chat
   - Badge clears

3. **Persistence:**
   - User B receives messages
   - User B force quits app
   - User B reopens app
   - Unread counts still accurate

#### Edge Cases
1. **Rapid messages:** Send 50 messages quickly, verify all mark as read in batch
2. **Network interruption:** Read messages while offline, verify updates sync when online
3. **App lifecycle:** Background app during read, verify reads still process
4. **Old conversations:** Open conversation with 1000+ messages, verify performance

---

## Related Documentation

- **Main PRD:** `/PRD.md`
- **Core Messaging PRD:** `/tasks/prd-core-messaging.md`
- **Task List (Core Messaging):** `/tasks/tasks-prd-core-messaging.md`
- **Building Phases:** `/building-phases.md` (PR #10)
- **Message Model:** `/NexusAI/Models/Message.swift`
- **MessageService:** `/NexusAI/Services/MessageService.swift`
- **ChatViewModel:** `/NexusAI/ViewModels/ChatViewModel.swift`

---

## Dependencies & Prerequisites

### Must Be Complete Before Starting
- ✅ **PR #5:** Conversation List Screen
- ✅ **PR #6:** Chat Screen UI
- ✅ **PR #7:** Message Sending & Optimistic UI
- ✅ **PR #8:** Real-Time Message Sync

### Infrastructure Already In Place
- ✅ Message model has `readBy` and `deliveredTo` arrays
- ✅ MessageStatusView component exists (basic implementation)
- ✅ MessageService has basic status tracking
- ✅ Firestore listeners receive real-time updates
- ✅ ChatViewModel handles message state

### What's New in This PR
- ❌ Auto-mark messages as read on chat open (NEW)
- ❌ Batch write for read receipts (NEW)
- ❌ Unread count calculation (NEW)
- ❌ Unread badge UI component (NEW)
- ❌ Double blue checkmark for read status (NEW)
- ❌ Delivered status implementation (ENHANCEMENT)

---

**Last Updated:** October 21, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PR #10 - Read Receipts & Message Status  
**Branch:** `feature/read-receipts`

---

**Priority:** 🟡 MEDIUM-HIGH - Enhances UX, not critical for MVP  
**Complexity:** ⭐⭐⭐ Medium (3/5)  
**Estimated Effort:** 2-3 hours

