# PRD: Core Messaging - Phase 3

## Introduction/Overview

Build the core messaging infrastructure for NexusAI, including the conversation list screen, chat interface, message sending with optimistic UI, and real-time message synchronization. This phase represents the heart of the MVP - the foundational messaging system that enables real-time communication between users.

**Problem:** Users need a reliable, fast, and intuitive way to view their conversations, send messages, and receive real-time updates across devices - even when offline.

**Goal:** Implement a production-quality messaging system with WhatsApp-like reliability featuring instant message delivery, real-time sync, offline support, and seamless user experience following SwiftUI best practices.

**Scope:** This PRD covers PRs #5-8 from the building phases:
- **PR #5:** Conversation List Screen
- **PR #6:** Chat Screen UI
- **PR #7:** Message Sending & Optimistic UI
- **PR #8:** Real-Time Message Sync

---

## Goals

1. **Conversation Management:** Provide a real-time conversation list with search, filtering, and new conversation creation
2. **Instant Messaging:** Messages appear instantly in UI with optimistic updates before server confirmation
3. **Real-Time Sync:** All participants see messages immediately through Firestore snapshot listeners
4. **Offline Support:** Messages queue locally when offline and sync automatically on reconnection
5. **Reliable Delivery:** No message loss under any network condition or app lifecycle scenario
6. **Professional UX:** Clean, intuitive interface inspired by modern messaging apps (WhatsApp, iMessage)

---

## User Stories

### As a User Viewing Conversations (PR #5)
- **Story 1:** I want to see a list of all my conversations sorted by most recent activity so I can quickly find active chats
- **Story 2:** I want to search/filter conversations by name so I can quickly find specific chats
- **Story 3:** I want to see unread message counts on each conversation so I know what needs my attention
- **Story 4:** I want to see who's online so I know who's available to chat
- **Story 5:** I want to start a new conversation with any user so I can initiate communication
- **Story 6:** I want to see a profile picture and last message preview so I can identify conversations at a glance
- **Story 7:** I want to pull-to-refresh my conversation list so I can manually trigger updates

### As a User Sending Messages (PRs #6-7)
- **Story 8:** I want to see a dedicated chat screen for each conversation so I can focus on one discussion
- **Story 9:** I want my messages to appear instantly when I hit send so the app feels responsive
- **Story 10:** I want to know if my message is sending, sent, delivered, or read through visual indicators
- **Story 11:** I want to send messages even when offline and have them deliver automatically when I reconnect
- **Story 12:** I want to see sent messages aligned to the right and received messages to the left so I can easily distinguish them
- **Story 13:** I want to see timestamps on messages so I know when they were sent
- **Story 14:** I want clear error messages and retry options if message sending fails

### As a User Receiving Messages (PR #8)
- **Story 15:** I want to receive messages in real-time without refreshing so I stay updated on conversations
- **Story 16:** I want to automatically scroll to the bottom when new messages arrive so I see the latest content
- **Story 17:** I want to load older messages by pulling down so I can see conversation history
- **Story 18:** I want my local optimistic messages to merge seamlessly with server messages so there's no duplication
- **Story 19:** I want messages to persist across app restarts so I don't lose conversation history

---

## Functional Requirements

### FR-1: Conversation List Screen (PR #5)

#### Navigation & Layout
1. The app SHALL display a conversation list screen as the main screen after authentication
2. The navigation bar SHALL display the app name "Nexus" as the title
3. The screen SHALL include a floating action button (FAB) in the bottom-right corner to start new conversations
4. The list SHALL be sorted by most recent activity (`updatedAt` timestamp) with newest conversations at the top

#### Conversation Row Display
5. Each conversation row SHALL display:
   - Profile picture (individual user photo or group icon)
   - Display name (user's name or group name)
   - Last message preview text (truncated to 60 characters)
   - Timestamp with smart formatting:
     - "Just now" (< 1 minute)
     - "5m", "23m" (< 60 minutes)
     - "2h", "8h" (< 24 hours)
     - "Yesterday" (yesterday)
     - "Mon", "Tue", etc. (< 7 days)
     - "12/24" (older than 7 days)
   - Unread badge count (number of unread messages)
   - Online status indicator (green dot for direct chats when user is online)
   - Read receipt indicator (double checkmark if last message was read by recipient)

#### Real-Time Updates
6. The system SHALL listen to Firestore changes on the `conversations` collection filtered by `participantIds` containing current user's ID
7. The list SHALL update automatically when:
   - A new message is sent or received
   - A conversation is created or deleted
   - Participant online status changes
   - Read receipts are updated
8. The system SHALL maintain real-time subscriptions while the screen is active and clean up listeners when the screen is dismissed

#### Search & Filter
9. The screen SHALL include a search bar at the top of the conversation list
10. Users SHALL be able to filter conversations by typing in the search bar
11. The search SHALL match against:
    - Display names
    - Group names
    - Last message text
12. The search SHALL update results in real-time as the user types

#### Pull-to-Refresh
13. Users SHALL be able to pull down on the conversation list to manually refresh
14. The system SHALL show a loading indicator during refresh
15. The refresh SHALL fetch the latest conversation data from Firestore

#### Empty State
16. When a user has no conversations, the system SHALL display an empty state with:
    - Illustration or icon
    - Message: "No conversations yet"
    - Subtitle: "Tap + to start a new conversation"

#### New Conversation Flow
17. When the user taps the FAB, the system SHALL present a "New Conversation" screen
18. The new conversation screen SHALL display a list of all users in the system (excluding the current user)
19. Each user row SHALL display:
    - Profile picture
    - Display name
    - Email address
    - Online status indicator
20. When the user selects a recipient, the system SHALL:
    - Check if a direct conversation already exists between the two users
    - If exists, navigate to the existing conversation
    - If not exists, create a new conversation document in Firestore and navigate to the chat screen
21. The system SHALL create conversations with the following fields:
    - `conversationId`: Auto-generated
    - `type`: "direct"
    - `participantIds`: Array of user IDs [currentUserId, recipientUserId]
    - `participants`: Map of userId → {displayName, profileImageUrl}
    - `createdAt`: Current timestamp
    - `updatedAt`: Current timestamp
    - `lastMessage`: null (initially)

### FR-2: Chat Screen UI (PR #6)

#### Navigation & Layout
22. The chat screen SHALL display a navigation bar with:
    - Back button to return to conversation list
    - Recipient's name (or group name) as title
    - Online status text (e.g., "Online", "Last seen 2h ago") for direct chats
23. The main content area SHALL contain:
    - Message list (scrollable, reverse chronological order with newest at bottom)
    - Message input bar fixed at the bottom
24. The message list SHALL auto-scroll to the bottom when the screen first loads

#### Message Bubble Design
25. Each message bubble SHALL display:
    - Message text
    - Timestamp (e.g., "2:34 PM")
    - Message status indicator (for sent messages only)
26. Sent messages (from current user) SHALL:
    - Align to the right side of the screen
    - Use blue background color
    - Use white text color
27. Received messages (from other users) SHALL:
    - Align to the left side of the screen
    - Use light gray background color
    - Use black text color
28. Message bubbles SHALL have:
    - Rounded corners (16pt radius)
    - Padding (12pt vertical, 16pt horizontal)
    - Maximum width of 75% screen width
    - Word wrap for long text

#### Message Status Indicators
29. The system SHALL display message status icons for sent messages:
    - **Sending:** Single gray clock icon
    - **Sent:** Single gray checkmark (message confirmed by server)
    - **Delivered:** Double gray checkmarks (message received by recipient's device)
    - **Read:** Double blue checkmarks (message opened by recipient)
30. Status indicators SHALL appear in the bottom-right corner of sent message bubbles
31. Status indicators SHALL be 12pt icons with subtle opacity

#### Message Input Bar
32. The message input bar SHALL contain:
    - Multi-line text field for message composition
    - Send button (blue background, white arrow icon)
33. The text field SHALL:
    - Expand vertically as user types (up to 4 lines)
    - Show placeholder text: "Message..."
    - Clear automatically after successful send
34. The send button SHALL:
    - Be disabled (gray) when text field is empty
    - Be enabled (blue) when text field contains text
    - Trigger message send when tapped

#### Typing Indicator (Placeholder)
35. The system SHALL include a placeholder `TypingIndicatorView` component (implementation in PR #9)
36. The component SHALL be positioned above the message input bar
37. The component SHALL be hidden by default in this PR

#### Scroll Behavior
38. The chat screen SHALL auto-scroll to the bottom when:
    - The screen first loads
    - A new message is sent by the current user
39. The chat screen SHALL NOT auto-scroll when:
    - The user is manually scrolling through older messages
40. The system SHALL detect user scroll position to determine if auto-scroll should be prevented

### FR-3: Message Sending & Optimistic UI (PR #7)

#### Optimistic UI Updates
41. When the user taps the send button, the system SHALL immediately:
    - Display the message in the chat UI with "sending" status
    - Clear the message input field
    - Scroll to the bottom of the message list
42. The optimistic message SHALL include:
    - `localId`: UUID generated locally
    - `senderId`: Current user's ID
    - `senderName`: Current user's display name
    - `text`: Message text
    - `timestamp`: Current client timestamp
    - `status`: "sending"
    - `readBy`: Empty array
    - `deliveredTo`: Empty array
43. The optimistic message SHALL persist in local storage (SwiftData) before Firestore write attempt

#### Message Service Integration
44. After displaying the optimistic message, the system SHALL call `MessageService.sendMessage()` to:
    - Write the message to Firestore at `conversations/{conversationId}/messages`
    - Update the conversation's `lastMessage` field
    - Update the conversation's `updatedAt` timestamp
45. The Firestore message document SHALL include:
    - `messageId`: Auto-generated by Firestore
    - `senderId`: Current user's ID
    - `senderName`: Current user's display name
    - `text`: Message text
    - `timestamp`: Server timestamp (FieldValue.serverTimestamp())
    - `status`: "sent"
    - `readBy`: Empty array initially
    - `deliveredTo`: Empty array initially
46. On successful Firestore write, the system SHALL:
    - Update the local message with the server-generated `messageId`
    - Change message status from "sending" to "sent"
    - Keep the message visible in the UI
47. The system SHALL merge the optimistic message with the Firestore message when the listener receives it (see FR-4)

#### Error Handling & Retry
48. If the Firestore write fails, the system SHALL:
    - Update message status to "failed"
    - Display a retry button next to the failed message
    - Keep the message in local storage
49. When the user taps retry, the system SHALL:
    - Change status back to "sending"
    - Attempt to send the message again
50. The system SHALL display error messages for:
    - **Network error:** "Message failed to send. Check your connection."
    - **Permission error:** "Message failed to send. Please try signing in again."
    - **Unknown error:** "Message failed to send. Please try again."
51. Error messages SHALL be displayed as inline alerts above the message input bar
52. Error messages SHALL auto-dismiss after 5 seconds or when the user sends a new message

#### Offline Message Queue
53. The system SHALL implement a `MessageQueueService` to handle offline scenarios
54. When a message send fails due to no network connection, the system SHALL:
    - Add the message to the local offline queue
    - Display the message with "sending" status (not "failed")
    - Continue showing in the UI
55. The queue SHALL persist in local storage (SwiftData)
56. When network connectivity is restored, the system SHALL:
    - Automatically flush all queued messages to Firestore in chronological order
    - Update each message status to "sent" on success
    - Show "failed" status with retry option on individual failures

#### Network Monitoring
57. The system SHALL implement a `NetworkMonitor` utility using `Network.framework`
58. The monitor SHALL track network status:
    - Connected (WiFi or Cellular)
    - Disconnected (No network)
59. The system SHALL observe network status changes
60. When network reconnects, the system SHALL automatically trigger message queue flush
61. The system SHALL display a subtle banner at the top of the chat screen when offline:
    - Background: Light yellow
    - Text: "No internet connection. Messages will send when reconnected."
62. The offline banner SHALL disappear when network reconnects

#### Last Message Update
63. When a message is successfully sent, the system SHALL update the conversation document's `lastMessage` field with:
    - `text`: Message text
    - `senderId`: Current user's ID
    - `timestamp`: Message timestamp
64. The system SHALL update the conversation's `updatedAt` field to trigger conversation list reordering

### FR-4: Real-Time Message Sync (PR #8)

#### Firestore Snapshot Listeners
65. When the chat screen loads, the system SHALL call `MessageService.listenToMessages(conversationId:)` to establish a Firestore snapshot listener
66. The listener SHALL query messages at `conversations/{conversationId}/messages` ordered by `timestamp` ascending
67. The listener SHALL initially load the most recent 50 messages
68. The listener SHALL receive real-time updates when:
    - New messages are added by any participant
    - Existing messages are updated (status changes, read receipts)
    - Messages are deleted (future feature)
69. The listener SHALL remain active while the chat screen is visible
70. The listener SHALL be cancelled when the user navigates away from the chat screen

#### Merging Optimistic and Firestore Messages
71. The system SHALL maintain two message arrays in `ChatViewModel`:
    - `optimisticMessages`: Local messages pending Firestore confirmation
    - `firestoreMessages`: Messages received from Firestore listener
72. The system SHALL merge these arrays for display using the following logic:
    - If a Firestore message has a `localId` matching an optimistic message, replace the optimistic message
    - Otherwise, keep both arrays separate
    - Sort the merged array by timestamp
73. The system SHALL remove optimistic messages from the array once confirmed by Firestore
74. The system SHALL update local storage to reflect confirmed message IDs

#### Auto-Scroll on New Messages
75. When a new message is received from Firestore, the system SHALL:
    - Auto-scroll to the bottom IF the user is already at or near the bottom (within 100pt of bottom)
    - NOT auto-scroll if the user is viewing older messages
76. The system SHALL consider messages as "new" if they arrived after the chat screen loaded

#### Pagination - Load Older Messages
77. The chat screen SHALL support pull-to-refresh at the top of the message list to load older messages
78. When the user pulls down at the top, the system SHALL:
    - Show a loading indicator
    - Query Firestore for the next 50 messages before the oldest currently loaded message
    - Append the older messages to the top of the list
    - Maintain scroll position (don't jump to top)
79. If no more messages exist, the system SHALL display "No more messages" at the top
80. Pagination SHALL work with the Firestore query cursor using `startAfter()` or `endBefore()`

#### Message Delivered Status
81. When a message arrives via the Firestore listener, the system SHALL:
    - Update the message's `deliveredTo` array to include the current user's ID
    - Write back to Firestore (only if current user is not the sender)
82. This update triggers status changes visible to the sender:
    - Single checkmark → Double checkmark (delivered)

#### Local Persistence Sync
83. The system SHALL save all Firestore messages to local storage (SwiftData) as they arrive
84. On app launch with no network, the system SHALL:
    - Load cached messages from SwiftData immediately
    - Display them in the chat screen
    - Show offline banner
85. When network reconnects, the system SHALL:
    - Subscribe to Firestore listeners
    - Merge Firestore messages with cached messages
    - Update UI with latest data

#### Handling Rapid Messages
86. The system SHALL handle scenarios where multiple messages are sent in quick succession (20+ messages)
87. The system SHALL batch Firestore writes where possible to avoid rate limiting
88. The system SHALL maintain message order even during rapid sends
89. The system SHALL ensure all messages complete their optimistic → sent → delivered cycle

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in Phase 3:

### Out of Scope for PR #5-8
1. **Typing Indicators:** Not implemented until PR #9
2. **Read Receipts:** Basic infrastructure in place, but full read receipt logic implemented in PR #10
3. **Group Chat:** Group conversation creation and group-specific UI handled in PR #12
4. **Message Editing/Deletion:** Not included in MVP
5. **Media Messages:** No images, videos, voice messages (text-only MVP)
6. **Message Reactions:** No emoji reactions or message likes
7. **Message Forwarding:** Cannot forward messages to other conversations
8. **Message Search:** No in-conversation search functionality
9. **Message Pinning:** Cannot pin important messages
10. **Custom Notifications:** Notification handling implemented in PR #13
11. **Online Presence Logic:** Basic display included, but full presence system in PR #11
12. **Profile Viewing:** Cannot tap profile pictures to view full profiles
13. **Conversation Settings:** No muting, archiving, or conversation customization
14. **Message Export:** Cannot export conversation history
15. **Link Previews:** Links displayed as plain text
16. **Draft Messages:** Text input not saved between sessions

---

## Design Considerations

### Conversation List Screen Design

#### Layout
- **Navigation Bar:** Standard iOS large title style
- **Search Bar:** Positioned directly below navigation bar
- **Conversation Rows:** Full-width cells with subtle dividers
- **FAB (New Conversation):** 56pt circle, blue background, white + icon, positioned 16pt from bottom-right

#### Visual Hierarchy
- **Display Name:** 17pt, semibold, primary text color
- **Last Message Preview:** 15pt, regular, secondary text color, 1 line truncated
- **Timestamp:** 13pt, regular, tertiary text color, right-aligned
- **Unread Badge:** 20pt circle, red background, white text, count centered

#### Empty State
- **Illustration:** SF Symbol "bubble.left.and.bubble.right" at 80pt size
- **Message:** 20pt, semibold, centered
- **Subtitle:** 15pt, regular, secondary text color, centered

### Chat Screen Design

#### Message Bubbles
- **Sent Messages:**
  - Background: `#007AFF` (iOS blue)
  - Text: White
  - Alignment: Trailing (right)
  - Tail: Small triangular tail pointing right
  
- **Received Messages:**
  - Background: `#E5E5EA` (iOS light gray)
  - Text: Black
  - Alignment: Leading (left)
  - Tail: Small triangular tail pointing left

#### Message Input Bar
- **Background:** White with subtle top border
- **Text Field:** Gray rounded background, 36pt height (expandable)
- **Send Button:** 36pt circle, blue when enabled, gray when disabled

#### Loading Indicators
- **Message Sending:** Small spinner next to message
- **Pull-to-Refresh:** Standard iOS spinner
- **Older Messages Loading:** Spinner at top of message list

### Accessibility
- **VoiceOver:** All interactive elements have descriptive labels
- **Dynamic Type:** Text scales with user's system font size preferences
- **Color Contrast:** All text meets WCAG AA standards
- **Touch Targets:** All tappable elements are at least 44pt × 44pt

---

## Technical Considerations

### Dependencies
- **Firebase Firestore SDK:** Real-time database and snapshot listeners
- **SwiftData:** Local message persistence and offline caching
- **Combine:** Reactive programming for view model state management
- **Network Framework:** Network connectivity monitoring

### Architecture

#### ViewModels
- **`ConversationListViewModel`:**
  - Manages conversation list state
  - Handles Firestore listener for conversations
  - Implements search/filter logic
  - Coordinates navigation to chat screens

- **`ChatViewModel`:**
  - Manages chat screen state
  - Handles message sending with optimistic UI
  - Manages Firestore message listener
  - Merges optimistic and Firestore messages
  - Coordinates with MessageQueueService

#### Services
- **`MessageService`:**
  - `sendMessage(conversationId:text:sender:)` → writes to Firestore
  - `listenToMessages(conversationId:limit:)` → establishes snapshot listener
  - `updateMessageStatus(messageId:status:)` → updates message status
  - `markMessageDelivered(messageId:userId:)` → updates deliveredTo array

- **`ConversationService`:**
  - `listenToConversations(userId:)` → snapshot listener for conversations
  - `createConversation(participantIds:type:)` → creates new conversation
  - `updateLastMessage(conversationId:message:)` → updates conversation metadata

- **`MessageQueueService`:**
  - `enqueue(message:conversationId:)` → adds message to offline queue
  - `flushQueue()` → sends all queued messages
  - `retryMessage(localId:)` → retries failed message
  - Uses SwiftData for persistent queue storage

- **`LocalStorageService`:**
  - `saveMessage(_:)` → persists message locally
  - `getMessages(conversationId:)` → retrieves cached messages
  - `updateMessage(localId:with:)` → updates cached message
  - `saveConversation(_:)` → caches conversation

#### Utilities
- **`NetworkMonitor`:**
  - Singleton using `NWPathMonitor`
  - `isConnected` published property
  - Emits connectivity change events

- **`Date+Extensions`:**
  - `smartTimestamp()` → returns formatted timestamp string
  - Implements smart formatting logic (5m, 2h, Yesterday, etc.)

### Data Flow

#### Message Sending Flow
```
User types message → Taps send button
    ↓
1. ChatViewModel.sendMessage()
    ↓
2. Create optimistic message with localId
    ↓
3. Add to optimisticMessages array
    ↓
4. UI updates immediately (message appears)
    ↓
5. LocalStorageService.saveMessage() (SwiftData)
    ↓
6. MessageService.sendMessage() (Firestore write)
    ↓
7a. Success:
    - Message gets messageId from Firestore
    - Status updates to "sent"
    - Conversation lastMessage updates
    ↓
7b. Failure:
    - MessageQueueService.enqueue()
    - Status remains "sending" if offline
    - Status changes to "failed" if online error
    ↓
8. Firestore listener receives message
    ↓
9. Merge optimistic message with Firestore message
    ↓
10. Remove from optimisticMessages array
```

#### Message Receiving Flow
```
Another user sends message
    ↓
1. Firestore writes message document
    ↓
2. All participants' snapshot listeners triggered
    ↓
3. MessageService listener callback fires
    ↓
4. ChatViewModel.handleNewMessage()
    ↓
5. Check if message exists in optimisticMessages
    ↓
6a. If exists (own message):
    - Merge with optimistic message
    - Remove from optimistic array
    - Update to firestoreMessages
    ↓
6b. If not exists (received message):
    - Add to firestoreMessages
    - LocalStorageService.saveMessage()
    - Update deliveredTo array in Firestore
    ↓
7. UI updates with new message
    ↓
8. Auto-scroll if at bottom
```

### Firestore Query Optimization
- Use `.limit(50)` for initial message load to prevent large data transfers
- Implement cursor-based pagination with `.startAfter()` for older messages
- Index `timestamp` field for efficient sorting
- Use `.whereField("participantIds", arrayContains: userId)` for conversation filtering

### Local Storage Strategy (SwiftData)
- Create `LocalMessage` and `LocalConversation` models with `@Model` macro
- Use `ModelContext` for CRUD operations
- Implement background context for offline queue processing
- Clear old cached messages after 30 days to prevent storage bloat

### Performance Considerations
- Lazy load conversation rows with `LazyVStack`
- Use `List` with `id` for efficient message list updates
- Implement view recycling for message bubbles
- Debounce search input to avoid excessive filtering (300ms delay)
- Batch Firestore writes when flushing message queue

### Error Handling Strategy
- Use Swift `Result` type for async operations
- Map Firestore errors to user-friendly messages
- Implement exponential backoff for retry logic (1s, 2s, 4s, 8s)
- Log all errors for debugging (use `os_log` or similar)
- Gracefully degrade functionality when services unavailable

### Testing Considerations
- Test optimistic UI updates in airplane mode
- Test rapid message sending (20+ messages in 10 seconds)
- Test message delivery when recipient is offline
- Test conversation list updates with multiple simultaneous messages
- Test pagination with conversations containing 500+ messages
- Test app backgrounding/foregrounding during message send
- Verify no duplicate messages after optimistic/Firestore merge

---

## Success Metrics

### Functional Success
- ✅ Conversation list displays all user's conversations sorted by recent activity
- ✅ User can search/filter conversations by name
- ✅ User can create new conversations with any user in the system
- ✅ User can send messages that appear instantly in the UI
- ✅ Messages sync in real-time to all participants within 1 second under good network
- ✅ Messages sent offline queue and deliver automatically on reconnection
- ✅ User can load older messages by pull-to-refresh at top of chat
- ✅ Conversation list updates in real-time when new messages arrive
- ✅ All message statuses (sending/sent/delivered/read) display correctly
- ✅ No duplicate messages appear after optimistic UI merge with Firestore
- ✅ App handles rapid message sending (20+ messages) without errors

### Technical Success
- ✅ No crashes during message sending or receiving
- ✅ Firestore listeners clean up properly to avoid memory leaks
- ✅ Local storage persists messages across app restarts
- ✅ Message queue flushes correctly on network reconnection
- ✅ Pagination loads older messages without scroll position jumping
- ✅ UI remains responsive during heavy message load (100+ messages)
- ✅ Network monitor accurately tracks connectivity changes

### User Experience Success
- ✅ Messages appear instantly when send button is tapped (<100ms)
- ✅ Real-time message delivery feels natural (no lag or jitter)
- ✅ Offline experience is clear and non-blocking (messages queue silently)
- ✅ Error messages are clear and actionable
- ✅ No unexpected navigation or screen flashing
- ✅ Scroll behavior is predictable (auto-scroll when appropriate, manual otherwise)
- ✅ Loading indicators provide appropriate feedback

### Performance Benchmarks
- ✅ Conversation list loads within 1 second on first app launch
- ✅ Chat screen loads within 500ms when opening conversation
- ✅ Message appears in UI within 100ms of send button tap
- ✅ Firestore write completes within 1 second under good network
- ✅ Message queue flush completes within 5 seconds for 20 queued messages
- ✅ Pagination loads 50 older messages within 1 second

---

## Open Questions

1. **Message Timestamp Display:** Should timestamps be displayed on every message, or only when there's a time gap (e.g., > 5 minutes)?

2. **Conversation Previews:** If the last message is from the current user, should the preview show "You: " prefix?

3. **New Conversation Check:** When creating a new conversation, should we search by both users' IDs (to prevent duplicate direct conversations), or allow multiple conversations between the same users?

4. **Profile Picture Source:** Should we use Google profile picture URLs or implement a custom avatar/initials fallback for users without pictures?

5. **Message Batch Size:** Is 50 messages an appropriate initial load size? Should this be configurable based on device/network?

6. **Offline Queue Limit:** Should we limit the offline queue size (e.g., max 100 messages) to prevent excessive memory usage?

7. **Failed Message Persistence:** How long should failed messages remain in the UI with retry buttons? Should they auto-clear after some time?

8. **Scroll Position Memory:** When returning to a chat screen, should we scroll to the last position the user was viewing, or always jump to the bottom?

9. **Empty Conversation State:** Should the chat screen show a different empty state for new conversations vs. conversations with no messages yet?

10. **Message Merging Edge Cases:** How should we handle the edge case where a user sends the same message text multiple times in quick succession? Match by localId only, or also compare timestamps?

---

## Acceptance Criteria

### Must Have (All PRs #5-8)

#### PR #5: Conversation List
- [ ] Conversation list displays all user's conversations
- [ ] Conversations sorted by most recent activity (updatedAt)
- [ ] Each row shows profile picture, name, last message, timestamp, unread count, online status
- [ ] Real-time updates when new messages arrive
- [ ] Search bar filters conversations by name/content
- [ ] Pull-to-refresh updates conversation list
- [ ] Empty state displayed when user has no conversations
- [ ] FAB button opens new conversation screen
- [ ] New conversation screen lists all available users
- [ ] Selecting a user creates conversation and navigates to chat screen
- [ ] Duplicate direct conversations prevented (check existing participants)

#### PR #6: Chat Screen UI
- [ ] Chat screen displays navigation bar with recipient name and online status
- [ ] Message list displays messages in correct order (oldest to newest, bottom-aligned)
- [ ] Sent messages align right with blue background
- [ ] Received messages align left with gray background
- [ ] Each message shows timestamp
- [ ] Message status indicators display correctly (sending/sent/delivered/read icons)
- [ ] Message input bar with text field and send button
- [ ] Send button disabled when text field is empty
- [ ] Send button enabled when text field contains text
- [ ] Auto-scroll to bottom when chat screen loads

#### PR #7: Message Sending & Optimistic UI
- [ ] Tapping send button immediately displays message in UI
- [ ] Message input field clears after sending
- [ ] Message shows "sending" status initially
- [ ] Message writes to Firestore successfully
- [ ] Message status updates to "sent" after Firestore confirmation
- [ ] Failed messages show retry button
- [ ] Retry button re-attempts message send
- [ ] Offline messages queue in MessageQueueService
- [ ] Queued messages flush automatically when network reconnects
- [ ] Offline banner displays when no network connection
- [ ] Offline banner disappears when network reconnects
- [ ] Conversation lastMessage updates after successful send
- [ ] NetworkMonitor tracks connectivity status correctly

#### PR #8: Real-Time Message Sync
- [ ] Chat screen establishes Firestore snapshot listener on load
- [ ] New messages appear in real-time from other participants
- [ ] Optimistic messages merge seamlessly with Firestore messages (no duplicates)
- [ ] Messages persist to local storage (SwiftData)
- [ ] App loads cached messages on launch when offline
- [ ] Message list auto-scrolls to bottom for new messages (when user is at bottom)
- [ ] Message list does NOT auto-scroll when user is viewing older messages
- [ ] Pull-to-refresh at top loads older messages (pagination)
- [ ] Pagination loads 50 messages at a time
- [ ] Pagination maintains scroll position (doesn't jump to top)
- [ ] "No more messages" indicator shown when all messages loaded
- [ ] Firestore listener cleans up when leaving chat screen
- [ ] Delivered status updates when message received by recipient

### Should Have
- [ ] Smart timestamp formatting (5m, 2h, Yesterday, Mon, 12/24)
- [ ] Smooth animations for message appearance
- [ ] Keyboard dismisses when scrolling message list
- [ ] Message bubbles have subtle shadows for depth
- [ ] Unread badge count updates in real-time on conversation list
- [ ] Retry logic uses exponential backoff (1s, 2s, 4s, 8s)

### Nice to Have
- [ ] Haptic feedback when message successfully sends
- [ ] Smooth transition animation when navigating to chat screen
- [ ] Message bubbles animate in with subtle fade/scale effect
- [ ] Pull-to-refresh uses custom animation instead of default spinner
- [ ] Typing indicator animation (placeholder for PR #9)
- [ ] Message sent confirmation sound (optional)

---

## Implementation Notes for Developers

### Key Files to Create

#### PR #5: Conversation List
- `ViewModels/ConversationListViewModel.swift` - Manages conversation list state and Firestore listener
- `Views/ConversationList/ConversationListView.swift` - Main conversation list screen
- `Views/ConversationList/ConversationRowView.swift` - Individual conversation row component
- `Views/ConversationList/NewConversationView.swift` - New conversation creation screen
- `Views/Components/ProfileImageView.swift` - Reusable profile picture component
- `Views/Components/OnlineStatusIndicator.swift` - Green dot indicator for online users
- `Utilities/Extensions/Date+Extensions.swift` - Smart timestamp formatting

#### PR #6: Chat Screen UI
- `ViewModels/ChatViewModel.swift` - Basic structure (expanded in PR #7-8)
- `Views/Chat/ChatView.swift` - Main chat screen
- `Views/Chat/MessageBubbleView.swift` - Message bubble component
- `Views/Chat/MessageInputView.swift` - Message input bar with text field and send button
- `Views/Chat/MessageStatusView.swift` - Status indicator icons component
- `Views/Chat/TypingIndicatorView.swift` - Placeholder component (implemented in PR #9)

#### PR #7: Message Sending & Optimistic UI
- `Services/MessageQueueService.swift` - Offline message queue management
- `Utilities/NetworkMonitor.swift` - Network connectivity monitoring
- Update `Services/MessageService.swift` - Add sendMessage() implementation
- Update `ViewModels/ChatViewModel.swift` - Add optimistic UI logic

#### PR #8: Real-Time Message Sync
- Update `Services/MessageService.swift` - Add listenToMessages() and pagination
- Update `ViewModels/ChatViewModel.swift` - Add listener subscription and message merging logic
- Update `Views/Chat/ChatView.swift` - Add scroll management and pull-to-refresh

### Existing Files to Modify
- `Services/ConversationService.swift` - Already created, add conversation CRUD methods
- `Services/LocalStorageService.swift` - Already created, add SwiftData persistence methods
- `Models/Message.swift` - Already created, may need to add computed properties
- `Models/Conversation.swift` - Already created, may need to add computed properties
- `Utilities/Constants.swift` - Add UI constants (colors, dimensions, etc.)

### SwiftUI Best Practices

#### State Management
```swift
// In ViewModel
@Published var conversations: [Conversation] = []
@Published var messages: [Message] = []
@Published var isLoading = false
@Published var errorMessage: String?

// In View
@StateObject private var viewModel = ConversationListViewModel()
@State private var searchText = ""
```

#### Firestore Listeners
```swift
func listenToConversations() {
    listener = db.collection("conversations")
        .whereField("participantIds", arrayContains: currentUserId)
        .order(by: "updatedAt", descending: true)
        .addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self?.conversations = documents.compactMap { 
                try? $0.data(as: Conversation.self) 
            }
        }
}

// IMPORTANT: Clean up listeners
deinit {
    listener?.remove()
}
```

#### Optimistic UI Pattern
```swift
// 1. Create optimistic message
let localMessage = Message(
    localId: UUID().uuidString,
    text: text,
    senderId: currentUserId,
    timestamp: Date(),
    status: .sending
)

// 2. Show in UI immediately
messages.append(localMessage)

// 3. Send to Firestore
Task {
    do {
        let messageId = try await messageService.sendMessage(localMessage)
        
        // 4. Update with server ID
        if let index = messages.firstIndex(where: { $0.localId == localMessage.localId }) {
            messages[index].messageId = messageId
            messages[index].status = .sent
        }
    } catch {
        // 5. Handle failure
        if let index = messages.firstIndex(where: { $0.localId == localMessage.localId }) {
            messages[index].status = .failed
        }
    }
}
```

### SwiftData Setup

#### Models
```swift
import SwiftData

@Model
class LocalMessage {
    @Attribute(.unique) var localId: String
    var messageId: String?
    var conversationId: String
    var text: String
    var senderId: String
    var timestamp: Date
    var status: String
    // ... other fields
    
    init(from message: Message) {
        self.localId = message.localId
        // ... map fields
    }
}
```

#### Container Configuration
```swift
// In App
@main
struct NexusAIApp: App {
    var modelContainer: ModelContainer = {
        let schema = Schema([
            LocalMessage.self,
            LocalConversation.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

### Network Monitoring Setup

```swift
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
```

### Testing Scenarios

#### PR #5 Testing
1. Launch app after authentication → See conversation list
2. Create new conversation → Verify appears in list
3. Receive message in background → Verify conversation moves to top
4. Search for conversation → Verify filtering works
5. Pull-to-refresh → Verify updates correctly
6. Empty state → Sign in with new user, verify empty state displays

#### PR #6 Testing
1. Tap conversation → Chat screen opens
2. View messages → Sent messages right-aligned blue, received left-aligned gray
3. Type message → Send button enables
4. Clear text → Send button disables
5. Messages display timestamps correctly
6. Status indicators show for sent messages

#### PR #7 Testing
1. Send message → Appears instantly with "sending" status
2. Message confirms → Status changes to "sent"
3. Turn on airplane mode → Send message → Shows "sending" (queued)
4. Turn off airplane mode → Message delivers automatically
5. Force Firestore error → Message shows "failed" with retry button
6. Tap retry → Message attempts send again
7. Send 20 messages rapidly → All deliver correctly
8. Offline banner appears when disconnected

#### PR #8 Testing
1. Open chat on Device A → Send message from Device B → Message appears in real-time
2. Send message with optimistic UI → Verify no duplicate when Firestore listener receives it
3. Load chat with 100+ messages → Pull down at top → Older messages load
4. Close and reopen app → Messages load from cache immediately
5. Scroll to middle of chat → Send new message from another device → Verify no auto-scroll
6. Stay at bottom of chat → Receive message → Verify auto-scrolls to show new message
7. Kill app → Send messages to user → Reopen app → Messages appear

---

## Related Documentation

- **Project Brief:** `/memory-bank/projectbrief.md`
- **Building Phases:** `/building-phases.md` (PRs #5-8)
- **System Architecture:** `/architecture.md`
- **Main PRD:** `/PRD.md`
- **Authentication PRD:** `/tasks/prd-authentication-flow.md`
- **Firebase Services:** `/NexusAI/Services/MessageService.swift`, `/NexusAI/Services/ConversationService.swift`
- **Models:** `/NexusAI/Models/Message.swift`, `/NexusAI/Models/Conversation.swift`

---

## Dependencies & Prerequisites

### Must Be Complete Before Starting
- ✅ **PR #1:** Project Setup & Firebase Configuration
- ✅ **PR #2:** Core Models & Constants
- ✅ **PR #3:** Firebase Services Layer
- ✅ **PR #4:** Authentication Flow

### Firebase Configuration Requirements
- Firestore database created and configured
- Firestore security rules allow authenticated users to read/write their conversations
- Firestore indexes created for:
  - `conversations` collection: `participantIds` (array) + `updatedAt` (descending)
  - `messages` subcollection: `conversationId` + `timestamp` (ascending)

### Xcode Project Requirements
- Firebase SDK installed via SPM (Firestore, Auth)
- GoogleService-Info.plist configured
- SwiftData framework imported
- Network framework imported

---

**Last Updated:** October 21, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PRs #5-8 - Core Messaging Phase  
**Branches:** 
- `feature/conversation-list` (PR #5)
- `feature/chat-ui` (PR #6)
- `feature/message-sending` (PR #7)
- `feature/realtime-messages` (PR #8)

---

**Priority:** 🔴 CRITICAL - Core MVP Feature  
**Complexity:** ⭐⭐⭐⭐⭐ High (4 interconnected PRs)  
**Estimated Effort:** 8-10 hours total across all 4 PRs

