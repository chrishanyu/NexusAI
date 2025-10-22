## Relevant Files

- `NexusAI/Models/Conversation.swift` - Update to add group-specific fields (ConversationType enum, groupName, groupImageUrl, createdBy, ParticipantInfo)
- `NexusAI/Services/ConversationService.swift` - Add createGroupConversation(), getGroupDetails() methods
- `NexusAI/Views/Group/CreateGroupView.swift` - NEW: Group creation UI with name field and participant picker
- `NexusAI/Views/Group/ParticipantSelectionRow.swift` - NEW: Participant row with checkbox for selection
- `NexusAI/Views/Group/GroupInfoView.swift` - NEW: Group info display screen
- `NexusAI/Views/Group/ParticipantListView.swift` - NEW: Reusable participant list component
- `NexusAI/Views/Group/ParticipantRow.swift` - NEW: Individual participant row UI
- `NexusAI/ViewModels/GroupInfoViewModel.swift` - NEW: State management for GroupInfoView
- `NexusAI/Views/ConversationList/ConversationListView.swift` - Add "New Group" option to UI
- `NexusAI/Views/ConversationList/ConversationRowView.swift` - Update to display groups (group icon, group name, sender prefix)
- `NexusAI/Views/Chat/ChatView.swift` - Add group-specific header (participant count, tap to open GroupInfoView)
- `NexusAI/Views/Chat/MessageBubbleView.swift` - Add sender name display for group messages
- `NexusAI/Views/Chat/MessageStatusView.swift` - Add "Read by X/Y" format for group read receipts
- `NexusAI/ViewModels/ChatViewModel.swift` - Add isGroupConversation computed property

### Notes

- Unit tests should be added for new ViewModels and Services
- Test group creation, messaging, and read receipts with multiple users
- Use existing infrastructure (message sending, real-time sync, optimistic UI) - minimal changes needed

## Tasks

- [x] 1.0 Update Data Models for Group Support
  - [x] 1.1 Add `ConversationType` enum to Conversation model with cases: direct, group
  - [x] 1.2 Add group-specific properties to Conversation: `groupName: String?`, `groupImageUrl: String?`, `createdBy: String?`
  - [x] 1.3 Add nested `ParticipantInfo` struct with displayName and profileImageUrl properties
  - [x] 1.4 Ensure `participants` map uses `[String: ParticipantInfo]` type
  - [x] 1.5 Verify Conversation model properly encodes/decodes all new fields
  - [x] 1.6 Add computed property `isGroup` to Conversation for convenience checks

- [x] 2.0 Implement Group Creation Flow
  - [x] 2.1 Create `CreateGroupView.swift` with basic layout (navigation bar, group name field, participant section, create button)
  - [x] 2.2 Add TextField for group name with validation (1-50 characters, required)
  - [x] 2.3 Create `ParticipantSelectionRow.swift` component with profile image, name, email, and checkbox
  - [x] 2.4 Add searchable participant list that fetches all users from Firestore (excluding current user)
  - [x] 2.5 Implement multi-select logic with checkbox state management
  - [x] 2.6 Add selected participant count badge display (e.g., "3 selected")
  - [x] 2.7 Implement search/filter functionality for participant list
  - [x] 2.8 Add validation: "Create Group" button disabled if name empty or fewer than 2 participants selected
  - [x] 2.9 Add `createGroupConversation()` method to ConversationService that writes group document to Firestore
  - [x] 2.10 Build participants map with ParticipantInfo for each selected user
  - [x] 2.11 On successful creation, navigate to new group's ChatView
  - [x] 2.12 Add error handling and display error messages on failure

- [x] 3.0 Update Conversation List for Group Display
  - [x] 3.1 Add "New Group" button or menu option to ConversationListView (alongside existing "New Message")
  - [x] 3.2 Present CreateGroupView sheet when "New Group" tapped
  - [x] 3.3 Update ConversationRowView to detect conversation type (direct vs group)
  - [x] 3.4 For group rows, display group icon instead of user profile image
  - [x] 3.5 For group rows, display group name instead of user name
  - [x] 3.6 Update last message preview for groups to show sender name prefix: "[SenderName]: Message text"
  - [x] 3.7 Show "You: Message text" if current user sent the last message in group
  - [x] 3.8 Hide online status indicator for group rows (only show for direct chats)
  - [x] 3.9 Ensure unread badge displays correctly for group conversations

- [x] 4.0 Enhance Chat UI for Group Messages
  - [x] 4.1 Add `isGroupConversation` computed property to ChatViewModel
  - [x] 4.2 Update ChatView navigation bar to show group name for groups
  - [x] 4.3 Update ChatView subtitle to show participant count for groups (e.g., "3 participants")
  - [x] 4.4 Add tap gesture on navigation title/header to open GroupInfoView for groups
  - [x] 4.5 Update MessageBubbleView to conditionally show sender name for received messages in groups
  - [x] 4.6 Display sender name above message bubble in 13pt semibold gray text with 4pt spacing
  - [x] 4.7 Ensure sender name only shows for messages from other users (not current user's messages)
  - [x] 4.8 Verify message sending, optimistic UI, and offline queue work identically in groups
  - [x] 4.9 Test that all participants receive group messages in real-time via existing listeners

- [x] 5.0 Implement Group Info View
  - [x] 5.1 Create `GroupInfoView.swift` with header section (group icon, name, participant count)
  - [x] 5.2 Add large group icon display (80pt diameter, centered)
  - [x] 5.3 Display group name below icon (24pt semibold, centered)
  - [x] 5.4 Display participant count below name (e.g., "5 participants")
  - [x] 5.5 Create `ParticipantListView.swift` component for displaying all participants
  - [x] 5.6 Create `ParticipantRow.swift` with profile image (40pt), name, email, and online status indicator
  - [x] 5.7 Create `GroupInfoViewModel.swift` to manage state and load participant details
  - [x] 5.8 Implement `loadParticipants()` method to fetch user details for all participantIds
  - [x] 5.9 Sort participants: current user first (with "You" label), then online users, then offline, then alphabetically
  - [x] 5.10 Add section header "PARTICIPANTS" above participant list
  - [x] 5.11 Ensure participant list is scrollable for large groups
  - [x] 5.12 Wire up navigation from ChatView header tap to GroupInfoView

- [x] 6.0 Add Group-Specific Read Receipts
  - [x] 6.1 Update MessageStatusView to detect group conversations
  - [x] 6.2 For group sent messages, calculate read count: X = readBy.count (excluding sender)
  - [x] 6.3 Calculate total recipient count: Y = participantIds.count - 1 (all except sender)
  - [x] 6.4 Display "Read by X/Y" format in 12pt gray text, right-aligned below message bubble
  - [x] 6.5 Only show read receipt for sent messages with 1+ reads
  - [x] 6.6 Ensure read receipt count updates in real-time as participants read messages
  - [x] 6.7 Verify read receipt logic works correctly with existing markMessagesAsRead() from PR #10

- [x] 7.0 Testing and Polish
  - [x] 7.1 Test group creation with 3, 5, and 10 participants
  - [x] 7.2 Test participant selection edge cases (0, 1, 2+ participants)
  - [x] 7.3 Test search/filter functionality in participant picker
  - [x] 7.4 Test group creation with empty name, very long name (50+ chars)
  - [x] 7.5 Test three-device group messaging: verify all participants receive messages with correct sender names
  - [x] 7.6 Test group read receipts: send message, verify "Read by X/Y" updates as participants open chat
  - [x] 7.7 Test GroupInfoView displays all participants correctly with online status
  - [x] 7.8 Test offline group message sending (should queue and send when online)
  - [x] 7.9 Test rapid message sending in groups (10+ messages quickly)
  - [x] 7.10 Add VoiceOver labels for accessibility (group name field, participant selection, read receipts)
  - [x] 7.11 Test Dynamic Type support (text scales with system font size)
  - [x] 7.12 Verify group conversations persist correctly and appear after app restart
  - [x] 7.13 Performance test with 20+ participants (creation, messaging, info view)
  - [x] 7.14 Test that groups and direct chats can coexist in conversation list without issues

