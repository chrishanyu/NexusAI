# Task List: Push Notifications (Real FCM Implementation)

**PRD Reference:** `/tasks/prd-push-notifications.md`  
**Branch:** `feature/push-notifications`  
**PR:** #13

---

## Relevant Files

### Already Created (Phase 1 Complete)
- `NexusAI/ViewModels/NotificationManager.swift` - ✅ Manages notification permissions and navigation
- `NexusAI/Services/NotificationService.swift` - ✅ Implements UNUserNotificationCenterDelegate
- `NexusAI/AppDelegate.swift` - ✅ Sets up notification center delegate
- `NexusAI/NexusAIApp.swift` - ✅ Integrates AppDelegate and NotificationManager
- `NexusAI/ContentView.swift` - ✅ Passes NotificationManager environment object
- `NexusAI/Views/ConversationList/ConversationListView.swift` - ✅ Handles notification navigation

### To Be Created/Modified
- `NexusAI/Services/AuthService.swift` - TO UPDATE: Add FCM token registration/removal
- `firebase/functions/src/index.ts` - TO CREATE: Cloud Function for notification delivery
- `firebase/functions/package.json` - TO UPDATE: Add Firebase Admin SDK dependency
- `NexusAI.xcodeproj/project.pbxproj` - TO UPDATE: Add Firebase Messaging SDK via SPM

### Notes

- **Phase 1 (Notification Handling)** is COMPLETE - We have the infrastructure to handle notifications
- **Phase 2 (FCM Integration)** needs to be implemented - Token registration and Cloud Functions
- Real push notifications require physical iOS devices (not simulator)
- APNs certificate must be configured in Firebase Console before testing

---

## Tasks

- [ ] 1.0 Add Firebase Messaging SDK to iOS Project
  - [ ] 1.1 Open Xcode project and navigate to project settings
  - [ ] 1.2 Add Firebase Messaging via Swift Package Manager (File > Add Package Dependencies)
  - [ ] 1.3 Add package URL: `https://github.com/firebase/firebase-ios-sdk`
  - [ ] 1.4 Select `FirebaseMessaging` product and add to NexusAI target
  - [ ] 1.5 Add Push Notifications capability to project (Signing & Capabilities)
  - [ ] 1.6 Add Background Modes capability and enable "Remote notifications"
  - [ ] 1.7 Import FirebaseMessaging in AppDelegate and NotificationService
  - [ ] 1.8 Verify project builds without errors

- [ ] 2.0 Configure APNs in Firebase Console
  - [ ] 2.1 Generate APNs Authentication Key in Apple Developer Portal
  - [ ] 2.2 Download .p8 key file and note the Key ID and Team ID
  - [ ] 2.3 Open Firebase Console and navigate to Project Settings > Cloud Messaging
  - [ ] 2.4 Upload APNs Authentication Key (.p8 file)
  - [ ] 2.5 Enter Key ID and Team ID
  - [ ] 2.6 Verify APNs configuration is active in Firebase Console
  - [ ] 2.7 Enable Firebase Cloud Messaging API in Google Cloud Console

- [ ] 3.0 Implement FCM Token Registration in iOS
  - [ ] 3.1 Update `AppDelegate.swift` to configure Firebase Messaging in `didFinishLaunchingWithOptions`
  - [ ] 3.2 Set `Messaging.messaging().delegate` to NotificationService
  - [ ] 3.3 Call `UIApplication.shared.registerForRemoteNotifications()` after permission granted
  - [ ] 3.4 Update `NotificationService.swift` to conform to `MessagingDelegate`
  - [ ] 3.5 Implement `messaging(_:didReceiveRegistrationToken:)` delegate method
  - [ ] 3.6 Add `registerFCMToken()` method to AuthService to store token in Firestore
  - [ ] 3.7 Call `registerFCMToken()` after successful login in AuthViewModel
  - [ ] 3.8 Add `removeFCMToken()` method to AuthService
  - [ ] 3.9 Call `removeFCMToken()` on logout in AuthViewModel
  - [ ] 3.10 Update User model to include `fcmToken` field (if not exists)
  - [ ] 3.11 Test: Login → Check Firestore users/{userId} has fcmToken field
  - [ ] 3.12 Test: Logout → Verify fcmToken removed from Firestore

- [ ] 4.0 Implement Cloud Function for Notification Delivery
  - [ ] 4.1 Navigate to `firebase/functions` directory
  - [ ] 4.2 Run `npm install firebase-admin firebase-functions` to add dependencies
  - [ ] 4.3 Create or update `firebase/functions/src/index.ts` (or index.js)
  - [ ] 4.4 Initialize Firebase Admin SDK in Cloud Function
  - [ ] 4.5 Create `sendMessageNotification` function that triggers on `conversations/{conversationId}/messages/{messageId}` onCreate
  - [ ] 4.6 Fetch conversation document to get participantIds array
  - [ ] 4.7 Filter out sender from recipient list (don't notify yourself)
  - [ ] 4.8 Fetch FCM tokens for all recipients from users collection
  - [ ] 4.9 Construct notification payload with title, body, and custom data (conversationId, senderId, etc.)
  - [ ] 4.10 Send notifications using `admin.messaging().sendToDevice(tokens, payload)`
  - [ ] 4.11 Add error handling for missing tokens and invalid tokens
  - [ ] 4.12 Add logging for notification delivery success/failure
  - [ ] 4.13 Test function locally using Firebase Emulator (optional)
  - [ ] 4.14 Deploy Cloud Function using `firebase deploy --only functions`
  - [ ] 4.15 Verify function appears in Firebase Console under Functions
  - [ ] 4.16 Check Cloud Function logs after deployment

- [ ] 5.0 Test End-to-End Notification Flow on Physical Devices
  - [ ] 5.1 Build and install app on Physical Device A (using your Apple Developer account)
  - [ ] 5.2 Build and install app on Physical Device B (or use TestFlight)
  - [ ] 5.3 Login on Device A and verify FCM token stored in Firestore
  - [ ] 5.4 Login on Device B and verify FCM token stored in Firestore
  - [ ] 5.5 Background the app on Device B
  - [ ] 5.6 Send a message from Device A to Device B
  - [ ] 5.7 Verify: Device B receives push notification within 5 seconds
  - [ ] 5.8 Verify: Notification shows sender name and message preview
  - [ ] 5.9 Tap notification on Device B → Verify app opens to correct conversation
  - [ ] 5.10 Test: Send message while Device B app is in foreground → Banner notification appears
  - [ ] 5.11 Test: Send message while Device B app is killed → Notification appears, tap opens to conversation
  - [ ] 5.12 Test: Group message → All participants (except sender) receive notification
  - [ ] 5.13 Test: Logout on Device B → Send message → No notification received (token removed)
  - [ ] 5.14 Test: Rapid messages (5+ in a row) → All notifications delivered
  - [ ] 5.15 Check Cloud Function logs for any errors or failed deliveries
  - [ ] 5.16 Document any issues or edge cases discovered

