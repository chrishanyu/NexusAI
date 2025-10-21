# Active Context

## Current Focus

**Sprint:** MVP Foundation  
**Phase:** PR #2 - Core Models & Constants  
**Status:** Models created, ready for Services layer

## What We're Building Right Now

### Just Completed
1. ✅ **Project Setup (PR #1)**
   - Xcode project initialized
   - Firebase SDK added via Swift Package Manager
   - GoogleService-Info.plist configured
   - Basic folder structure created
   - Firestore security rules defined

2. ✅ **Core Models (PR #2 - In Progress)**
   - `User.swift` - User profile with Firebase Auth integration
   - `Conversation.swift` - Direct and group conversation types
   - `Message.swift` - Message with status tracking
   - `MessageStatus.swift` - Enum for sending/sent/delivered/read
   - `TypingIndicator.swift` - Typing state model
   - `Constants.swift` - App-wide constants
   - `Date+Extensions.swift` - Smart timestamp formatting

### Currently Staged Changes
Git shows several model files are staged but also have unstaged modifications:
- `Conversation.swift` - Modified
- `Message.swift` - Modified
- `MessageStatus.swift` - Modified
- `User.swift` - Modified
- `TypingIndicator.swift` - New file (untracked)

**Action Needed:** Review modifications, commit clean versions

## Next Immediate Steps

### PR #3: Firebase Services Layer
**Priority:** High - Foundation for all features

**Files to Create:**
1. `Services/FirebaseService.swift`
   - Firebase initialization
   - Firestore configuration
   - Enable offline persistence
   - Singleton pattern

2. `Services/AuthService.swift`
   - Email/password authentication
   - User profile CRUD
   - FCM token management
   - Auth state listener

3. `Services/ConversationService.swift`
   - Create conversations (direct and group)
   - List conversations for user
   - Update conversation metadata
   - Real-time conversation listener

4. `Services/MessageService.swift`
   - Send messages (with optimistic UI)
   - Listen to messages in conversation
   - Update message status (delivered, read)
   - Mark messages as read

5. `Services/PresenceService.swift`
   - Update online/offline status
   - Update lastSeen timestamp
   - Listen to participant presence
   - Typing indicator management

6. `Services/LocalStorageService.swift`
   - SwiftData persistence
   - Cache conversations and messages
   - Local message queue

**Success Criteria:**
- All services compile without errors
- Services handle async/await correctly
- Error handling for Firebase operations
- Ready to be called by ViewModels

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

4. **Email/Password Auth (Not Google Sign-In)**
   - Reason: Simpler for MVP, faster testing
   - Impact: Can add social auth post-MVP

### Technical Decisions
1. **Swift Concurrency (async/await) Over Completion Handlers**
   - Modern, cleaner code
   - All Firebase operations use async/await

2. **Firestore Snapshot Listeners for Real-Time**
   - Built-in real-time updates
   - Auto-cleanup on detach

3. **Singleton Services for Global State**
   - FirebaseService, PresenceManager, NotificationManager
   - Other services instantiated for testability

4. **Message Queue Pattern for Offline**
   - Queue messages when offline
   - Flush on reconnection
   - Ensures no message loss

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
- `main` - Current stable state (models defined)
- Next: `feature/firebase-services` (PR #3)

### Files Recently Modified
1. `NexusAI/Models/User.swift` - User model with Firestore integration
2. `NexusAI/Models/Conversation.swift` - Conversation types and metadata
3. `NexusAI/Models/Message.swift` - Message structure with status
4. `NexusAI/Models/MessageStatus.swift` - Status enum
5. `NexusAI/Models/TypingIndicator.swift` - Typing state (new, untracked)
6. `NexusAI/Utilities/Constants.swift` - App constants
7. `NexusAI/Utilities/Extensions/Date+Extensions.swift` - Date formatting

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

