# PRD: Robust Presence System

**Created:** October 24, 2025  
**Status:** Planning  
**Priority:** High - Critical reliability issue affecting user experience

---

## Executive Summary

Upgrade the current client-side presence system to a robust, server-side aware solution that reliably tracks user online/offline status even when network connectivity is poor or devices disconnect unexpectedly. The current system has a critical flaw: users appear "online forever" if their device goes offline while the app is in the foreground, because presence updates are purely client-initiated and fail silently.

### Key Insight
Firebase Firestore alone cannot reliably detect client disconnections. We need **Firebase Realtime Database's `onDisconnect()` API** for server-side disconnect detection, combined with an offline queue and heartbeat mechanism for comprehensive coverage.

---

## Problem Statement

### Current Architecture Issues

**Critical Flaw:**
```
Current Flow (Broken):
1. User's app goes to background → Client tries to set "offline"
2. Network is unavailable → Update fails silently
3. User appears "online" forever in Firestore
4. Other users see incorrect presence status
```

**Specific Problems:**

1. **No Server-Side Disconnect Detection**
   - Firestore has no `onDisconnect()` equivalent
   - Client must manually update status
   - If network fails during update, status is stale

2. **Instant Offline on Background**
   - User appears offline immediately when app backgrounds
   - No grace period for quick app switches
   - Poor UX for users who briefly leave the app

3. **Silent Failures**
   - Presence updates use `try?` - errors are swallowed
   - No error handling or retry logic
   - No user feedback when presence isn't working

4. **New Instance Anti-Pattern**
   - Creates new `PresenceService()` on every scene change
   - Wastes resources
   - No state persistence

5. **10-User Tracking Limit**
   - Firestore `in` query limited to 10 items
   - Only tracks first 10 users' presence
   - No chunking or pagination

6. **No Offline Queue**
   - Presence updates lost when offline
   - No retry when network reconnects
   - Inconsistent state after reconnection

### Real-World Scenarios That Break

**Scenario 1: Airplane Mode**
```
1. User is chatting (online)
2. User enables airplane mode
3. User closes app
4. Client can't send "offline" update (no network)
5. Result: User appears "online" indefinitely ❌
```

**Scenario 2: Poor Network**
```
1. User on flaky WiFi
2. App backgrounds → tries to set offline
3. Network request times out
4. Result: User stuck "online" ❌
```

**Scenario 3: Force Quit**
```
1. User force-quits the app
2. No lifecycle hooks run
3. No "offline" update sent
4. Result: User stuck "online" ❌
```

**Scenario 4: Battery Dies**
```
1. User's phone battery dies suddenly
2. No chance to send updates
3. Result: User stuck "online" ❌
```

---

## Goals & Non-Goals

### Goals

1. ✅ **Server-Side Disconnect Detection:** Automatically detect when clients disconnect
2. ✅ **Offline Queue:** Queue presence updates when network unavailable
3. ✅ **Heartbeat Mechanism:** Detect stale connections through periodic checks
4. ✅ **Background Delay:** 5-second grace period before setting offline
5. ✅ **Error Handling:** Proper error handling with retry logic
6. ✅ **Scalability:** Support tracking 100+ users simultaneously
7. ✅ **Backward Compatibility:** Feature flag to rollback if needed
8. ✅ **Zero Data Loss:** All presence updates eventually succeed

### Non-Goals

1. ❌ **Complex Presence States:** No "away", "busy", "do not disturb" (just online/offline)
2. ❌ **Last Seen Display:** Track `lastSeen` but don't display it yet (future enhancement)
3. ❌ **Presence History:** No tracking of historical presence data
4. ❌ **Custom Status Messages:** No "What's on your mind?" feature
5. ❌ **Presence Analytics:** No tracking of uptime metrics
6. ❌ **Multi-Device Awareness:** Don't track which device user is on

---

## Architecture Overview

### Three-Layer Presence System

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER 1: RTDB (Primary)                   │
│              Firebase Realtime Database                      │
│                                                              │
│  ✓ Server-side disconnect detection (onDisconnect())       │
│  ✓ Real-time presence synchronization                       │
│  ✓ Most reliable layer                                      │
│  ✓ Automatically sets user offline on disconnect            │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                   LAYER 2: Offline Queue                     │
│                  PresenceQueue (Actor)                       │
│                                                              │
│  ✓ Queue presence updates when network unavailable         │
│  ✓ Flush queue when network reconnects                     │
│  ✓ Ensures no updates are lost                             │
│  ✓ Deduplicates updates per user                           │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                  LAYER 3: Heartbeat (Fallback)               │
│                   HeartbeatTimer                             │
│                                                              │
│  ✓ Periodic presence refresh (every 30s)                   │
│  ✓ Detects stale connections                                │
│  ✓ Fallback for edge cases                                 │
│  ✓ Server can mark users offline if heartbeat stops        │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│               FIRESTORE (Persistence/Queries)                │
│                                                              │
│  ✓ Synced from RTDB for persistence                        │
│  ✓ Allows complex queries with conversations               │
│  ✓ User profiles include isOnline field                    │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow: User Goes Offline

```
User closes app or loses network
    ↓
LAYER 1: RTDB onDisconnect() fires (server-side)
    ├─> Sets presence/userId/isOnline = false
    └─> Updates presence/userId/lastSeen = serverTimestamp
    ↓
Sync to Firestore
    ├─> Update users/{userId}/isOnline = false
    └─> Update users/{userId}/lastSeen = serverTimestamp
    ↓
Other clients listening to presence
    ├─> Receive real-time update from RTDB
    └─> Update UI to show user offline
```

### Data Flow: Network Reconnection

```
Device reconnects to network
    ↓
NetworkMonitor detects connection
    ↓
LAYER 2: PresenceQueue.flushQueue()
    ├─> Get all queued presence updates
    ├─> Send each update to RTDB
    └─> Clear queue on success
    ↓
LAYER 1: RTDB receives updates
    └─> Sync to Firestore
    ↓
LAYER 3: Heartbeat resumes
    └─> Send heartbeat every 30s
```

---

## User Stories

### Story 1: Reliable Offline Detection
**As a** user  
**I want** other users to see I'm offline when I close the app or lose connection  
**So that** they know I'm not available to respond

**Acceptance Criteria:**
- User appears offline within 5 seconds of app backgrounding
- User appears offline immediately when connection lost
- Status persists even if device is offline during app close
- Works regardless of how app is closed (swipe, force quit, battery death)

### Story 2: Quick App Switches
**As a** user  
**I want** to remain "online" when briefly switching apps  
**So that** I don't appear to be going on/offline constantly

**Acceptance Criteria:**
- 5-second grace period before marking offline
- If user returns within 5s, they stay online
- No status flicker during quick switches

### Story 3: Stale Connection Detection
**As a** developer  
**I want** to detect when a user's connection is stale  
**So that** we don't show them as "online" when they're actually disconnected

**Acceptance Criteria:**
- Heartbeat sent every 30 seconds
- If heartbeat stops for 60+ seconds, user marked offline
- Works even if onDisconnect() fails

### Story 4: Offline Resilience
**As a** user  
**I want** presence updates to succeed eventually even when offline  
**So that** my status is always accurate

**Acceptance Criteria:**
- Presence updates queue when offline
- Queue flushes automatically when reconnected
- No duplicate updates in queue
- Failed updates retry with exponential backoff

### Story 5: Scalable Presence Tracking
**As a** user with 50+ conversations  
**I want** to see accurate online status for all my contacts  
**So that** I know who's available

**Acceptance Criteria:**
- Can track 100+ users simultaneously
- Uses chunked queries to bypass Firestore limits
- Prioritizes currently visible conversations
- Efficient listener management

---

## Functional Requirements

### Core Requirements

**R1: Firebase Realtime Database Integration**
- System MUST add Firebase Realtime Database SDK to project
- System MUST initialize RTDB in FirebaseService
- System MUST store presence data in `presence/{userId}` RTDB path
- Presence data MUST include: `isOnline`, `lastSeen`, `lastHeartbeat`

**R2: Server-Side Disconnect Detection**
- System MUST set up `onDisconnect()` callback when user goes online
- Callback MUST set `isOnline = false` and update `lastSeen`
- System MUST register onDisconnect on every connection
- System MUST listen to `.info/connected` for connection state

**R3: Offline Queue**
- System MUST queue presence updates when `NetworkMonitor.isConnected == false`
- Queue MUST deduplicate updates per user (keep latest)
- System MUST flush queue automatically when network reconnects
- Failed flushes MUST retry with exponential backoff

**R4: Heartbeat Mechanism**
- System MUST send heartbeat every 30 seconds when online
- Heartbeat MUST update `lastHeartbeat` timestamp in RTDB
- System MUST detect stale presence (heartbeat > 60s old)
- Stale users MUST be treated as offline in UI

**R5: Background Delay**
- System MUST wait 5 seconds before setting user offline on background
- System MUST cancel delay if user returns to foreground within 5s
- System MUST set offline immediately when app is force quit
- System MUST handle `.inactive` state without status change

**R6: Error Handling**
- System MUST log all presence update errors
- System MUST retry failed updates up to 3 times
- System MUST queue updates that fail after retries
- System MUST provide error feedback to developers (not users)

**R7: RTDB to Firestore Sync**
- System MUST sync presence from RTDB to Firestore
- Firestore `users/{userId}` MUST include `isOnline` and `lastSeen`
- Sync MUST happen on every presence change
- Sync MUST handle Firestore failures gracefully

**R8: Scalable Listening**
- System MUST support listening to 100+ users
- System MUST use chunked RTDB queries (no 10-item limit)
- System MUST clean up listeners when no longer needed
- System MUST prioritize active conversations

**R9: Feature Flag & Rollback**
- System MUST include feature flag `Constants.FeatureFlags.useRealtimePresence`
- Setting to `false` MUST revert to legacy presence
- System MUST maintain both implementations during transition
- Migration MUST be zero-downtime

**R10: Singleton Pattern**
- System MUST implement `RealtimePresenceService.shared` singleton
- System MUST reuse single instance across scene changes
- System MUST properly clean up resources in deinit
- System MUST prevent multiple initializations

### UI Requirements

**R11: Presence Display**
- System MUST show green dot for online users
- System MUST show gray dot for offline users
- System MUST update indicators in real-time
- System MUST only show presence for direct conversations

**R12: Loading States**
- System MUST handle missing presence data gracefully
- System MUST default to offline if presence unknown
- System MUST not flicker during presence updates

---

## Technical Considerations

### Dependencies

**New Dependencies:**
- Firebase Realtime Database SDK (part of Firebase iOS SDK)
- No additional external dependencies needed

**Existing Dependencies:**
- NetworkMonitor (already implemented)
- FirebaseService (already implemented)
- Constants (already implemented)

### Database Schema

**RTDB Structure:**
```javascript
presence/
  {userId}/
    isOnline: boolean
    lastSeen: timestamp (server timestamp)
    lastHeartbeat: timestamp (server timestamp)
```

**Firestore Structure (unchanged):**
```javascript
users/
  {userId}/
    isOnline: boolean
    lastSeen: timestamp (server timestamp)
    // ... other user fields
```

### Performance Considerations

**RTDB Costs:**
- Read/write operations: $1/GB (cheaper than Firestore)
- Bandwidth: $1/GB downloaded
- Storage: $5/GB (minimal - presence data is tiny)
- Estimated cost: ~$5-10/month for 1000 active users

**Memory:**
- One RTDB connection per app instance
- ~100 active presence listeners max
- Minimal memory overhead (<1MB)

**Battery:**
- Heartbeat every 30s = negligible battery impact
- RTDB connection maintained by iOS SDK efficiently

### Migration Strategy

**Phase 1: Add New System (No Breaking Changes)**
- Add RealtimePresenceService alongside existing PresenceService
- Feature flag disabled by default
- Test in development

**Phase 2: Parallel Running**
- Enable feature flag for beta testers
- Monitor both systems
- Compare accuracy

**Phase 3: Gradual Rollout**
- Enable for 10% of users
- Monitor error rates
- Increase to 50%, then 100%

**Phase 4: Deprecation**
- Keep old PresenceService for 2 weeks
- Remove if no issues reported

### Testing Strategy

**Unit Tests:**
- Test PresenceQueue enqueueing/flushing
- Test heartbeat timer behavior
- Test offline detection logic
- Mock RTDB and NetworkMonitor

**Integration Tests:**
- Test RTDB connection/disconnection
- Test onDisconnect() callback
- Test Firestore sync
- Test queue flushing on reconnect

**Manual Tests:**
- Airplane mode scenarios
- Background/foreground cycles
- Force quit testing
- Battery death simulation
- Multi-device presence tracking

---

## Success Metrics

### Reliability Metrics
- **Target:** 99.9% presence accuracy (users shown offline when actually offline)
- **Measure:** Compare actual connection state vs displayed status

### Performance Metrics
- **Target:** <1s delay between disconnect and offline status
- **Measure:** Time from connection loss to UI update

### User Experience Metrics
- **Target:** <5% of users report "stuck online" bugs
- **Measure:** Support ticket tracking

### System Health Metrics
- **Target:** <0.1% presence update failure rate
- **Measure:** Error logs and retry counts

---

## Non-Goals (Out of Scope)

1. **Last Seen Display:** Track `lastSeen` but don't show "Active 5m ago" in UI (future)
2. **Rich Presence:** No custom status messages or "What I'm doing" (future)
3. **Typing Indicators:** Separate PRD (already partially implemented)
4. **Read Receipts:** Separate PRD (already partially implemented)
5. **Multi-Device Tracking:** Don't show "Online on iPhone" vs "Online on iPad"
6. **Presence History:** No analytics on when users are typically online
7. **Do Not Disturb:** No "appears offline" mode
8. **Presence Settings:** No user control over presence visibility (always show)

---

## Open Questions

### Technical Questions

**Q1:** Should we use RTDB for all presence data, or just for disconnect detection?
- **Option A:** RTDB as primary, Firestore as backup (proposed)
- **Option B:** RTDB only for disconnect, everything else in Firestore
- **Recommendation:** Option A - simpler, more reliable

**Q2:** What heartbeat interval is optimal?
- **Too frequent:** Battery drain, unnecessary traffic
- **Too infrequent:** Slow stale detection
- **Proposed:** 30s (60s timeout) - needs testing

**Q3:** Should presence data be ephemeral or persistent?
- **Ephemeral:** RTDB only, lost on restart
- **Persistent:** Sync to Firestore (proposed)
- **Recommendation:** Persistent - allows queries, offline access

**Q4:** How to handle >100 users to track?
- **Option A:** Chunked queries (10 at a time)
- **Option B:** Prioritize visible conversations
- **Option C:** Both (proposed)
- **Recommendation:** Both - chunk AND prioritize

### Product Questions

**Q5:** Should there be a "last seen" display?
- **Pros:** Better UX, matches WhatsApp
- **Cons:** Privacy concerns, extra UI work
- **Recommendation:** Track now, display later (future PRD)

**Q6:** Should users control presence visibility?
- **Pros:** Privacy control
- **Cons:** Reduces utility of feature
- **Recommendation:** Not for MVP, revisit post-launch

**Q7:** How to handle presence during "inactive" state (phone call, notification center)?
- **Current:** Don't change presence (user is "active" technically)
- **Alternative:** Mark as "away" after 30s
- **Recommendation:** Keep current behavior

---

## Implementation Phases

### Phase 1: Foundation
- Add Firebase Realtime Database SDK
- Create RealtimePresenceService skeleton
- Implement PresenceQueue actor
- Add feature flag

### Phase 2: Core Functionality
- Implement onDisconnect() logic
- Implement heartbeat mechanism
- Implement offline queue
- RTDB to Firestore sync

### Phase 3: Integration
- Update NexusAIApp lifecycle handling
- Update ConversationListViewModel
- Update GroupInfoViewModel
- Add error handling

### Phase 4: Testing & Refinement
- Unit tests
- Integration tests
- Manual testing (offline scenarios)
- Performance optimization

### Phase 5: Deployment
- Enable feature flag for testing
- Monitor error rates
- Gradual rollout
- Documentation

---

## Risk Assessment

### High Risks

**R1: RTDB Connection Overhead**
- **Risk:** Maintaining RTDB connection drains battery
- **Mitigation:** Use iOS SDK which optimizes connection management
- **Likelihood:** Low (Firebase SDK is battle-tested)

**R2: Dual Database Complexity**
- **Risk:** Syncing RTDB ↔ Firestore introduces bugs
- **Mitigation:** Comprehensive testing, clear sync logic
- **Likelihood:** Medium

**R3: Migration Issues**
- **Risk:** Switching presence systems breaks existing functionality
- **Mitigation:** Feature flag, parallel running, gradual rollout
- **Likelihood:** Medium

### Medium Risks

**R4: Cost Increase**
- **Risk:** RTDB adds additional Firebase costs
- **Mitigation:** Monitor usage, optimize queries
- **Likelihood:** Low (presence data is tiny)

**R5: Heartbeat Battery Drain**
- **Risk:** 30s heartbeat drains battery
- **Mitigation:** Measure battery impact, adjust interval if needed
- **Likelihood:** Low (30s is conservative)

---

## References

### Firebase Documentation
- [Realtime Database onDisconnect()](https://firebase.google.com/docs/database/ios/offline-capabilities#detecting-connection-state)
- [Presence System Guide](https://firebase.google.com/docs/firestore/solutions/presence)
- [iOS Offline Capabilities](https://firebase.google.com/docs/database/ios/offline-capabilities)

### Related PRDs
- `prd-local-first-sync-framework.md` - Similar architectural upgrade
- `prd-in-app-notifications.md` - Uses presence data

### Existing Code
- `NexusAI/Services/PresenceService.swift` - Current implementation
- `NexusAI/Utilities/NetworkMonitor.swift` - Network detection
- `NexusAI/NexusAIApp.swift` - App lifecycle handling

---

## Appendix: Comparison with Current System

| Feature | Current System | New System |
|---------|---------------|------------|
| **Disconnect Detection** | Client-side only | Server-side (onDisconnect) |
| **Offline Queue** | None | Full queue + retry |
| **Heartbeat** | None | 30s heartbeat |
| **Background Delay** | None (instant) | 5 seconds |
| **Error Handling** | Silent failure (`try?`) | Logged + retried |
| **User Limit** | 10 (Firestore limit) | 100+ (RTDB) |
| **Reliability** | ~80% accurate | 99.9% accurate |
| **Resource Usage** | Creates new instance each scene | Singleton |
| **Rollback** | N/A | Feature flag |

---

**Status:** Ready for task generation
**Next Steps:** Generate detailed task list using `generate-tasks` rule

