# PRD: Group Chat Functionality - PR #12

## Introduction/Overview

Implement comprehensive group chat functionality, enabling users to create group conversations with multiple participants (3+), send group messages, view participant lists, and manage group settings. This builds on the existing direct messaging infrastructure to support team-based communication.

**Problem:** Users can only chat one-on-one. Remote teams need group conversations to coordinate with multiple team members simultaneously, share updates, and have team discussions.

**Goal:** Implement production-quality group chat functionality that supports 3+ participants with features like group creation, participant management, sender identification, and group-specific read receipts.

**Scope:** This PRD covers PR #12 from the building phases, adding group chat capabilities to the existing messaging system.

---

## Goals

1. **Group Creation:** Users can create groups with multiple participants (3+ users)
2. **Group Identity:** Groups have names, optional profile images, and clear participant lists
3. **Message Attribution:** Group messages show sender names so users know who said what
4. **Participant Management:** Users can view group participants and their status
5. **Group Read Receipts:** Messages show "Read by X/Y" counts in group contexts
6. **Seamless Experience:** Group chats work identically to direct chats (same chat UI, same features)

---

## User Stories

### As a User Creating Groups
- **Story 1:** I want to create a group with 3+ team members so we can have team discussions
- **Story 2:** I want to give my group a descriptive name (e.g., "Engineering Team") so everyone knows the group's purpose
- **Story 3:** I want to see a list of all users and select multiple participants when creating a group
- **Story 4:** I want to add an optional group profile image so the group is easily identifiable
- **Story 5:** I want the group to appear in my conversation list immediately after creation

### As a Group Chat Participant
- **Story 6:** I want to see who sent each message in the group so I know who's saying what
- **Story 7:** I want to see a list of all group participants so I know who's in the conversation
- **Story 8:** I want to see who's online in the group so I know who's available
- **Story 9:** I want to send messages in groups just like in direct chats (same input, same optimistic UI)
- **Story 10:** I want to see how many people have read my messages ("Read by 3/5")

### As a Group Administrator (Future)
- **Story 11:** I want to add new participants to an existing group (future: PR #14)
- **Story 12:** I want to remove participants from a group (future: PR #14)
- **Story 13:** I want to change the group name or image (future: PR #14)
- **Story 14:** I want to leave a group when I'm no longer part of the team (future: PR #14)

### As a Group Observer
- **Story 15:** I want to view group info (name, participants, created date) so I understand the group context
- **Story 16:** I want to tap read receipts to see which specific members have read a message
- **Story 17:** I want to see participant status (online/offline) in the group info screen

---

## Functional Requirements

### FR-1: Group Creation

#### Create Group Flow
1. The app SHALL provide a way to initiate group creation from the conversation list (FAB → "New Group")
2. The system SHALL display a CreateGroupView screen for group setup
3. The CreateGroupView SHALL include:
   - Text field for group name (required, 1-50 characters)
   - Multi-select participant picker
   - Optional group image selector (future: photo library)
   - "Create Group" button (enabled when name + 2+ participants selected)
   - Cancel button

#### Participant Selection
4. The CreateGroupView SHALL display a searchable list of all users (excluding current user)
5. Users SHALL be able to search/filter participants by name or email
6. Users SHALL select participants by tapping checkboxes next to user rows
7. The system SHALL show a count of selected participants (e.g., "3 selected")
8. Users MUST select at least 2 other participants (total 3+ including creator)
9. The "Create Group" button SHALL be disabled if fewer than 2 participants selected

#### Group Metadata
10. Group name is REQUIRED and must be 1-50 characters
11. Group image is OPTIONAL (for MVP, use default group icon)
12. The system SHALL auto-generate a `conversationId` for the group
13. The system SHALL set `type: "group"` in the conversation document
14. The system SHALL create a `participants` map with user details:
    ```swift
    participants: [
        userId1: { displayName: "Alice", profileImageUrl: "..." },
        userId2: { displayName: "Bob", profileImageUrl: "..." },
        userId3: { displayName: "Charlie", profileImageUrl: "..." }
    ]
    ```
15. The system SHALL set `participantIds` array with all participant user IDs
16. The system SHALL include the creator in `participantIds` automatically

#### Group Creation Logic
17. When user taps "Create Group", the system SHALL call `ConversationService.createGroupConversation()`
18. The service SHALL create a conversation document in Firestore at `conversations/{conversationId}`
19. The conversation SHALL include:
    - `conversationId`: Auto-generated ID
    - `type`: "group"
    - `groupName`: User-provided name
    - `groupImageUrl`: Optional (null for MVP, default icon used)
    - `participantIds`: Array of all participant user IDs
    - `participants`: Map of userId → {displayName, profileImageUrl}
    - `createdAt`: Server timestamp
    - `createdBy`: Creator's user ID
    - `updatedAt`: Server timestamp
    - `lastMessage`: null initially
20. On success, the system SHALL navigate to the new group's ChatView
21. On failure, the system SHALL show error message and allow retry

### FR-2: Group Display in Conversation List

#### Group Row Appearance
22. Group conversations SHALL appear in the conversation list alongside direct chats
23. The system SHALL distinguish group conversations by:
    - Group name displayed (instead of user name)
    - Group icon (default icon for MVP, later custom images)
    - Last message shows sender name: "Alice: Message text..."
24. ConversationRowView SHALL adapt based on conversation type:
    - Direct: Show user profile image, user name
    - Group: Show group icon, group name
25. Online status indicator SHALL NOT appear for group rows (only for direct chats)
26. Unread badge SHALL work identically for groups and direct chats

#### Last Message Preview
27. For group conversations, last message preview SHALL show sender name prefix
28. Format: `"[SenderName]: [Message text]"`
29. Example: "Alice: Let's meet at 3pm"
30. If sender is current user, show "You: Message text"
31. Message text SHALL be truncated to fit row width

### FR-3: Group Chat UI

#### Chat Screen Header
32. The ChatView navigation bar SHALL display group name as title
33. For groups, the subtitle SHALL NOT show online status (reserved for direct chats)
34. The subtitle SHALL show participant count: "3 participants"
35. Tapping the group name/header SHALL navigate to GroupInfoView

#### Message Display
36. MessageBubbleView SHALL show sender name above received messages in groups
37. Sender name SHALL display as: "[DisplayName]" in 13pt semibold font
38. Sender name SHALL appear only on messages from other users (not current user's messages)
39. Sender name color SHALL be secondary text color (gray)
40. Messages SHALL otherwise display identically to direct chats (same bubbles, timestamps, etc.)

#### Message Input
41. Message input bar SHALL work identically in groups and direct chats
42. Send button, optimistic UI, offline queue, retry - all work the same
43. The system SHALL send group messages to the same Firestore path: `conversations/{conversationId}/messages`

#### Scroll Behavior
44. Auto-scroll, pagination, and all other chat features SHALL work identically in groups

### FR-4: Group Message Sending

#### Send Logic
45. Sending messages in groups SHALL use the exact same logic as direct chats
46. MessageService.sendMessage() SHALL work for both direct and group conversations
47. The message document SHALL include `senderId` and `senderName` (already implemented)
48. The system SHALL update the group conversation's `lastMessage` field
49. All participants SHALL receive the message via their Firestore snapshot listeners

#### Real-Time Sync
50. Group messages SHALL sync in real-time to all participants
51. Each participant's device SHALL receive messages via existing snapshot listeners
52. The system SHALL mark messages as delivered when each participant receives them
53. The system SHALL use the same optimistic UI pattern for group messages

### FR-5: Group Read Receipts

#### Read Tracking
54. When a participant reads messages in a group, the system SHALL update `readBy` array (same as direct chats)
55. The `readBy` array SHALL contain user IDs of all participants who have read the message
56. The system SHALL use the same `markMessagesAsRead()` logic from PR #10

#### Read Receipt Display
57. For group messages sent by current user, the system SHALL display read receipt count
58. Format: "Read by X/Y" where X = number who read, Y = total participants (excluding sender)
59. Example: "Read by 2/4" means 2 out of 4 recipients have read the message
60. The read receipt SHALL appear below the message bubble in small gray text
61. MessageStatusView SHALL compute read count:
    - X = `readBy.count` (excluding sender)
    - Y = `participantIds.count - 1` (all except sender)

#### Read Receipt Detail (Future)
62. Tapping "Read by X/Y" SHALL navigate to a detail view showing which participants have/haven't read (future: PR #14)
63. For MVP, read receipt count is display-only (no tap interaction)

### FR-6: Group Info View

#### View Content
64. The system SHALL provide a GroupInfoView screen showing group details
65. GroupInfoView SHALL be accessible by tapping the group name in ChatView navigation bar
66. GroupInfoView SHALL display:
    - Group icon (large, 80pt)
    - Group name (editable in future, read-only for MVP)
    - Participant count: "X participants"
    - ParticipantListView with all participants
67. Each participant row SHALL show:
    - Profile image
    - Display name
    - Online status indicator (green dot if online)
    - Email address (optional, secondary text)

#### Participant List
68. Participants SHALL be sorted:
    - Current user first (with "You" label)
    - Then by online status (online users first)
    - Then alphabetically by display name
69. The participant list SHALL be scrollable if many participants
70. Tapping a participant row SHALL do nothing for MVP (future: view profile or start direct chat)

#### Group Actions (Future)
71. The GroupInfoView SHALL include action buttons (future PRs):
    - "Add Participants" (future: PR #14)
    - "Leave Group" (future: PR #14)
    - "Mute Notifications" (future: PR #13 enhancement)
72. For MVP, these buttons are NOT included

### FR-7: Group Management (Future)

**Note:** The following features are designed but NOT implemented in PR #12 (deferred to PR #14)

#### Add Participants (Future)
- Add new users to existing group
- Update `participantIds` and `participants` map
- Send system message: "Alice added Bob to the group"

#### Remove Participants (Future)
- Remove users from group (admin only)
- Update Firestore document
- Send system message: "Alice removed Bob from the group"

#### Leave Group (Future)
- User can leave group they're in
- Update their `participantIds` entry
- Send system message: "Alice left the group"

#### Edit Group Info (Future)
- Change group name
- Change group image
- Restricted to group creator or admins

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in PR #12:

1. **Group Administration:** No admin roles, no permission system (future)
2. **Add/Remove Participants:** Cannot modify group membership after creation (future: PR #14)
3. **Edit Group Info:** Cannot change group name or image after creation (future: PR #14)
4. **Leave Group:** Cannot leave a group once created (future: PR #14)
5. **Group Images:** No custom group images, use default icon (future enhancement)
6. **System Messages:** No "Alice added Bob" messages (future: PR #14)
7. **Read Receipt Details:** Cannot see who specifically has read messages (future: PR #14)
8. **Group Settings:** No group-specific settings (mute, notifications, etc.)
9. **Group Search:** No dedicated group discovery or search
10. **Group Limits:** No max participant count enforcement (scalable design)
11. **Group Templates:** No pre-defined group types or templates
12. **Group Archiving:** Cannot archive or hide groups
13. **Group Pinning:** Cannot pin groups to top of conversation list
14. **Message Mentions:** No @mentions in group messages (future)
15. **Group Calls:** No group voice/video calls

---

## Design Considerations

### Create Group View Design

#### Layout
- **Navigation Bar:** "New Group" title, Cancel button (left)
- **Group Name Field:** Text input at top, placeholder "Group Name"
- **Participant Section:**
  - Header: "Add Participants" + count badge "(3 selected)"
  - Search bar for filtering users
  - Scrollable list with checkboxes
- **Create Button:** Fixed at bottom, blue, full-width, disabled when invalid

#### Visual Hierarchy
- Group name field: 20pt, prominent at top
- Participant rows: 44pt height, profile image (32pt), name + email
- Checkbox: Trailing edge, blue checkmark when selected
- Selected count badge: Blue circle, white text, positioned next to header

### Group Info View Design

#### Layout
- **Header Section:**
  - Group icon: 80pt diameter, centered
  - Group name: 24pt semibold, centered below icon
  - Participant count: 15pt secondary, centered below name
- **Participant List:**
  - Section header: "PARTICIPANTS"
  - Scrollable list of participant rows
  - Current user row has "You" badge

#### Participant Row
- Profile image: 40pt diameter
- Display name: 17pt semibold
- Email: 14pt secondary
- Online indicator: 8pt green dot overlaid on image

### Group Chat UI Adaptations

#### Message Bubbles
- **Received Messages (Group):**
  - Sender name: 13pt semibold, gray, above bubble
  - Spacing: 4pt between name and bubble
  - Bubble: Same style as direct chat
  
- **Sent Messages (Group):**
  - No sender name (obviously from current user)
  - Same blue bubble as direct chat

#### Read Receipts
- Position: Below message bubble, right-aligned
- Format: "Read by 2/4" in 12pt gray text
- Show only for sent messages with 1+ reads

### Accessibility

#### VoiceOver
- Group name field: "Group name, text field"
- Participant selection: "Select [Name] for group, checkbox, [checked/unchecked]"
- Participant rows: "[Name], online/offline"
- Read receipts: "Read by 2 of 4 participants"

#### Dynamic Type
- All text scales with system font size
- Group name field, participant list scale appropriately

---

## Technical Considerations

### Architecture

#### Service Methods

**ConversationService:**
```swift
// Create group conversation
func createGroupConversation(
    groupName: String,
    participantIds: [String],
    participants: [String: ParticipantInfo],
    groupImageUrl: String?
) async throws -> Conversation

// Get group details
func getGroupDetails(conversationId: String) async throws -> Conversation

// Future: Add participant
func addParticipantToGroup(conversationId: String, userId: String) async throws

// Future: Remove participant
func removeParticipantFromGroup(conversationId: String, userId: String) async throws

// Future: Update group name
func updateGroupName(conversationId: String, newName: String) async throws
```

#### ViewModel Updates

**ConversationListViewModel:**
```swift
// Already handles both types, no changes needed
// Just ensure group conversations display correctly
```

**ChatViewModel:**
```swift
// Add computed property
var isGroupConversation: Bool {
    conversation.type == "group"
}

// Use for conditional UI (show sender names if group)
```

**GroupInfoViewModel (NEW):**
```swift
class GroupInfoViewModel: ObservableObject {
    @Published var conversation: Conversation
    @Published var participants: [User] = []
    @Published var isLoading = false
    
    func loadParticipants() async {
        // Fetch user details for all participantIds
    }
}
```

### Data Model

#### Conversation Model (Enhancement)
```swift
struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    var type: ConversationType // "direct" or "group"
    var participantIds: [String]
    var participants: [String: ParticipantInfo]
    
    // Group-specific fields
    var groupName: String? // Only for type == "group"
    var groupImageUrl: String? // Optional
    var createdBy: String? // Creator's user ID
    
    // ... existing fields
    
    enum ConversationType: String, Codable {
        case direct
        case group
    }
    
    struct ParticipantInfo: Codable {
        var displayName: String
        var profileImageUrl: String?
    }
}
```

#### Message Model (No Changes)
```swift
// Message model already supports groups
// senderId and senderName identify who sent message
struct Message: Codable, Identifiable {
    // ... existing fields work for groups
    var senderId: String
    var senderName: String
    // readBy array works for group read receipts
    var readBy: [String] = []
}
```

### Firestore Structure

#### Group Conversation Document
```
conversations/{conversationId}
{
    "conversationId": "abc123",
    "type": "group",
    "groupName": "Engineering Team",
    "groupImageUrl": null,
    "participantIds": ["user1", "user2", "user3", "user4"],
    "participants": {
        "user1": { "displayName": "Alice", "profileImageUrl": "..." },
        "user2": { "displayName": "Bob", "profileImageUrl": "..." },
        "user3": { "displayName": "Charlie", "profileImageUrl": "..." },
        "user4": { "displayName": "Diana", "profileImageUrl": "..." }
    },
    "createdAt": Timestamp,
    "createdBy": "user1",
    "updatedAt": Timestamp,
    "lastMessage": {
        "text": "Hello team!",
        "senderId": "user1",
        "senderName": "Alice",
        "timestamp": Timestamp
    }
}
```

#### Group Messages
```
conversations/{conversationId}/messages/{messageId}
{
    "messageId": "msg123",
    "conversationId": "abc123",
    "senderId": "user1",
    "senderName": "Alice",
    "text": "Hello team!",
    "timestamp": Timestamp,
    "status": "sent",
    "readBy": ["user1", "user2"],
    "deliveredTo": ["user1", "user2", "user3", "user4"]
}
```

### Firestore Queries

#### Create Group
```swift
let groupData: [String: Any] = [
    "type": "group",
    "groupName": groupName,
    "groupImageUrl": groupImageUrl ?? NSNull(),
    "participantIds": participantIds,
    "participants": participantsMap,
    "createdAt": FieldValue.serverTimestamp(),
    "createdBy": currentUserId,
    "updatedAt": FieldValue.serverTimestamp(),
    "lastMessage": NSNull()
]

let ref = try await db.collection("conversations").addDocument(data: groupData)
return ref.documentID
```

#### Fetch Group Participants
```swift
// Fetch user documents for all participant IDs
let userRefs = participantIds.map { db.collection("users").document($0) }
let users = try await db.getDocuments(userRefs)
```

### UI Component Structure

```
CreateGroupView
├── TextField (group name)
├── Text ("Add Participants")
├── SearchBar (filter participants)
└── List (participant selection)
    └── ParticipantSelectionRow
        ├── ProfileImageView
        ├── VStack (name, email)
        └── Checkbox
└── Button ("Create Group")

GroupInfoView
├── VStack (header)
│   ├── ProfileImageView (group icon, 80pt)
│   ├── Text (group name)
│   └── Text (participant count)
└── ParticipantListView
    └── List (participants)
        └── ParticipantRow
            ├── ProfileImageView
            ├── OnlineStatusIndicator
            ├── VStack (name, email)
            └── Text ("You") if current user

MessageBubbleView (Updated)
├── if isGroupMessage && isFromOtherUser:
│   └── Text (sender name)
├── HStack (message bubble)
│   └── ... (existing bubble content)
└── if isGroupMessage && isFromCurrentUser:
    └── Text ("Read by X/Y")
```

### Performance Considerations

1. **Participant Fetching:** Batch fetch user details for group participants
2. **Large Groups:** Paginate participant list if 50+ participants (future)
3. **Message Display:** Sender name adds minimal overhead
4. **Read Receipts:** Calculate read count on client to avoid queries
5. **Group Icon:** Use cached default icon, lazy load custom images (future)

### Real-Time Sync

1. **Group Messages:** Existing Firestore listeners work for groups (no changes needed)
2. **Participant Updates:** Future PRs will add listeners for participant changes
3. **Group Info Changes:** Future PRs will sync group name/image changes

---

## Success Metrics

### Functional Success
- ✅ Users can create groups with 3+ participants
- ✅ Group appears in conversation list after creation
- ✅ Group messages display sender names
- ✅ All participants receive group messages in real-time
- ✅ Group read receipts show "Read by X/Y" format
- ✅ Group info view displays all participants
- ✅ Participant online status shows correctly
- ✅ Group messages work with optimistic UI
- ✅ Offline queue works for group messages

### Technical Success
- ✅ Group creation writes correct Firestore document structure
- ✅ Group conversations filter correctly in queries
- ✅ Message sending/receiving identical for direct and group
- ✅ Read receipt logic works for multi-participant groups
- ✅ Participant list loads efficiently

### User Experience Success
- ✅ Group creation flow is intuitive
- ✅ Sender names are clearly visible in group chats
- ✅ Read receipts provide useful feedback ("Read by 3/5")
- ✅ Group info view is easy to navigate
- ✅ Groups feel like natural extension of direct chats
- ✅ No confusion between direct and group chats

---

## Acceptance Criteria

### Must Have
- [ ] "New Group" option accessible from conversation list
- [ ] CreateGroupView displays with name field and participant picker
- [ ] User can search and multi-select participants
- [ ] "Create Group" button disabled until name + 2+ participants selected
- [ ] Group creation writes Firestore document with correct structure
- [ ] Group appears in conversation list after creation
- [ ] Group row shows group icon, group name, and last message with sender name
- [ ] Tapping group row navigates to ChatView
- [ ] ChatView header shows group name and participant count
- [ ] Received group messages display sender name above bubble
- [ ] Sent group messages do NOT show sender name
- [ ] Message sending works identically to direct chats
- [ ] All participants receive group messages in real-time
- [ ] Group messages support optimistic UI
- [ ] Group messages support offline queue
- [ ] Read receipts show "Read by X/Y" for sent messages in groups
- [ ] Tapping group name navigates to GroupInfoView
- [ ] GroupInfoView displays group icon, name, and participant count
- [ ] ParticipantListView shows all group participants
- [ ] Participant rows show profile image, name, email, and online status
- [ ] Current user shown first in participant list with "You" label

### Should Have
- [ ] Participant search filters in real-time
- [ ] Selected participant count displays during creation
- [ ] Group icon uses distinctive default image
- [ ] Sender names use consistent color (secondary gray)
- [ ] Read receipt count updates in real-time
- [ ] Participant list sorted (you, online, offline, alphabetical)
- [ ] VoiceOver labels work correctly

### Nice to Have
- [ ] Group creation animations (slide in)
- [ ] Participant selection with checkbox animations
- [ ] Group icon placeholder is visually appealing
- [ ] Read receipt count animates when changing
- [ ] Haptic feedback on group creation
- [ ] Participant count badge in group header

---

## Implementation Notes for Developers

### Key Files to Create

1. **`Views/Group/CreateGroupView.swift`**
   - Group creation UI
   - Group name text field
   - Multi-select participant picker
   - Search/filter functionality
   - Create button and logic

2. **`Views/Group/GroupInfoView.swift`**
   - Group info display screen
   - Group icon, name, participant count
   - Embed ParticipantListView
   - Navigation from ChatView

3. **`Views/Group/ParticipantListView.swift`**
   - Reusable participant list component
   - Displays all group participants
   - Shows online status
   - Used in GroupInfoView

4. **`Views/Group/ParticipantRow.swift`** (optional, can inline)
   - Individual participant row UI
   - Profile image, name, email, online indicator

5. **`Views/Group/ParticipantSelectionRow.swift`**
   - Participant row with checkbox
   - Used in CreateGroupView
   - Handles selection state

6. **`ViewModels/GroupInfoViewModel.swift`**
   - State management for GroupInfoView
   - Load participant details
   - Handle participant updates

### Key Files to Modify

1. **`Services/ConversationService.swift`**
   - Add `createGroupConversation()` method
   - Add `getGroupDetails()` method
   - Ensure conversation queries work for both types

2. **`Views/Chat/MessageBubbleView.swift`**
   - Add sender name display for group messages
   - Conditional: show name only if group && not from current user
   - Add "Read by X/Y" display for group sent messages

3. **`Views/Chat/MessageStatusView.swift`**
   - Add "Read by X/Y" format for groups
   - Calculate X and Y from readBy array and participantIds

4. **`Views/Chat/ChatView.swift`**
   - Add tap gesture on navigation title to open GroupInfoView
   - Update subtitle to show participant count for groups

5. **`Views/ConversationList/ConversationListView.swift`**
   - Add "New Group" option to FAB menu or separate button
   - Present CreateGroupView on tap

6. **`Views/ConversationList/ConversationRowView.swift`**
   - Adapt for group display (group icon, group name)
   - Show sender name in last message preview for groups
   - Hide online status for groups

7. **`ViewModels/ChatViewModel.swift`**
   - Add `isGroupConversation` computed property
   - Pass conversation type to views for conditional rendering

8. **`Models/Conversation.swift`**
   - Add `ConversationType` enum
   - Add `groupName`, `groupImageUrl`, `createdBy` properties
   - Add `ParticipantInfo` nested struct if not exists

### Implementation Steps

#### Phase 1: Group Creation (Core)
1. Create `CreateGroupView.swift` with UI layout
2. Add participant selection logic with multi-select
3. Implement `createGroupConversation()` in ConversationService
4. Wire up "New Group" button in conversation list
5. Test group creation flow

#### Phase 2: Group Display (Conversation List)
6. Update `ConversationRowView` to handle group type
7. Show group icon and group name
8. Update last message preview with sender name
9. Test group rows display correctly

#### Phase 3: Group Chat UI (Messages)
10. Update `MessageBubbleView` to show sender names in groups
11. Add conditional rendering based on `isGroupConversation`
12. Test group message display
13. Verify sent vs received messages look correct

#### Phase 4: Group Info View
14. Create `GroupInfoView.swift` with layout
15. Create `ParticipantListView.swift` component
16. Add navigation from ChatView header
17. Load participant details in GroupInfoViewModel
18. Test group info view

#### Phase 5: Group Read Receipts
19. Update `MessageStatusView` to show "Read by X/Y"
20. Calculate read count for group messages
21. Test read receipts in groups
22. Verify counts update in real-time

#### Phase 6: Polish & Testing
23. Add VoiceOver labels
24. Test with 3, 5, 10, 20 participants
25. Test group creation edge cases
26. Performance testing with large groups

### Testing Scenarios

#### Group Creation
1. **Basic creation:**
   - Create group with 3 users
   - Verify appears in conversation list
   - Open group chat
   - Send message

2. **Participant selection:**
   - Select 0 participants → button disabled
   - Select 1 participant → button disabled
   - Select 2+ participants → button enabled
   - Search for user → filters list
   - Deselect all → button disabled again

3. **Edge cases:**
   - Empty group name → validation error
   - Very long group name (100 chars) → truncate or limit
   - 20 participants → test performance

#### Group Messaging
1. **Three-device test:**
   - User A, B, C in group
   - User A sends message
   - User B and C receive immediately
   - Sender name shows for B and C
   - No sender name for User A

2. **Read receipts:**
   - User A sends message in 5-person group
   - User A sees "Read by 0/4"
   - User B opens chat → "Read by 1/4"
   - User C opens chat → "Read by 2/4"
   - Users D and E open → "Read by 4/4"

3. **Message flow:**
   - Send 10 rapid messages in group
   - All messages deliver to all participants
   - Sender names show correctly
   - Optimistic UI works

#### Group Info
1. **View participants:**
   - Open GroupInfoView
   - Verify all participants shown
   - Verify online status correct
   - Verify "You" label on current user

2. **Large groups:**
   - Create group with 30 participants
   - Open group info
   - Verify scrolling works
   - Verify performance acceptable

#### Edge Cases
1. **Offline group creation:** Try creating group offline → error handling
2. **Concurrent group creation:** Two users create same group simultaneously
3. **Group with deleted user:** User in group is deleted from Firebase
4. **Very active group:** 100 messages sent rapidly → all deliver

---

## Related Documentation

- **Main PRD:** `/PRD.md`
- **Core Messaging PRD:** `/tasks/prd-core-messaging.md`
- **Read Receipts PRD:** `/tasks/prd-read-receipts.md`
- **Building Phases:** `/building-phases.md` (PR #12)
- **Conversation Model:** `/NexusAI/Models/Conversation.swift`
- **ConversationService:** `/NexusAI/Services/ConversationService.swift`
- **ChatViewModel:** `/NexusAI/ViewModels/ChatViewModel.swift`

---

## Dependencies & Prerequisites

### Must Be Complete Before Starting
- ✅ **PR #5:** Conversation List Screen
- ✅ **PR #6:** Chat Screen UI
- ✅ **PR #7:** Message Sending & Optimistic UI
- ✅ **PR #8:** Real-Time Message Sync
- ⏳ **PR #10:** Read Receipts (recommended but not strictly required)

### Infrastructure Already In Place
- ✅ Conversation model supports `type` field ("direct" or "group")
- ✅ Message sending works for any conversation type
- ✅ Real-time listeners work for all conversations
- ✅ Optimistic UI and offline queue work universally

### What's New in This PR
- ❌ Group creation UI (CreateGroupView) - NEW
- ❌ Group info view (GroupInfoView) - NEW
- ❌ Participant list display - NEW
- ❌ Multi-select participant picker - NEW
- ❌ Sender name display in group messages - NEW
- ❌ Group-specific read receipts ("Read by X/Y") - NEW
- ❌ Group conversation creation logic - NEW

---

**Last Updated:** October 21, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PR #12 - Group Chat Functionality  
**Branch:** `feature/group-chat`

---

**Priority:** 🔴 HIGH - Critical MVP Feature  
**Complexity:** ⭐⭐⭐⭐ Medium-High (4/5)  
**Estimated Effort:** 4-5 hours

