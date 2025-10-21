# Task List: Authentication Flow (Google Sign-In)

Based on PRD: `/tasks/prd-authentication-flow.md`

---

## Relevant Files

### Main Implementation Files
- `NexusAI/Services/AuthService.swift` - Firebase Auth service layer for Google Sign-In operations
- `NexusAI/ViewModels/AuthViewModel.swift` - Authentication state management and UI coordination
- `NexusAI/Views/Auth/LoginView.swift` - Sign-in screen with Google Sign-In button
- `NexusAI/NexusAIApp.swift` - App entry point with auth state-based navigation
- `NexusAI/Models/User.swift` - User model (existing, may need updates)
- `NexusAI/GoogleService-Info.plist` - Firebase configuration (existing)

### Test Files
- `NexusAITests/Services/AuthServiceTests.swift` - Unit tests for AuthService ✅ Created (needs test target setup)
- `NexusAITests/ViewModels/AuthViewModelTests.swift` - Unit tests for AuthViewModel
- `NexusAITests/Views/Auth/LoginViewTests.swift` - UI tests for LoginView (optional)

### Configuration Files
- `Info.plist` - URL schemes for Google Sign-In callback
- `NexusAI.xcodeproj/project.pbxproj` - Xcode project file (Firebase SDK dependencies)

### Notes
- Tests are placed in a separate `NexusAITests` target following Swift conventions
- Run tests with `Cmd + U` in Xcode or `xcodebuild test -scheme NexusAI`
- Use `@testable import NexusAI` in test files to access internal members
- Integration tests can test the full sign-in flow using Firebase Test Lab or manual testing

---

## Tasks

- [x] 1.0 Firebase Configuration & Google Sign-In Setup
  - [x] 1.1 Verify Firebase project has Google Sign-In enabled in Firebase Console (Authentication > Sign-in method)
  - [x] 1.2 Configure OAuth consent screen in Google Cloud Console (add app name, support email, authorized domains)
  - [x] 1.3 Add Firebase GoogleSignIn SDK to Xcode project via Swift Package Manager (if not already added)
  - [x] 1.4 Configure URL schemes in `Info.plist` for Google Sign-In callback (add reversed client ID from GoogleService-Info.plist)
  - [x] 1.5 Verify `GoogleService-Info.plist` is correctly added to Xcode project and contains Google OAuth client IDs

- [x] 2.0 AuthService - Google Sign-In Implementation
  - [x] 2.1 Open `Services/AuthService.swift` and add import statements for FirebaseAuth and GoogleSignIn
  - [x] 2.2 Implement `signInWithGoogle() async throws -> User` method that initiates Google Sign-In flow
  - [x] 2.3 Add logic to get Google Sign-In credential and convert to Firebase credential
  - [x] 2.4 Implement Firebase authentication with Google credential
  - [x] 2.5 Implement `createOrUpdateUserInFirestore(firebaseUser:) async throws` method to create/update user document
  - [x] 2.6 Extract user data (userId, email, displayName, profileImageUrl) from Firebase User object
  - [x] 2.7 Create Firestore user document at `users/{userId}` with all required fields (userId, email, displayName, profileImageUrl, createdAt, isOnline, lastSeen)
  - [x] 2.8 Add `signOut() throws` method to sign out from Firebase Auth
  - [x] 2.9 Implement error handling and map Firebase errors to user-friendly error messages
  - [x] 2.10 Add retry logic for Firestore user creation failures (retry once on failure)
  - [x] 2.11 Write unit tests in `AuthServiceTests.swift` for signInWithGoogle (mock Firebase/Google Sign-In)
  - [x] 2.12 Write unit tests for createOrUpdateUserInFirestore (test document creation and updates)
  - [x] 2.13 Write unit tests for signOut method
  - [x] 2.14 Write tests for error scenarios (cancelled sign-in, network error, Firestore failure)

- [x] 3.0 AuthViewModel - State Management & Logic
  - [x] 3.1 Create `ViewModels/AuthViewModel.swift` as an ObservableObject class
  - [x] 3.2 Add @Published properties: `currentUser: User?`, `isLoading: Bool`, `errorMessage: String?`, `isAuthenticated: Bool`
  - [x] 3.3 Inject AuthService dependency in initializer
  - [x] 3.4 Implement `signIn() async` method that calls AuthService.signInWithGoogle()
  - [x] 3.5 Add loading state management (set isLoading to true before sign-in, false after)
  - [x] 3.6 Implement error handling - catch errors from AuthService and set errorMessage
  - [x] 3.7 Map error types to user-friendly messages (cancelled, network error, Firestore failure, permissions revoked)
  - [x] 3.8 Update `currentUser` and `isAuthenticated` properties on successful sign-in
  - [x] 3.9 Implement `signOut()` method that calls AuthService.signOut() and clears state
  - [x] 3.10 Add Firebase Auth state listener in init to detect existing sessions (`Auth.auth().addStateDidChangeListener`)
  - [x] 3.11 Implement automatic error message dismissal after 5 seconds using Task.sleep
  - [x] 3.12 Add logic to sign out user if Google Sign-In succeeds but Firestore creation fails
  - [ ] 3.13 Write unit tests in `AuthViewModelTests.swift` for signIn method (mock AuthService)
  - [ ] 3.14 Write tests for error handling and error message mapping
  - [ ] 3.15 Write tests for signOut functionality
  - [ ] 3.16 Write tests for auth state listener and session persistence

- [x] 4.0 LoginView - UI & User Experience
  - [x] 4.1 Create `Views/Auth/LoginView.swift` as a SwiftUI View
  - [x] 4.2 Add @StateObject property for AuthViewModel
  - [x] 4.3 Implement basic layout with VStack containing app logo/title and sign-in button
  - [x] 4.4 Add "Sign in with Google" button following Google's brand guidelines (use official Google Sign-In button style)
  - [x] 4.5 Implement button action to call authViewModel.signIn()
  - [x] 4.6 Add loading indicator (ProgressView) that shows when authViewModel.isLoading is true
  - [x] 4.7 Disable sign-in button during loading to prevent multiple simultaneous attempts
  - [x] 4.8 Display inline error message below button when authViewModel.errorMessage is not nil
  - [x] 4.9 Style error message with red text and warning icon (use SF Symbols exclamationmark.triangle)
  - [x] 4.10 Implement error message dismissal when user taps sign-in button again
  - [x] 4.11 Add accessibility labels for VoiceOver support (button, error message)
  - [x] 4.12 Test color contrast for error messages (ensure readability)
  - [x] 4.13 Add haptic feedback on successful sign-in (optional - nice to have)
  - [ ] 4.14 Write UI tests in `LoginViewTests.swift` to verify button exists and error messages display correctly (optional)

- [x] 5.0 App Navigation & Auth State Management
  - [x] 5.1 Open `NexusAIApp.swift` and add @StateObject for AuthViewModel at app level
  - [x] 5.2 Implement conditional navigation based on authViewModel.isAuthenticated
  - [x] 5.3 Show LoginView when isAuthenticated is false
  - [x] 5.4 Show ConversationListView (or placeholder) when isAuthenticated is true
  - [x] 5.5 Ensure navigation updates automatically when auth state changes (using @Published properties)
  - [ ] 5.6 Test session persistence: close and reopen app while authenticated - should go directly to conversation list
  - [ ] 5.7 Test logout flow: logout from app should navigate back to LoginView
  - [ ] 5.8 Add temporary profile/settings button in conversation list that triggers logout (for testing)
  - [ ] 5.9 Verify all app screens are blocked until user is authenticated (hard gate)
  - [ ] 5.10 Test complete flow: sign in → see conversation list → force quit app → reopen → still signed in
  - [ ] 5.11 Test error recovery: sign in with network off → see error → turn network on → retry → success
  - [ ] 5.12 Write integration tests for complete auth flow (optional - can be manual testing for now)

---

**Status:** Sub-tasks generated. Ready for implementation.
**Next Step:** Start with Task 1.0 (Firebase Configuration) and proceed sequentially.

