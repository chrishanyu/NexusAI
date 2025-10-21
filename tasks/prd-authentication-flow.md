# PRD: Authentication Flow (Google Sign-In)

## Introduction/Overview

Build a minimal, secure authentication system for NexusAI using Google Sign-In as the sole authentication method. The feature provides a unified sign-in experience for both new and returning users, automatically creating user profiles in Firestore from Google account data. Authentication is a hard gate—users cannot access any part of the app without being authenticated.

**Problem:** Users need a secure, frictionless way to authenticate and access the messaging platform.

**Goal:** Implement Google Sign-In with automatic user profile creation, seamless session management, and proper error handling following SwiftUI best practices.

---

## Goals

1. **Single Sign-In Experience:** Provide one unified "Sign in with Google" flow for all users (new and returning)
2. **Automatic Profile Creation:** Extract user data from Google (email, display name, profile picture URL) and create Firestore user document automatically
3. **Session Persistence:** Keep users logged in between app sessions using Firebase Auth session management
4. **Secure & Reliable:** Handle all error scenarios gracefully with inline error messages
5. **Navigation Control:** Route users to conversation list after successful authentication; block access to app features until authenticated

---

## User Stories

### As a First-Time User
- **Story 1:** I want to sign in with my Google account so that I can quickly access the app without creating a new username/password
- **Story 2:** I want my Google profile information (name, email, picture) to be used automatically so I don't have to set up my profile manually
- **Story 3:** I want to see the conversation list immediately after signing in so I can start messaging right away

### As a Returning User
- **Story 4:** I want to stay logged in between app sessions so I don't have to sign in every time I open the app
- **Story 5:** I want to log out from my profile screen so I can switch accounts or protect my privacy

### As Any User
- **Story 6:** I want clear error messages when sign-in fails so I understand what went wrong and can try again
- **Story 7:** I want the app to handle network errors gracefully so my experience isn't disrupted by temporary connectivity issues

---

## Functional Requirements

### FR-1: Google Sign-In Screen
1. The app SHALL display a dedicated sign-in screen with a "Sign in with Google" button when no user is authenticated
2. The sign-in screen SHALL be the entry point to the app (hard gate)
3. The button SHALL follow Google's brand guidelines for sign-in buttons

### FR-2: Google Authentication Flow
4. The system SHALL initiate Google Sign-In using Firebase Auth when the user taps "Sign in with Google"
5. The system SHALL request user consent for email, profile, and basic account information from Google
6. The system SHALL handle Google Sign-In cancellation gracefully (user closes Google sign-in modal)

### FR-3: Automatic User Profile Creation
7. Upon successful Google Sign-In, the system SHALL extract the following data from the Google account:
   - Email address
   - Display name
   - Profile picture URL (if available)
8. The system SHALL create or update a user document in Firestore at `users/{userId}` with the following fields:
   - `userId` (Firebase Auth UID)
   - `email` (from Google)
   - `displayName` (from Google)
   - `profileImageUrl` (from Google, optional)
   - `createdAt` (timestamp)
   - `isOnline` (boolean, default: true)
   - `lastSeen` (timestamp)
9. User profile creation SHALL happen automatically in the background without user confirmation
10. If a user document already exists, the system SHALL update the profile with latest Google data

### FR-4: Session Management
11. The system SHALL persist user authentication sessions using Firebase Auth
12. On app launch, the system SHALL check for an active Firebase Auth session
13. If a valid session exists, the system SHALL navigate directly to the conversation list
14. If no valid session exists, the system SHALL show the Google Sign-In screen

### FR-5: Navigation & Routing
15. After successful authentication, the system SHALL navigate users to the conversation list screen
16. The system SHALL block access to all app screens (conversation list, chat, profile) until the user is authenticated
17. The system SHALL update the app's root view based on authentication state (signed in → conversation list, signed out → sign-in screen)

### FR-6: Logout Functionality
18. The system SHALL provide a logout button in the user's profile screen
19. When the user taps logout, the system SHALL:
    - Sign out from Firebase Auth
    - Clear the current user session
    - Navigate back to the Google Sign-In screen
20. Local conversation data MAY be retained after logout (handled by LocalStorageService)

### FR-7: Error Handling
21. The system SHALL handle the following error scenarios:
    - **Google Sign-In cancelled:** Show inline message "Sign-in was cancelled. Please try again."
    - **Google Sign-In failed (network error):** Show inline message "Network error. Please check your connection and try again."
    - **Firestore user creation failed:** Show inline message "Failed to create profile. Please try signing in again."
    - **User revoked app permissions:** Show inline message "App permissions were revoked. Please grant permissions to continue."
22. Error messages SHALL be displayed inline below the "Sign in with Google" button
23. Error messages SHALL automatically dismiss after 5 seconds or when user taps the sign-in button again
24. If Google Sign-In succeeds but Firestore user creation fails, the system SHALL sign out the user and require re-authentication
25. On Firestore user creation failure, the system SHALL retry the creation on next successful sign-in attempt

### FR-8: Loading States
26. The system SHALL show a loading indicator while Google Sign-In is in progress
27. The system SHALL show a loading indicator while creating/updating the user profile in Firestore
28. Loading indicators SHALL prevent multiple simultaneous sign-in attempts

---

## Non-Goals (Out of Scope)

The following are explicitly **NOT** included in this authentication feature:

1. **Profile Setup Screen:** No dedicated profile setup screen after first sign-in
2. **Onboarding Screens:** No welcome screens, tutorials, or walkthroughs for first-time users
3. **Profile Editing:** Users cannot edit profile during initial sign-in (can be added later in profile screen)
4. **Multiple Auth Methods:** No email/password, Apple Sign-In, or other authentication methods
5. **Email Verification:** Not required since Google handles account verification
6. **Password Reset:** Not applicable (Google manages credentials)
7. **Account Deletion:** Not included in this PR (can be added later)
8. **Terms of Service Acceptance:** Not required during sign-in (can be added later)
9. **Permissions Onboarding:** No upfront explanation of app permissions (notifications handled separately)

---

## Design Considerations

### Sign-In Screen
- **Layout:** Centered "Sign in with Google" button on clean background
- **Branding:** Follow Google's sign-in button design guidelines (official button or styled UIButton)
- **Feedback:** Show loading spinner during sign-in process
- **Error Display:** Inline error message displayed below button with red text and warning icon

### UI/UX Guidelines
- Keep the sign-in screen minimal and uncluttered
- Use system-provided Google Sign-In UI for consistency
- Provide immediate visual feedback (loading state) when user taps sign-in button
- Error messages should be clear, actionable, and non-technical

### Accessibility
- Ensure "Sign in with Google" button has proper VoiceOver labels
- Error messages should be announced by screen readers
- Maintain sufficient color contrast for error messages

---

## Technical Considerations

### Dependencies
- **Firebase Auth SDK:** Required for Google Sign-In integration
- **Firebase Firestore SDK:** Required for user profile storage
- **Google Sign-In SDK (via Firebase):** Handles OAuth flow

### Architecture
- **AuthViewModel:** Manages authentication state, Google Sign-In logic, error handling
- **AuthService:** Service layer for Firebase Auth operations (sign-in, sign-out, user creation)
- **Views:**
  - `LoginView.swift`: Main sign-in screen (no separate SignUpView needed)
  - `ProfileSetupView.swift`: Not needed for this PR (future enhancement)
- **App Navigation:** Update `NexusAIApp.swift` to conditionally show sign-in screen or conversation list based on auth state

### Firebase Auth Setup
- Enable Google Sign-In in Firebase Console
- Configure OAuth consent screen in Google Cloud Console
- Add GoogleService-Info.plist to Xcode project
- Configure URL schemes for Google Sign-In callback

### Data Flow
1. User taps "Sign in with Google"
2. AuthViewModel calls AuthService.signInWithGoogle()
3. Firebase Auth presents Google OAuth consent screen
4. On success, Firebase returns Firebase User object
5. AuthService extracts user data and creates/updates Firestore user document
6. On Firestore success, AuthViewModel updates authentication state
7. App navigation routes user to conversation list

### Error Handling Strategy
- Use Swift Result types for async operations
- Catch and map Firebase errors to user-friendly messages
- Log errors for debugging (using print or logging framework)
- Retry logic for Firestore user creation failures

### Testing Considerations
- Test on iOS Simulator (Google Sign-In works in simulator)
- Test error scenarios (network off, cancelled sign-in, Firestore unavailable)
- Test session persistence (close/reopen app)
- Verify user document structure in Firestore Console

---

## Success Metrics

### Functional Success
- ✅ User can sign in with Google account successfully
- ✅ User profile is created automatically in Firestore with correct data
- ✅ User remains logged in after closing and reopening the app
- ✅ User can log out successfully and is redirected to sign-in screen
- ✅ All error scenarios display appropriate inline error messages

### Technical Success
- ✅ No crashes during sign-in flow
- ✅ Firebase Auth session persists correctly
- ✅ Firestore user document created within 2 seconds of successful sign-in
- ✅ App navigation updates correctly based on authentication state

### User Experience Success
- ✅ Sign-in process takes <5 seconds under normal network conditions
- ✅ Error messages are clear and actionable
- ✅ Loading states provide visual feedback
- ✅ No unexpected navigation loops or blank screens

---

## Open Questions

1. **Profile Picture Fallback:** If Google doesn't provide a profile picture URL, should we generate initials-based avatars or use a default placeholder?
   
2. **Offline Sign-In:** Should we allow users to access the app offline if they have a cached session, or require online connectivity for authentication checks?

3. **Session Timeout:** Should Firebase Auth sessions expire after a certain period of inactivity, or remain valid indefinitely?

4. **Account Switching:** If a user logs out and signs in with a different Google account, should we preserve any local data from the previous session?

5. **Firestore Retry Strategy:** How many times should we retry Firestore user creation before showing a persistent error? Should we implement exponential backoff?

6. **Google Sign-In Scope:** Are the default Firebase Auth Google scopes (email, profile) sufficient, or do we need additional scopes for future features?

---

## Acceptance Criteria

### Must Have
- [ ] "Sign in with Google" button displayed on initial app launch for unauthenticated users
- [ ] Google OAuth flow completes successfully
- [ ] User document created in Firestore with all required fields (userId, email, displayName, profileImageUrl, createdAt, isOnline, lastSeen)
- [ ] Authenticated users navigate to conversation list screen
- [ ] Session persists between app launches
- [ ] Logout functionality works from profile screen
- [ ] All error scenarios display inline error messages
- [ ] Loading indicators shown during sign-in and profile creation

### Should Have
- [ ] Error messages dismiss automatically after 5 seconds
- [ ] Retry logic for Firestore user creation failures
- [ ] VoiceOver accessibility for sign-in button and error messages

### Nice to Have
- [ ] Smooth animations for navigation transitions
- [ ] Haptic feedback on successful sign-in
- [ ] Custom loading animation instead of system spinner

---

## Implementation Notes for Developers

### Key Files to Create/Modify
- **New Files:**
  - `ViewModels/AuthViewModel.swift` - Manages auth state and UI logic
  - `Views/Auth/LoginView.swift` - Sign-in screen UI
  
- **Existing Files to Modify:**
  - `Services/AuthService.swift` - Add Google Sign-In methods
  - `NexusAIApp.swift` - Add auth state routing logic

### SwiftUI Best Practices for Error Handling
- Use `@State` for error messages in views
- Use `Alert` or custom error view components
- Implement proper error propagation through ViewModels
- Use Swift's async/await with proper do-catch blocks
- Display user-friendly error messages (not raw Firebase errors)

### Firebase Auth Integration
```swift
// Example: Google Sign-In method structure
func signInWithGoogle() async throws -> User {
    // 1. Get GIDSignIn credential
    // 2. Convert to Firebase credential
    // 3. Sign in to Firebase
    // 4. Create/update Firestore user document
    // 5. Return User object
}
```

### Firestore User Document Structure
```json
{
  "userId": "abc123",
  "email": "user@gmail.com",
  "displayName": "John Doe",
  "profileImageUrl": "https://lh3.googleusercontent.com/...",
  "createdAt": Timestamp,
  "isOnline": true,
  "lastSeen": Timestamp
}
```

---

## Related Documentation
- **Project Brief:** `/memory-bank/projectbrief.md`
- **Building Phases:** `/building-phases.md` (PR #4)
- **System Architecture:** `/architecture.md`
- **Firebase Services:** `/NexusAI/Services/AuthService.swift`

---

**Last Updated:** October 21, 2025  
**Status:** Ready for Implementation  
**Assigned To:** PR #4 - Authentication Flow  
**Branch:** `feature/authentication`

