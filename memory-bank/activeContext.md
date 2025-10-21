# Active Context

## Current Focus

**Sprint:** MVP Foundation  
**Phase:** PR #4 - Authentication Flow  
**Status:** ✅ COMPLETE - Google Sign-In fully implemented and tested

## What We're Building Right Now

### Just Completed
1. ✅ **Project Setup (PR #1)**
   - Xcode project initialized
   - Firebase SDK added via Swift Package Manager
   - GoogleService-Info.plist configured
   - Basic folder structure created
   - Firestore security rules defined

2. ✅ **Core Models (PR #2)**
   - `User.swift` - User profile with Firebase Auth integration
   - `Conversation.swift` - Direct and group conversation types
   - `Message.swift` - Message with status tracking
   - `MessageStatus.swift` - Enum for sending/sent/delivered/read
   - `TypingIndicator.swift` - Typing state model
   - `Constants.swift` - App-wide constants
   - `Date+Extensions.swift` - Smart timestamp formatting

3. ✅ **Firebase Services Layer (PR #3)**
   - `FirebaseService.swift` - Firebase singleton with offline persistence (100MB cache)
   - `AuthService.swift` - Authentication and user profile management
   - `ConversationService.swift` - Direct/group conversation CRUD, real-time listeners
   - `MessageService.swift` - Message sending with optimistic UI, status tracking, pagination
   - `PresenceService.swift` - Online/offline status, typing indicators with auto-expiration
   - `LocalStorageService.swift` - SwiftData persistence for offline caching

4. ✅ **Authentication Flow (PR #4 - JUST COMPLETED)**
   - `AuthService.swift` - Google Sign-In integration with Firebase Auth, Firestore user profile creation/update with retry logic
   - `AuthServiceProtocol.swift` - Protocol for dependency injection and testability
   - `MockAuthService.swift` - Mock implementation for unit testing
   - `AuthViewModel.swift` - Auth state management with loading states, error handling, and auth state listener
   - `LoginView.swift` - Google Sign-In UI with accessibility support, haptic feedback, and inline error display
   - `NexusAIApp.swift` - Auth-based navigation with conditional LoginView/ContentView
   - `ContentView.swift` - Temporary authenticated home screen with user info and sign out button
   - `AuthServiceTests.swift` - Unit tests for AuthService using MockAuthService

**Build Status:** ✅ All features compile and tested successfully, no errors

## Next Immediate Steps

### PR #5: Conversation List Screen
**Priority:** HIGH - Core navigation hub

**Files to Create:**
1. `ViewModels/ConversationListViewModel.swift`
   - Conversation list state management
   - Real-time conversation updates
   - Search/filter logic
   - Create conversation flow

2. `Views/ConversationList/ConversationListView.swift`
   - List of conversations
   - Search bar
   - Create conversation button
   - Navigation to ChatView

3. `Views/ConversationList/ConversationRowView.swift`
   - Individual conversation row
   - Last message preview
   - Unread badge
   - Online status indicator
   - Timestamp

4. `Views/ConversationList/CreateConversationView.swift`
   - User search/selection
   - Create direct or group conversation
   - Validation

**Success Criteria:**
- Users can see their conversation list
- Real-time updates when new messages arrive
- Can navigate to individual conversations
- Can create new direct conversations
- Conversations sorted by last message timestamp

## Recent Decisions

### Architecture Decisions
1. **MVVM Over Other Patterns**
   - Reason: Standard for SwiftUI, clean separation
   - Impact: All views use ViewModels, no direct Firebase access

2. **Hybrid Storage (SwiftData + Firestore)**
   - Reason: Fast local reads + real-time sync
   - Impact: Services manage both persistence layers

3. **Optimistic UI for Messages**
   - Reason: Instant feedback critical for messaging UX
   - Impact: Messages use localId, complex merge logic
   - Implementation: MessageService has optimistic UI support

4. **Google Sign-In Only (Not Email/Password)**
   - Reason: Single unified authentication experience, leverages existing Google accounts
   - Impact: Simpler user flow, no password management, pulls email/display name/photo from Google
   - Implementation: Uses GoogleSignIn SDK + Firebase Auth credential conversion

5. **Protocol-Based Dependency Injection**
   - Reason: Enables unit testing with mock services
   - Impact: Services implement protocols, ViewModels inject protocol dependencies
   - Implementation: AuthServiceProtocol + MockAuthService for testing

### Technical Decisions (PR #3)
1. **Swift Concurrency (async/await) Over Completion Handlers**
   - Modern, cleaner code
   - All Firebase operations use async/await
   - ✅ Implemented across all services

2. **Firestore Snapshot Listeners for Real-Time**
   - Built-in real-time updates
   - Auto-cleanup on detach
   - ✅ Implemented in ConversationService, MessageService, PresenceService

3. **Singleton Services for Global State**
   - FirebaseService, PresenceManager, NotificationManager
   - Other services instantiated for testability
   - ✅ FirebaseService implemented as singleton

4. **Message Queue Pattern for Offline**
   - Queue messages when offline
   - Flush on reconnection
   - Ensures no message loss
   - ✅ LocalStorageService with QueuedMessage model

5. **Typing Indicator Auto-Expiration**
   - Decided: 3-second timeout with Timer
   - Prevents stale "typing..." indicators
   - ✅ Implemented in PresenceService

6. **Firestore Offline Cache Size**
   - Decided: 100MB persistent cache
   - Balances performance with disk usage
   - ✅ Configured in FirebaseService

## Active Challenges

### Technical Challenges
1. **Message Deduplication**
   - Problem: Optimistic messages + Firestore messages can duplicate
   - Solution: Use localId to match and merge
   - Status: Designed, not yet implemented

2. **Offline Queue Ordering**
   - Problem: Messages must send in order when reconnecting
   - Solution: Sequential flush with timestamp ordering
   - Status: Designed, not yet implemented

3. **Firestore Security Rules**
   - Problem: Rules must be tight but allow real-time listeners
   - Solution: Participant-based access control
   - Status: Defined in firestore.rules, not tested yet

### Process Challenges
1. **Rapid MVP Timeline**
   - Challenge: 24-hour target for MVP
   - Mitigation: Focus on critical path PRs (1-8, 10, 12, 13, 15)
   - Status: On track with foundation

2. **Testing on Simulator Only**
   - Challenge: Can't test real push notifications
   - Mitigation: Use .apns files for simulator testing
   - Status: Deferred to PR #13

## Questions & Unknowns

### Open Questions
1. **Message Pagination Strategy**
   - How many initial messages to load? (Proposed: 50)
   - How to handle infinite scroll? (Proposed: Load 50 more on scroll top)
   - Status: Not yet decided

2. **Typing Indicator Expiration**
   - How long before "typing" expires? (Proposed: 3 seconds)
   - Should we clean up expired indicators? (Proposed: Yes, client-side)
   - Status: Not yet implemented

3. **Group Chat Limits**
   - Maximum group size? (Proposed: No limit for MVP, optimize later)
   - Should we paginate participant lists? (Proposed: Not for MVP)
   - Status: Not yet decided

### Resolved Questions
1. ✅ **Authentication Method:** Email/Password (simpler for MVP)
2. ✅ **Offline Strategy:** Message queue with auto-flush
3. ✅ **Real-time vs Polling:** Firestore snapshot listeners (real-time)
4. ✅ **Local Storage:** SwiftData for iOS 17+ compatibility

## Dependencies & Blockers

### No Current Blockers
All dependencies available:
- ✅ Xcode 15+ installed
- ✅ Firebase project configured
- ✅ GoogleService-Info.plist added
- ✅ Swift Package Manager dependencies resolved

### External Dependencies
1. **Firebase Services**
   - Auth, Firestore, Cloud Messaging
   - Status: Configured, ready to use

2. **Cloud Functions (Future)**
   - For push notifications and AI features
   - Status: Not required for initial PRs, defer to PR #13+

## Work In Progress

### Active Branches
- `feature/auth` - ✅ PR #4 complete, ready to merge
- Next: `feature/conversation-list` (PR #5)

### Files Recently Created (PR #4)
1. `NexusAI/Services/AuthService.swift` - Updated with Google Sign-In integration
2. `NexusAI/Services/AuthServiceProtocol.swift` - Protocol for dependency injection
3. `NexusAI/ViewModels/AuthViewModel.swift` - Auth state management, error handling
4. `NexusAI/Views/Auth/LoginView.swift` - Google Sign-In UI with accessibility
5. `NexusAI/NexusAIApp.swift` - Updated with auth-based navigation
6. `NexusAI/ContentView.swift` - Temporary authenticated home screen
7. `NexusAITests/Mocks/MockAuthService.swift` - Mock service for testing
8. `NexusAITests/Services/AuthServiceTests.swift` - Unit tests

### Key Implementation Details
- **AuthService:** Google Sign-In flow with Firebase credential conversion, Firestore user profile creation/update with 2-attempt retry logic
- **AuthViewModel:** Auth state listener, loading states, user-friendly error messages with auto-dismissal
- **LoginView:** Haptic feedback, VoiceOver accessibility, inline error display, dynamic button states
- **App Navigation:** Conditional rendering based on `isAuthenticated` state
- **Testing:** Protocol-based mocking enables comprehensive unit tests without Firebase dependencies

## Testing Status

### Manual Testing Done
- ✅ Project builds successfully
- ✅ Firebase SDK loads without errors
- ✅ Models compile and conform to Codable
- ✅ Google Sign-In authentication flow
- ✅ Firestore user profile creation/update
- ✅ Auth state persistence across app restarts
- ✅ Sign out functionality
- ✅ Error handling (network failures, cancelled sign-in)

### Unit Tests Completed
- ✅ AuthService unit tests with MockAuthService
- ✅ Protocol-based dependency injection pattern validated

### Testing Needed
- [ ] Service layer integration with Firestore (ConversationService, MessageService)
- [ ] Real-time listener functionality
- [ ] Offline persistence with SwiftData
- [ ] Message sending and receiving

## Next Session Priorities

### Immediate (Next Work Session)
1. **Start PR #5:** Conversation List Screen
   - Create ConversationListViewModel
   - Create ConversationListView
   - Create ConversationRowView
   - Create CreateConversationView
   - Wire up ConversationService for real-time updates

2. **Merge PR #4:** Authentication flow branch ready to merge

### Short-Term (This Week)
1. **Complete PR #5:** Conversation list with real-time updates
2. **Start PR #6:** Chat screen UI
3. **Start PR #7:** Message sending with optimistic UI

### Medium-Term (Next Week)
1. **PRs #6-8:** Chat screen with real-time messaging
2. **PRs #9-10:** Typing indicators and read receipts
3. **PR #12:** Group chat functionality
4. **PR #15:** Offline support

## Context for Future Sessions

### What You Need to Know
1. **Models are defined** - User, Conversation, Message, MessageStatus, TypingIndicator
2. **Architecture is MVVM** - Services layer next, then ViewModels, then Views
3. **Optimistic UI is critical** - Messages must feel instant
4. **Offline-first design** - Local queue, automatic sync
5. **Real-time listeners** - Firestore snapshots for instant updates

### Key Files to Reference
- `PRD.md` - Detailed requirements and database schema
- `architecture.md` - Visual architecture diagram
- `building-phases.md` - PR breakdown and build order
- `memory-bank/systemPatterns.md` - Architectural patterns
- `memory-bank/techContext.md` - Technical stack and decisions

### Current State Summary
**Phase:** Foundation building  
**Completed:** Models layer  
**Next:** Services layer  
**Goal:** Complete core messaging infrastructure by end of MVP sprint

