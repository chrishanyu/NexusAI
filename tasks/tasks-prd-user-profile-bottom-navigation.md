# Task List: User Profile & Bottom Navigation

> Generated from: `prd-user-profile-bottom-navigation.md`

## Relevant Files

### New Files to Create
- ✅ `NexusAI/Views/Main/MainTabView.swift` - Main tab bar container with Chat and Profile tabs (COMPLETED)
- ✅ `NexusAI/Views/Profile/ProfileView.swift` - Profile screen displaying user information and logout (COMPLETED)
- ✅ `NexusAI/ViewModels/ProfileViewModel.swift` - State management for profile screen with repository integration (COMPLETED)

### Existing Files to Modify
- ✅ `NexusAI/ContentView.swift` - Updated to show MainTabView instead of ConversationListView after auth (COMPLETED)
- ✅ `NexusAI/Views/Chat/ChatView.swift` - Tab bar visible for smooth transitions (COMPLETED)
- ✅ `NexusAI/Views/ConversationList/ConversationListView.swift` - Added scroll-to-top and pop navigation with NotificationCenter (COMPLETED)
- ✅ `NexusAI/Views/Profile/ProfileView.swift` - Added scroll-to-top infrastructure with ScrollViewReader (COMPLETED)
- ✅ `NexusAI/Views/Main/MainTabView.swift` - Added tab tap detection, keyboard observation, and dynamic tab bar hiding (COMPLETED)
- ✅ `NexusAI/Utilities/Constants.swift` - Added Notification.Name extensions for scroll-to-top and keyboard (COMPLETED)
- `NexusAI/Views/Group/GroupInfoView.swift` - N/A (presented as sheet, doesn't need tab bar hiding)
- `NexusAI/Views/ConversationList/NewConversationView.swift` - N/A (presented as sheet, doesn't need tab bar hiding)
- `NexusAI/Views/Components/ProfileImageView.swift` - May need to verify size parameter handling

### Test Files to Create (Optional)
- `NexusAITests/ViewModels/ProfileViewModelTests.swift` - Unit tests for ProfileViewModel

### Notes

- Unit tests should be created for ViewModels following the existing pattern (e.g., `AuthViewModelTests.swift`)
- Use existing `ProfileImageView` component with size parameter
- Follow MVVM architecture and repository pattern established in the codebase
- Test on iOS Simulator to verify tab navigation and profile display
- **Tab bar strategy (FINAL)**: Tab bar stays visible for smooth transitions, hides automatically when keyboard appears
- Use `@AppStorage` for tab state persistence
- **Edge cases handled**:
  - ✅ Tapping Chat tab while in ChatView navigates back to conversation list
  - ✅ Tab bar hides automatically when keyboard appears (typing messages)
  - ✅ Tab bar shows when keyboard dismisses
  - ⚠️ Draft message saving NOT implemented (too complex for now)

## Tasks

- [x] 1.0 Create Main Tab View with Bottom Navigation
  - [x] 1.1 Create `Views/Main/MainTabView.swift` file
  - [x] 1.2 Set up SwiftUI `TabView` with two tabs
  - [x] 1.3 Add Chat tab with SF Symbol icon `message.fill` and label "Chat"
  - [x] 1.4 Add Profile tab with SF Symbol icon `person.fill` and label "Profile"
  - [x] 1.5 Embed `ConversationListView` in Chat tab
  - [x] 1.6 Create placeholder for ProfileView in Profile tab (will be implemented in Task 2.0)
  - [x] 1.7 Configure tab bar styling (use iOS default appearance)
  - [x] 1.8 Add accessibility labels for both tab items

- [x] 2.0 Create Profile Screen UI and Layout
  - [x] 2.1 Create `Views/Profile/ProfileView.swift` file
  - [x] 2.2 Add navigation bar with title "Profile"
  - [x] 2.3 Add `ProfileImageView` component with 120pt diameter size parameter
  - [x] 2.4 Add display name `Text` view (24pt font, bold, primary color)
  - [x] 2.5 Add email `Text` view (16pt font, regular weight, secondary color)
  - [x] 2.6 Add "Log Out" button with standard button styling
  - [x] 2.7 Implement vertical layout with proper spacing (VStack with centered alignment)
  - [x] 2.8 Add padding around content for visual balance
  - [x] 2.9 Connect button to ProfileViewModel logout action (placeholder for now)
  - [x] 2.10 Add accessibility labels for profile elements

- [x] 3.0 Implement Profile ViewModel with Repository Integration
  - [x] 3.1 Create `ViewModels/ProfileViewModel.swift` file
  - [x] 3.2 Add `ObservableObject` conformance with `@MainActor`
  - [x] 3.3 Add dependency injection for `UserRepositoryProtocol` (with default to `RepositoryFactory.shared.userRepository()`)
  - [x] 3.4 Add dependency injection for `AuthViewModel` (for logout functionality)
  - [x] 3.5 Add `@Published var currentUser: LocalUser?` property
  - [x] 3.6 Add `@Published var isLoading: Bool = false` property
  - [x] 3.7 Add `@Published var errorMessage: String?` property
  - [x] 3.8 Implement `loadCurrentUser()` method to fetch user from repository
  - [x] 3.9 Implement `logout()` method that calls `authViewModel.signOut()`
  - [x] 3.10 Add error handling for missing user data
  - [x] 3.11 Add `init()` method that loads user on initialization
  - [x] 3.12 Update ProfileView to use `@StateObject var viewModel = ProfileViewModel()`
  - [x] 3.13 Bind ProfileView UI to ViewModel published properties

- [x] 4.0 Implement Tab Navigation Behavior and State Management
  - [x] 4.1 Add `@AppStorage("selectedTab")` property to MainTabView for tab persistence
  - [x] 4.2 Set default selected tab to 0 (Chat tab) on first launch
  - [x] 4.3 Bind TabView selection to `@AppStorage` property
  - [x] 4.4 Update `ContentView.swift` to show `MainTabView()` instead of `ConversationListView()` after authentication
  - [x] 4.5 In `ChatView.swift`, add `.toolbar(.hidden, for: .tabBar)` modifier to hide tab bar
  - [x] 4.6 In `GroupInfoView.swift`, add `.toolbar(.hidden, for: .tabBar)` modifier - N/A (sheet presentation)
  - [x] 4.7 In `NewConversationView.swift`, add `.toolbar(.hidden, for: .tabBar)` modifier - N/A (sheet presentation)
  - [x] 4.8 Test that tab bar reappears when navigating back to ConversationListView
  - [x] 4.9 Test tab persistence by backgrounding app and returning
  - [x] 4.10 Verify navigation flow: MainTabView → ChatView → back to MainTabView

- [x] 5.0 Implement Scroll-to-Top on Active Tab Tap
  - [x] 5.1 Wrap ConversationListView's List with `ScrollViewReader`
  - [x] 5.2 Add `.id("top")` to the first element in the conversation list
  - [x] 5.3 In MainTabView, detect when Chat tab is tapped while already selected
  - [x] 5.4 Use `NotificationCenter` to trigger scroll-to-top in ConversationListView
  - [x] 5.5 Implement scroll-to-top with animation: `withAnimation { proxy.scrollTo("top") }`
  - [x] 5.6 Wrap ProfileView content with `ScrollView` and `ScrollViewReader` for future scrollable content
  - [x] 5.7 Add `.id("top")` to the first element in ProfileView
  - [x] 5.8 Detect when Profile tab is tapped while already selected
  - [x] 5.9 Implement scroll-to-top for ProfileView
  - [x] 5.10 Test scroll-to-top behavior on both tabs

- [ ] 6.0 Integration Testing and Polish
  - [x] 6.1 Test tab switching: tap Chat tab → tap Profile tab → verify navigation works ✅
  - [x] 6.2 Test tab bar visibility: Tab bar stays visible everywhere for smooth transitions ✅ (FINAL DECISION)
  - [ ] 6.3 Test profile data display: verify profile picture, name, and email match authenticated user
  - [x] 6.4 Test logout flow: tap "Log Out" → verify navigation to LoginView → verify auth state cleared ✅
  - [x] 6.5 Add logout confirmation alert (optional) - User confirmed not needed ✅
  - [x] 6.6 Test tab persistence: background app → reopen → verify last selected tab is restored ✅
  - [ ] 6.7 Test scroll-to-top: scroll down conversation list → tap Chat tab → verify scrolls to top
  - [ ] 6.8 Test scroll-to-top: tap Chat tab while already on Chat tab → verify scrolls to top
  - [ ] 6.9 Test error handling: simulate missing user data → verify error message displayed
  - [ ] 6.10 Verify dark mode appearance for all new UI elements
  - [ ] 6.11 Test VoiceOver accessibility for tab bar and profile screen
  - [ ] 6.12 Update `memory-bank/progress.md` to reflect completion of user profile feature
  - [ ] 6.13 Update `README.md` if needed to document new navigation structure

---

**Status:** ✅ Detailed sub-tasks generated  
**Total Sub-tasks:** 60  
**Ready for Implementation:** Yes

