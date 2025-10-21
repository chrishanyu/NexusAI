# Active Context

## Current Focus

**Sprint:** MVP Foundation  
**Phase:** PR #3 - Firebase Services Layer  
**Status:** ✅ COMPLETE - All services implemented and building successfully

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

3. ✅ **Firebase Services Layer (PR #3 - JUST COMPLETED)**
   - `FirebaseService.swift` - Firebase singleton with offline persistence (100MB cache)
   - `AuthService.swift` - Email/password authentication, user profile management
   - `ConversationService.swift` - Direct/group conversation CRUD, real-time listeners
   - `MessageService.swift` - Message sending with optimistic UI, status tracking, pagination
   - `PresenceService.swift` - Online/offline status, typing indicators with auto-expiration
   - `LocalStorageService.swift` - SwiftData persistence for offline caching

**Build Status:** ✅ All services compile successfully, no errors

## Next Immediate Steps

### PR #4: Authentication Flow
**Priority:** HIGH - Required for all subsequent features

**Files to Create:**
1. `ViewModels/AuthViewModel.swift`
   - Auth state management
   - Login/signup logic
   - Error handling
   - Loading states

2. `Views/Auth/LoginView.swift`
   - Email/password input fields
   - Login button
   - Link to SignUpView
   - Error display

3. `Views/Auth/SignUpView.swift`
   - Email, password, display name inputs
   - Sign up button
   - Input validation
   - Link to LoginView

4. `Views/Auth/ProfileSetupView.swift`
   - Display name configuration
   - Optional profile image
   - Completion flow

5. Update `NexusAIApp.swift`
   - Auth state listener
   - Conditional navigation (logged in → conversation list, logged out → login)

**Success Criteria:**
- Users can sign up with email/password
- Users can log in and see conversation list
- Auth state persists across app restarts
- Proper error handling for auth failures

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

4. **Email/Password Auth (Not Google Sign-In)**
   - Reason: Simpler for MVP, faster testing
   - Impact: Can add social auth post-MVP

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
- `feature/firebase-service` - ✅ PR #3 complete, ready to merge
- Next: `feature/authentication` (PR #4)

### Files Recently Created (PR #3)
1. `NexusAI/Services/FirebaseService.swift` - Firebase singleton, offline persistence
2. `NexusAI/Services/AuthService.swift` - Authentication and user management
3. `NexusAI/Services/ConversationService.swift` - Conversation CRUD and listeners
4. `NexusAI/Services/MessageService.swift` - Message operations and real-time sync
5. `NexusAI/Services/PresenceService.swift` - Presence and typing indicators
6. `NexusAI/Services/LocalStorageService.swift` - SwiftData caching and offline queue

### Key Implementation Details
- **AuthService:** Includes chunked user fetching (max 10 per Firestore 'in' query)
- **MessageService:** Optimistic UI with localId, pagination support (50 messages/page)
- **PresenceService:** Typing indicators with 3s auto-expiration using Timer
- **LocalStorageService:** SwiftData models for cached messages, queued messages, cached conversations

## Testing Status

### Manual Testing Done
- ✅ Project builds successfully
- ✅ Firebase SDK loads without errors
- ✅ Models compile and conform to Codable

### Testing Needed
- [ ] Service layer integration with Firestore
- [ ] Real-time listener functionality
- [ ] Offline persistence with SwiftData
- [ ] Authentication flow
- [ ] Message sending and receiving

## Next Session Priorities

### Immediate (Next Work Session)
1. **Complete PR #2:** Finalize any model adjustments
2. **Start PR #3:** Begin Services layer implementation
   - Create FirebaseService.swift
   - Create AuthService.swift
   - Create ConversationService.swift
   - Create MessageService.swift

### Short-Term (This Week)
1. **Complete PR #3:** All services implemented and tested
2. **Start PR #4:** Authentication flow (ViewModels + Views)
3. **Start PR #5:** Conversation list screen

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

