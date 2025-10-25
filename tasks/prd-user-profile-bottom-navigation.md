# PRD: User Profile & Bottom Navigation

## Introduction/Overview

This feature introduces a user profile screen and bottom tab navigation to NexusAI. Currently, users can only access the conversation list and chat screens. This enhancement adds a dedicated profile view where users can see their basic information and log out, along with a bottom navigation bar that allows seamless switching between the conversation list and profile screens.

**Problem:** Users have no way to view their own profile information or easily access logout functionality without navigating through multiple screens.

**Goal:** Provide users with quick access to their profile and improve app navigation through a familiar bottom tab bar pattern (similar to Telegram, WhatsApp, and other messaging apps).

---

## Goals

1. **Profile Visibility:** Enable users to view their own profile information (picture, name, email) in a dedicated screen
2. **Easy Logout:** Provide users with a clear, accessible way to sign out of the app
3. **Improved Navigation:** Implement a bottom tab bar for quick switching between main app sections (Chat and Profile)
4. **Consistent UX:** Follow established iOS patterns for tab-based navigation
5. **Maintain Architecture:** Integrate seamlessly with existing local-first sync framework and repository pattern

---

## User Stories

1. **As a user**, I want to view my profile information so that I can verify my account details.

2. **As a user**, I want to easily log out of the app so that I can switch accounts or secure my device.

3. **As a user**, I want to quickly switch between my conversations and profile so that I can access either feature without navigating through multiple screens.

4. **As a user**, I want the app to remember which tab I was on when I return from background so that my navigation context is preserved.

5. **As a user**, I want to scroll to the top of my conversation list when I tap the Chat tab while already on it so that I can quickly access my most recent conversations.

---

## Functional Requirements

### 1. Bottom Navigation Bar

**FR-1.1:** The app must display a bottom tab bar with two tabs: "Chat" and "Profile"

**FR-1.2:** The Chat tab must display a chat bubble icon (SF Symbol: `message.fill`)

**FR-1.3:** The Profile tab must display a person icon (SF Symbol: `person.fill`)

**FR-1.4:** The bottom tab bar must be visible only on the Conversation List screen and Profile screen

**FR-1.5:** The bottom tab bar must be hidden when navigating to:
- Individual chat screens (ChatView)
- Group chat screens
- Group info screens
- New conversation creation screens
- Any other detail/modal screens

**FR-1.6:** The app must default to the Chat tab on initial launch after authentication

**FR-1.7:** When a user taps a tab that is already active:
- Chat tab: Scroll the conversation list to the top
- Profile tab: Scroll the profile view to the top (if scrollable in the future)

**FR-1.8:** The app must persist the selected tab when transitioning from background to active state

**FR-1.9:** Tab labels must be displayed below the icons ("Chat", "Profile")

**FR-1.10:** The active tab must be visually distinct from inactive tabs (using iOS standard tab bar styling)

### 2. Profile Screen

**FR-2.1:** The Profile screen must display the following user information:
- Profile picture (larger than in conversation list)
- Display name
- Email address

**FR-2.2:** The profile picture must use the existing `ProfileImageView` component with a larger size (120pt diameter recommended)

**FR-2.3:** If no profile picture exists, the view must display the user's initials as fallback (consistent with existing behavior)

**FR-2.4:** The display name must be prominently displayed (e.g., 24pt font, bold)

**FR-2.5:** The email address must be displayed below the name (e.g., 16pt font, secondary color)

**FR-2.6:** The Profile screen must include a "Log Out" button

**FR-2.7:** The "Log Out" button must use standard button styling (not prominently styled or colored red)

**FR-2.8:** When the "Log Out" button is tapped, the app must:
- Call `AuthViewModel.signOut()`
- Clear any cached user data if necessary
- Navigate to the LoginView
- Show a confirmation alert before logging out (optional but recommended)

**FR-2.9:** The Profile screen layout must be centered and visually balanced

**FR-2.10:** The Profile screen must use a standard iOS navigation bar with the title "Profile"

### 3. Data Source & Architecture

**FR-3.1:** The Profile screen must use `LocalUserRepository` as the single source of truth for user data

**FR-3.2:** The Profile screen must follow the existing MVVM pattern with a dedicated `ProfileViewModel`

**FR-3.3:** The `ProfileViewModel` must observe changes to the current user data and update the UI reactively

**FR-3.4:** The Profile screen must display the currently authenticated user's data (matching `AuthViewModel.currentUser`)

**FR-3.5:** The implementation must be consistent with the existing local-first sync framework architecture

### 4. Navigation Flow

**FR-4.1:** The app structure must change from:
```
LoginView → ConversationListView → ChatView
```
To:
```
LoginView → TabBarView (Chat Tab + Profile Tab)
  ├─ Chat Tab → ConversationListView → ChatView → GroupInfoView
  └─ Profile Tab → ProfileView
```

**FR-4.2:** When navigating to ChatView, the tab bar must be hidden

**FR-4.3:** When navigating back from ChatView to ConversationListView, the tab bar must reappear

**FR-4.4:** The back button in ChatView must navigate back to ConversationListView with the tab bar visible

---

## Non-Goals (Out of Scope)

1. **Profile Editing:** This feature does NOT include the ability to edit profile information (name, picture, email). This will be a future enhancement.

2. **Settings Screen:** No dedicated settings screen or advanced user preferences in this version.

3. **Account Management:** No features for account deletion, password changes, or privacy settings.

4. **Additional Tabs:** No other tabs beyond Chat and Profile (e.g., no Settings tab, Search tab, etc.).

5. **Profile Customization:** No ability to set custom status messages, bio, or other profile fields.

6. **View Other Profiles:** This PRD only covers viewing the current user's own profile, not viewing other users' profiles.

7. **Badge Indicators:** No unread count or notification badges on tabs in this version.

8. **Advanced Tab Features:** No long-press actions, tab reordering, or customization options.

---

## Design Considerations

### UI Components

1. **Tab Bar:**
   - Use native SwiftUI `TabView` with `.tabViewStyle(.page)` or standard tab style
   - Standard iOS tab bar appearance (translucent background, blur effect)
   - Icons should use SF Symbols for consistency
   - Follow iOS Human Interface Guidelines for tab bars

2. **Profile Screen Layout:**
   ```
   ┌─────────────────────────┐
   │      [Navigation]       │
   ├─────────────────────────┤
   │                         │
   │     [Profile Pic]       │ ← 120pt diameter
   │                         │
   │    John Smith           │ ← displayName (24pt, bold)
   │  john@example.com       │ ← email (16pt, secondary)
   │                         │
   │                         │
   │     [ Log Out ]         │ ← Standard button
   │                         │
   └─────────────────────────┘
   ```

3. **Visual Consistency:**
   - Reuse existing color scheme and typography from `Constants.swift`
   - Maintain consistent spacing and padding
   - Profile picture uses same `ProfileImageView` component with size parameter

4. **Accessibility:**
   - All tab bar items must have accessibility labels
   - Profile information must be properly labeled for VoiceOver
   - Log out button must have clear accessibility hint

### Navigation Behavior

- Use `.toolbar(.hidden, for: .tabBar)` in ChatView to hide tab bar during chat
- Tab bar should use `.badge()` modifier for future notification counts (infrastructure only, no implementation needed now)
- Smooth transitions when switching tabs

---

## Technical Considerations

### Architecture Integration

1. **Repository Pattern:**
   - `ProfileViewModel` should inject `UserRepositoryProtocol` for testability
   - Use existing `RepositoryFactory.shared.userRepository()` in production
   - Create `MockUserRepository` for unit tests

2. **Local-First Sync:**
   - Profile data should come from `LocalUserRepository`
   - Changes to user data in Firestore should automatically sync to local database
   - UI should reactively update when local user data changes

3. **State Management:**
   - Selected tab state should be stored in `@AppStorage` for persistence
   - Use `@StateObject` for `ProfileViewModel` lifecycle management
   - Leverage existing `AuthViewModel` for logout functionality

4. **File Structure:**
   ```
   NexusAI/
   ├── Views/
   │   ├── Main/
   │   │   └── MainTabView.swift          (NEW - Tab bar container)
   │   ├── Profile/
   │   │   └── ProfileView.swift          (NEW - Profile screen)
   │   └── ...
   ├── ViewModels/
   │   └── ProfileViewModel.swift         (NEW - Profile state management)
   └── ...
   ```

### Dependencies

- **Existing Components:**
  - `ProfileImageView` (reuse with size parameter)
  - `AuthViewModel` (for logout functionality)
  - `UserRepository` / `LocalUserRepository` (for data access)

- **New Dependencies:**
  - None (uses existing SwiftUI and Firebase infrastructure)

### Testing Considerations

- Unit tests for `ProfileViewModel` with mock repository
- Test tab persistence with `@AppStorage`
- Test logout flow integration
- Manual testing: tab switching, scroll-to-top, background/foreground transitions

---

## Success Metrics

1. **Feature Adoption:** 100% of users can access their profile screen within first session
2. **Logout Accessibility:** Users can successfully log out in < 3 taps from any screen
3. **Navigation Efficiency:** Users can switch between Chat and Profile in < 1 second
4. **Zero Crashes:** No crashes related to tab navigation or profile screen rendering
5. **Data Accuracy:** Profile information matches authenticated user data 100% of the time

---

## Open Questions

1. **Logout Confirmation:**
   - Should we show a confirmation alert before logging out? ("Are you sure you want to log out?")
   - Recommendation: Yes, to prevent accidental logouts

2. **Empty State:**
   - What should happen if user data fails to load in ProfileView?
   - Recommendation: Show error message with retry button

3. **Scroll to Top Animation:**
   - Should scroll-to-top be animated or instant?
   - Recommendation: Animated for better UX

4. **Profile Picture Tap:**
   - Should tapping the profile picture do anything? (e.g., show full-screen image)
   - Recommendation: No action for MVP, consider for future enhancement

5. **Tab Badge Infrastructure:**
   - Should we add infrastructure for unread count badges even if not implementing the feature now?
   - Recommendation: Yes, add badge infrastructure for easy future implementation

---

## Implementation Priority

### Phase 1: Core Navigation (High Priority)
- Create `MainTabView` with Chat and Profile tabs
- Hide tab bar in ChatView and other detail screens
- Implement tab persistence with `@AppStorage`

### Phase 2: Profile Screen (High Priority)
- Create `ProfileView` with basic layout
- Create `ProfileViewModel` with repository integration
- Display profile picture, name, and email
- Implement logout functionality

### Phase 3: Polish & Edge Cases (Medium Priority)
- Implement scroll-to-top on active tab tap
- Add logout confirmation alert
- Error handling for missing user data
- Accessibility improvements

### Phase 4: Testing (Medium Priority)
- Unit tests for `ProfileViewModel`
- Integration testing for tab navigation
- Manual testing for all navigation flows

---

## Appendix: User Flow Diagram

```
[App Launch]
     ↓
[User Authenticated?] → No → [LoginView]
     ↓ Yes                        ↓
[MainTabView]              [Google Sign In]
     ↓                             ↓
[Default: Chat Tab]          [MainTabView]
     ↓
┌────────────────────────────────┐
│  Chat Tab  │  Profile Tab      │
└────────────────────────────────┘
     ↓              ↓
[ConversationList]  [ProfileView]
     ↓                   ↓
[Tap Conversation]  [View Profile Info]
     ↓                   ↓
[ChatView]          [Tap Log Out]
(Tab bar hidden)         ↓
     ↓              [Confirmation Alert?]
[Back Button]            ↓
     ↓              [AuthViewModel.signOut()]
[ConversationList]       ↓
(Tab bar visible)   [LoginView]
```

---

## Related Documents

- `memory-bank/systemPatterns.md` - MVVM architecture and repository pattern
- `memory-bank/techContext.md` - SwiftUI and Firebase integration
- `tasks/prd-authentication-flow.md` - Authentication patterns and logout flow
- `NexusAI/Data/Repositories/UserRepository.swift` - Data access for user information

---

**Document Version:** 1.0  
**Created:** October 24, 2025  
**Status:** Ready for Implementation

