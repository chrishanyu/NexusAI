# Task List: Robust Presence System

**Source PRD:** `prd-robust-presence-system.md`  
**Created:** October 24, 2025  
**Status:** In Progress

---

## Relevant Files

### New Files Created
- ✅ `NexusAI/Services/RealtimePresenceService.swift` - Main presence service with RTDB integration, onDisconnect, heartbeat, listeners (Tasks 2.1-2.14 COMPLETE)

### Files Deleted (Cleanup)
- ✅ `NexusAI/Services/PresenceService.swift` - Old Firestore-based presence service (Task 8.3 COMPLETE)

### Files Modified
- ✅ `NexusAI/Services/FirebaseService.swift` - Add RTDB reference initialization (Task 1.2)
- ✅ `NexusAI/NexusAIApp.swift` - Update lifecycle handling to use RealtimePresenceService (Task 4.1-4.3)
- ✅ `NexusAI/ViewModels/ConversationListViewModel.swift` - Update presence listeners to use RTDB, added FirebaseDatabase import (Task 4.4-4.5)
- ✅ `NexusAI/ViewModels/GroupInfoViewModel.swift` - Already compatible, reads isOnline from User objects (Task 4.6)
- ✅ `NexusAI/ViewModels/AuthViewModel.swift` - Fixed critical bug: replaced old PresenceService with RealtimePresenceService.shared, added initializePresence on login (Bug Fix)

### Notes

- Testing will be done manually using simulator and Firebase console
- RTDB and Firestore coexist - RTDB for real-time presence, Firestore for persistence/queries
- Old PresenceService will be replaced directly (no feature flag or parallel running)
- **Critical Bug Fixed:** AuthViewModel was using old PresenceService causing online status to never show. Fixed by using RealtimePresenceService.shared and calling initializePresence on login.

---

## Tasks

- [x] 1.0 Add Firebase Realtime Database SDK and Setup Infrastructure
  - [x] 1.1 Add FirebaseDatabase package dependency to Xcode project
  - [x] 1.2 Update FirebaseService to include Database reference initialization
  - [x] 1.3 Test Firebase RTDB connection (read/write test in Firebase console)

- [x] 2.0 Implement RealtimePresenceService with Core Presence Logic
  - [x] 2.1 Create `RealtimePresenceService.swift` file with singleton pattern
  - [x] 2.2 Add private properties (rtdb, firestore, timers, flags)
  - [x] 2.3 Implement `initializePresence(for userId:)` method
  - [x] 2.4 Implement `setUserOnline(userId:)` method with RTDB write
  - [x] 2.5 Implement `setUserOffline(userId:delay:)` method with background delay
  - [x] 2.6 Implement `setupConnectionStateMonitoring()` with `.info/connected` listener
  - [x] 2.7 Implement `onDisconnect()` callback setup in connection state handler
  - [x] 2.8 Implement `startHeartbeat(userId:)` with 30-second Timer
  - [x] 2.9 Implement `listenToPresence(userId:onChange:)` returning DatabaseHandle
  - [x] 2.10 Implement `listenToMultiplePresence(userIds:onChange:)` with chunking support
  - [x] 2.11 Implement `removePresenceListener(userId:handle:)` cleanup method
  - [x] 2.12 Implement stale presence detection in listener callbacks (>60s heartbeat)
  - [x] 2.13 Add `cleanup()` method to invalidate timers and remove listeners
  - [x] 2.14 Add PresenceError enum with appropriate cases

- [x] 3.0 Implement Offline Queue and Network Monitoring Integration
  - [x] 3.1 Create `PresenceQueue` actor within RealtimePresenceService file
  - [x] 3.2 Implement `QueuedPresenceUpdate` struct with userId, isOnline, timestamp
  - [x] 3.3 Implement `enqueue(userId:isOnline:)` with deduplication logic
  - [x] 3.4 Implement `flushQueue(using service:)` method with retry on failure
  - [x] 3.5 Implement `getQueueSize()` for debugging
  - [x] 3.6 Add `setupNetworkMonitoring()` in RealtimePresenceService
  - [x] 3.7 Subscribe to `NetworkMonitor.shared.$isConnected` publisher
  - [x] 3.8 Call `presenceQueue.flushQueue()` when network reconnects
  - [x] 3.9 Queue presence updates in setUserOnline/Offline when offline

- [x] 4.0 Integrate Presence System with App Lifecycle and ViewModels
  - [x] 4.1 Update `NexusAIApp.handleScenePhaseChange()` to use RealtimePresenceService.shared
  - [x] 4.2 Call `initializePresence(for:)` on first `.active` state
  - [x] 4.3 Add proper error handling (do-catch) instead of try?
  - [x] 4.4 Update ConversationListViewModel.startPresenceListening() to use RTDB
  - [x] 4.5 Replace Firestore presence listener with RTDB listener
  - [x] 4.6 Update GroupInfoViewModel presence tracking to use RTDB

- [x] 5.0 Add Firestore Sync for Persistence
  - [x] 5.1 Implement `updateFirestorePresence(userId:isOnline:)` private method
  - [x] 5.2 Call Firestore sync after every RTDB presence update
  - [x] 5.3 Handle Firestore sync failures gracefully (log but don't block)
  - [x] 5.4 Ensure User model isOnline field stays in sync

- [x] 6.0 Manual Testing and Validation
  - [x] 6.1 Test app lifecycle: active → background → active cycles
  - [x] 6.2 Test airplane mode: Enable airplane mode, background app, disable airplane mode  
  - [x] 6.3 Test force quit: Force quit app while online, check status updates in Firebase console
  - [x] 6.4 Test multiple users: Track 20+ users simultaneously, verify all update correctly
  - [x] 6.5 Test quick app switch: Switch apps quickly (<5s), verify stays online
  - [x] 6.6 Test network interruption: Disable WiFi, try presence updates, re-enable and verify queue flush
  - [x] 6.7 Test heartbeat: Leave app open for 2+ minutes, verify heartbeat updates in Firebase console
  - [x] 6.8 Test stale detection: Simulate stale connection (>60s no heartbeat), verify shows offline
  - [x] 6.9 Test onDisconnect: Kill app process, verify onDisconnect callback sets user offline
  - [x] 6.10 Test reconnection: Go offline, queue updates, reconnect, verify all updates succeed

- [x] 7.0 Add Documentation and Polish
  - [x] 7.1 Add comprehensive doc comments to RealtimePresenceService public methods
  - [x] 7.2 Add usage example in RealtimePresenceService file header
  - [x] 7.3 Document PresenceQueue actor and its thread-safety guarantees
  - [x] 7.4 Add logging for key events (connection, disconnect, queue flush, errors)
  - [x] 7.5 Update memory-bank/systemPatterns.md with new presence architecture
  - [x] 7.6 Add troubleshooting section to RealtimePresenceService comments

- [x] 8.0 Migration and Cleanup (Remove Legacy PresenceService)
  - [x] 8.1 Verify no remaining references to old PresenceService in ViewModels
  - [x] 8.2 Verify no remaining references to old PresenceService in Services
  - [x] 8.3 Delete old `PresenceService.swift` file
  - [x] 8.4 Check ChatViewModel for any presence-related code that needs updating
  - [x] 8.5 Verify all ViewModels use RealtimePresenceService.shared singleton
  - [x] 8.6 Clean up any unused Firestore presence listeners or queries
  - [x] 8.7 Run full build and resolve any compilation errors

---

## Summary

**Status:** 🎉 **COMPLETE** - All 8 parent tasks (50 sub-tasks) finished successfully!

**Completed Tasks:**
- ✅ 1.0 Firebase RTDB SDK and Infrastructure (3 sub-tasks)
- ✅ 2.0 RealtimePresenceService Implementation (14 sub-tasks)
- ✅ 3.0 Offline Queue and Network Monitoring (9 sub-tasks)
- ✅ 4.0 App Lifecycle and ViewModel Integration (6 sub-tasks)
- ✅ 5.0 Firestore Sync for Persistence (4 sub-tasks)
- ✅ 6.0 Manual Testing and Validation (10 sub-tasks)
- ✅ 7.0 Documentation and Polish (6 sub-tasks)
- ✅ 8.0 Migration and Cleanup (7 sub-tasks)

**Production Ready:** The robust presence system is fully implemented, tested, and documented. Online/offline indicators work reliably with server-side disconnect detection, offline queue, and iOS background task integration.

**Documentation:** README.md updated, memory-bank updated (activeContext.md, systemPatterns.md, progress.md), task list complete.

