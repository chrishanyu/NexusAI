# PRD: Push Notifications (Real FCM Implementation) - PR #13

## Introduction/Overview

Implement complete push notification functionality using Firebase Cloud Messaging (FCM), including token registration, Cloud Functions for notification delivery, and notification handling on iOS devices. When User A sends a message, User B receives a real push notification that opens the app to the correct conversation.

**Problem:** Users need to be notified immediately when they receive new messages, even when the app is in the background or not running. Without push notifications, users have to manually check the app for new messages.

**Goal:** Implement end-to-end push notification delivery so that when a message is sent, all recipients automatically receive a push notification with the sender's name and message preview, which navigates them directly to the conversation when tapped.

**Scope:** This PRD covers PR #13 from the building phases, implementing production-ready push notifications using FCM and Cloud Functions.

---

## Goals

1. **FCM Token Management:** Register and store FCM tokens for each user
2. **Notification Permissions:** Request and handle notification permissions on app launch
3. **Notification Delivery:** Automatically send push notifications when messages are sent
4. **Notification Display:** Display notifications when app is in foreground and background
5. **Notification Handling:** Handle notification taps to navigate to correct conversation
6. **Payload Parsing:** Parse notification payload to extract conversation and sender information
7. **Cloud Functions:** Deploy serverless functions to trigger notifications on new messages

---

## User Stories

### As a Message Recipient
- **Story 1:** I want to receive a push notification immediately when someone sends me a message so I don't miss important communications
- **Story 2:** I want the notification to show who sent the message and a preview of the content so I can decide if I need to respond immediately
- **Story 3:** I want to tap the notification to open the app directly to that conversation so I can quickly respond
- **Story 4:** I want to see notification banners when messages arrive while the app is open so I'm aware of messages in other conversations

### As a Message Sender
- **Story 5:** I want recipients to be notified when I send a message so they can respond in a timely manner
- **Story 6:** I want group message notifications to show the group name and my name so recipients know which conversation needs attention

### As a User Managing Notifications
- **Story 7:** I want to be prompted for notification permissions when I first launch the app
- **Story 8:** I want notifications to work whether the app is in foreground, background, or completely closed

---

## Functional Requirements

### FR-1: FCM Token Registration

1. The app SHALL register for Firebase Cloud Messaging on app launch
2. The app SHALL obtain the user's FCM token using `Messaging.messaging().token()`
3. The app SHALL store the FCM token in Firestore at `users/{userId}/fcmToken`
4. The app SHALL update the FCM token whenever it refreshes (token rotation)
5. The app SHALL implement `MessagingDelegate` to handle token updates
6. The app SHALL remove the FCM token from Firestore on user logout

### FR-2: Notification Permissions

7. The app SHALL request notification permissions on first launch using `UNUserNotificationCenter.requestAuthorization()`
8. The app SHALL request alert, badge, and sound permissions
9. The app SHALL handle all permission states:
   - `.authorized` - notifications enabled, register for FCM
   - `.denied` - notifications blocked, skip FCM registration
   - `.notDetermined` - user hasn't decided yet
10. The app SHALL check notification permission status on subsequent launches
11. The app SHALL only register FCM tokens if notification permissions are granted

### FR-3: Cloud Function - Send Notification on New Message

12. A Cloud Function SHALL be triggered when a new message document is created in Firestore
13. The function SHALL trigger on `conversations/{conversationId}/messages/{messageId}` create events
14. The function SHALL retrieve the conversation document to get all participant IDs
15. The function SHALL exclude the sender from the recipient list (don't notify yourself)
16. The function SHALL fetch FCM tokens for all recipients from their user documents
17. The function SHALL construct notification payloads with:
    - Title: Sender's display name (or group name for groups)
    - Body: Message text preview (first 100 characters)
    - Custom data: conversationId, senderId, messageText, senderName
18. The function SHALL send notifications to all recipients using FCM Admin SDK
19. The function SHALL handle errors gracefully (missing tokens, invalid tokens)
20. The function SHALL log notification delivery status

### FR-4: Notification Display (iOS App)

21. The app SHALL implement `UNUserNotificationCenterDelegate` to handle notifications
22. The app SHALL display notification banners when messages arrive while app is in foreground
23. The app SHALL return `[.banner, .sound]` presentation options for foreground notifications
24. The app SHALL display notification banners when app is in background (automatic)
25. The app SHALL show notification content:
    - Title: Sender's display name (or "Group Name" for groups)
    - Subtitle: Sender name in group messages
    - Body: Message text preview
    - Badge: Unread message count (optional)
    - Sound: Default notification sound
26. Notifications SHALL wake the device and display on lock screen

### FR-5: Notification Handling (Tap Actions)

27. The app SHALL implement `didReceive response` delegate method to handle notification taps
28. When a notification is tapped, the app SHALL:
    - Parse the notification payload to extract `conversationId` and `senderId`
    - Navigate to the specified conversation (ChatView)
    - Mark messages in that conversation as read
29. The app SHALL handle notification taps from all app states:
    - Foreground (app open and visible)
    - Background (app running but not visible)
    - Killed (app not running, cold start)
30. The app SHALL dismiss the notification banner after user taps it
31. The app SHALL handle invalid or missing conversationId gracefully (no crash)

### FR-6: Notification Payload Structure

32. FCM notification payloads SHALL follow this structure:
```json
{
  "notification": {
    "title": "Alice Johnson",
    "body": "Hey, can you review the doc?"
  },
  "data": {
    "conversationId": "conv_abc123",
    "senderId": "user_alice_456",
    "messageText": "Hey, can you review the doc?",
    "senderName": "Alice Johnson",
    "conversationType": "direct"
  },
  "apns": {
    "payload": {
      "aps": {
        "badge": 1,
        "sound": "default"
      }
    }
  }
}
```

### FR-7: Token Management & Cleanup

33. The app SHALL update FCM token in Firestore when token refreshes
34. The app SHALL remove FCM token from Firestore on user logout
35. The Cloud Function SHALL handle invalid/expired tokens gracefully
36. The Cloud Function SHALL skip recipients with missing FCM tokens (not fail entire batch)

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in PR #13:

1. **Rich Notifications:** No images, videos, or custom notification UI
2. **Notification Actions:** No quick reply or notification action buttons
3. **Notification Categories:** Not implementing custom notification categories
4. **Silent Notifications:** Not implementing background fetch or silent push
5. **Notification Settings:** No in-app notification preferences UI
6. **Per-Conversation Muting:** Cannot mute specific conversations yet
7. **Notification Sounds:** Using default system sound only
8. **Badge Count Management:** Advanced badge counting logic
9. **Notification Grouping:** iOS automatic grouping only
10. **Read Receipt Notifications:** No notifications when someone reads your message

---

## Design Considerations

### Notification Appearance

**Direct Message:**
```
┌────────────────────────────────────┐
│  📱 Nexus                          │
│  Alice Johnson                     │
│  Hey, can you review the doc I...  │
└────────────────────────────────────┘
```

**Group Message:**
```
┌────────────────────────────────────┐
│  📱 Nexus                          │
│  Team Nexus                        │
│  Bob: Don't forget the standup...  │
└────────────────────────────────────┘
```

### Navigation Flow

**Notification Tap → App Opens:**
1. User taps notification
2. App launches (or comes to foreground)
3. App parses notification payload
4. App navigates to ConversationListView
5. App navigates to ChatView with conversationId
6. ChatView loads messages and marks as read

---

## Technical Considerations

### iOS App Architecture

**New/Updated Components:**

1. **NotificationManager.swift** (ViewModel) - Already created
   - Request notification permissions
   - Handle notification authorization status
   - Coordinate notification-related logic
   - Manage FCM token registration

2. **NotificationService.swift** (Service) - Already created
   - Implement `UNUserNotificationCenterDelegate`
   - Parse notification payloads
   - Trigger navigation to conversations
   - Implement `MessagingDelegate` for token updates

3. **AppDelegate.swift** - Already created
   - Set up notification center delegate
   - Configure Firebase Messaging
   - Handle app lifecycle for notifications

4. **AuthService.swift** - TO UPDATE
   - Register FCM token on login
   - Remove FCM token on logout

### Firebase Cloud Functions

**Function: `sendMessageNotification`**

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = context.params.conversationId;
    
    // Get conversation to find participants
    const conversationDoc = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .get();
    
    const conversation = conversationDoc.data();
    
    // Get recipient IDs (exclude sender)
    const recipientIds = conversation.participantIds
      .filter(id => id !== message.senderId);
    
    // Fetch FCM tokens for all recipients
    const tokens = [];
    for (const userId of recipientIds) {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      const fcmToken = userDoc.data()?.fcmToken;
      if (fcmToken) {
        tokens.push(fcmToken);
      }
    }
    
    if (tokens.length === 0) {
      console.log('No FCM tokens found for recipients');
      return null;
    }
    
    // Construct notification payload
    const payload = {
      notification: {
        title: message.senderName,
        body: message.text.substring(0, 100)
      },
      data: {
        conversationId: conversationId,
        senderId: message.senderId,
        messageText: message.text,
        senderName: message.senderName
      }
    };
    
    // Send notifications
    const response = await admin.messaging().sendToDevice(tokens, payload);
    console.log('Notifications sent:', response.successCount, 'success,', response.failureCount, 'failed');
    
    return response;
  });
```

### iOS Implementation Updates

**Update AuthService.swift:**

```swift
import FirebaseMessaging

func registerFCMToken() async throws {
    guard let token = try? await Messaging.messaging().token() else {
        throw AuthError.fcmTokenFailed
    }
    
    guard let userId = Auth.auth().currentUser?.uid else {
        throw AuthError.notAuthenticated
    }
    
    // Store token in Firestore
    try await db.collection("users")
        .document(userId)
        .updateData(["fcmToken": token])
    
    print("✅ FCM token registered: \(token)")
}

func removeFCMToken() async throws {
    guard let userId = Auth.auth().currentUser?.uid else { return }
    
    try await db.collection("users")
        .document(userId)
        .updateData(["fcmToken": FieldValue.delete()])
    
    print("✅ FCM token removed")
}
```

**Update NotificationService.swift:**

```swift
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 FCM token refreshed: \(fcmToken ?? "nil")")
        
        // Update token in Firestore
        Task {
            guard let token = fcmToken,
                  let userId = Auth.auth().currentUser?.uid else { return }
            
            try? await FirebaseService.shared.db
                .collection("users")
                .document(userId)
                .updateData(["fcmToken": token])
        }
    }
}
```

### Firebase Project Setup Requirements

1. **Enable Cloud Functions** in Firebase Console
2. **Deploy Cloud Function** using Firebase CLI
3. **Ensure Firestore Security Rules** allow FCM token writes
4. **Add APNs Certificate** to Firebase Console (for iOS)
5. **Enable FCM API** in Google Cloud Console

---

## Success Metrics

### Functional Success
- ✅ FCM tokens stored in Firestore for all logged-in users
- ✅ Cloud Function deploys successfully
- ✅ Notification sent when User A messages User B
- ✅ Notification appears on User B's device (foreground, background, killed)
- ✅ Notification shows sender name and message preview
- ✅ Tapping notification navigates to correct conversation
- ✅ Navigation works from all app states
- ✅ Group notifications sent to all participants (except sender)
- ✅ FCM tokens updated when they refresh
- ✅ FCM tokens removed on logout

### Technical Success
- ✅ Cloud Function triggers reliably on new messages
- ✅ Notification delivery latency < 5 seconds
- ✅ No crashes when handling notifications
- ✅ Invalid/expired tokens handled gracefully
- ✅ Cloud Function logs show success/failure rates

---

## Testing Checklist

### FCM Token Registration
- [ ] User logs in → FCM token stored in Firestore `users/{userId}/fcmToken`
- [ ] Token value is non-empty string
- [ ] Token updates when it refreshes
- [ ] Token removed from Firestore on logout

### Cloud Function Deployment
- [ ] Deploy Cloud Function using `firebase deploy --only functions`
- [ ] Function appears in Firebase Console
- [ ] Function triggers when test message is sent
- [ ] Check Cloud Function logs for execution

### Notification Delivery (Two Devices Required)
- [ ] Device A sends message to Device B
- [ ] Device B receives notification within 5 seconds
- [ ] Notification shows correct sender name and message text
- [ ] Badge count increments on Device B

### Notification Display
- [ ] Notification appears when app is in background
- [ ] Notification appears when app is killed
- [ ] Notification banner appears when app is in foreground
- [ ] Notification plays sound
- [ ] Lock screen shows notification

### Notification Navigation
- [ ] Tap notification from background → app opens to conversation
- [ ] Tap notification from killed state → app launches to conversation
- [ ] Tap notification from foreground → navigates to conversation
- [ ] Correct conversationId extracted from payload
- [ ] ChatView loads correct messages

### Group Notifications
- [ ] User A sends message to group → All other participants receive notification
- [ ] Sender (User A) does NOT receive their own notification
- [ ] Group notification shows group name

### Edge Cases
- [ ] Send message to user who's never logged in (no FCM token) → no crash
- [ ] Send message to user with expired token → handled gracefully
- [ ] Tap notification with invalid conversationId → no crash
- [ ] Multiple rapid messages → multiple notifications delivered

---

## Acceptance Criteria

### Must Have
- [ ] FCM token registration implemented in AuthService
- [ ] FCM token stored in Firestore on login
- [ ] FCM token removed on logout
- [ ] Cloud Function deployed and active
- [ ] Cloud Function triggers on new message creation
- [ ] Notification sent to all recipients (except sender)
- [ ] Notification payload includes conversationId, senderId, message text
- [ ] iOS app handles notification taps
- [ ] Navigation to conversation works from all app states
- [ ] Tested on at least 2 physical iOS devices
- [ ] No crashes or errors in production

### Should Have
- [ ] FCM token updates when it refreshes
- [ ] Cloud Function logs show delivery status
- [ ] Foreground notifications display with banner
- [ ] Notification shows in lock screen
- [ ] Invalid tokens handled gracefully
- [ ] Group notifications work correctly

### Nice to Have
- [ ] Badge count management
- [ ] Notification delivery analytics
- [ ] Retry logic for failed deliveries
- [ ] Cloud Function monitoring/alerts

---

## Implementation Steps

### Phase 1: FCM Token Registration (iOS)
1. Add Firebase Messaging SDK to project
2. Configure APNs in Firebase Console
3. Update AuthService to register FCM tokens on login
4. Update AuthService to remove FCM tokens on logout
5. Implement MessagingDelegate for token refresh
6. Test token storage in Firestore

### Phase 2: Cloud Function Development
7. Set up Firebase Functions project (if not exists)
8. Create `sendMessageNotification` function
9. Test function locally with Firebase Emulator
10. Deploy function to Firebase
11. Verify function triggers on test message

### Phase 3: Notification Handling (Already Complete)
12. ✅ NotificationManager created
13. ✅ NotificationService implements UNUserNotificationCenterDelegate
14. ✅ AppDelegate integrated
15. ✅ Navigation handling implemented

### Phase 4: Integration Testing
16. Test on 2 physical iOS devices
17. Verify end-to-end notification flow
18. Test all app states (foreground, background, killed)
19. Test group notifications
20. Fix bugs and edge cases

### Phase 5: Production Deployment
21. Deploy Cloud Function to production
22. Submit app to TestFlight or App Store
23. Monitor Cloud Function logs
24. Monitor notification delivery rates

---

## Dependencies & Prerequisites

### Must Be Complete Before Starting
- ✅ **PR #5-8:** Conversation list and chat screens exist for navigation
- ✅ **PR #7:** Message sending works (to trigger Cloud Function)
- ✅ **Notification Infrastructure:** NotificationManager, NotificationService, AppDelegate (DONE)

### Required Setup
- ❌ **Firebase Cloud Functions:** Must be enabled in Firebase Console
- ❌ **APNs Certificate:** Must be uploaded to Firebase Console
- ❌ **Physical iOS Devices:** Simulators don't support real FCM push
- ❌ **Firebase CLI:** For deploying Cloud Functions

### What's New in This PR
- ❌ FCM token registration (NEW)
- ❌ Cloud Function for notification delivery (NEW)
- ❌ FCM token management in AuthService (NEW)
- ❌ MessagingDelegate implementation (NEW)
- ❌ End-to-end notification testing (NEW)

---

**Last Updated:** October 22, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PR #13 - Push Notifications (Real FCM)  
**Branch:** `feature/push-notifications`

---

**Priority:** 🔴 HIGH - Critical for MVP  
**Complexity:** ⭐⭐⭐⭐ High (4/5) - Requires Cloud Functions  
**Estimated Effort:** 4-6 hours

