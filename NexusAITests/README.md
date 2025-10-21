# NexusAI Tests - Setup Guide

## Quick Setup (5 minutes)

### Step 1: Add Test Target in Xcode

1. Open `NexusAI.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "NexusAI")
3. Click the **"+"** button at the bottom of the targets list
4. Select **iOS > Unit Testing Bundle**
5. Name it: `NexusAITests`
6. Click **Finish**

### Step 2: Add Files to Test Target

1. Select `NexusAITests` folder in the navigator
2. For each test file, open **File Inspector** (right panel)
3. Check the box next to `NexusAITests` under "Target Membership"

Files to add:
- `NexusAITests/Services/AuthServiceTests.swift`
- `NexusAITests/Mocks/MockAuthService.swift`

### Step 3: Add Dependencies to Test Target

1. Select `NexusAITests` target
2. Go to **General** tab
3. Scroll to **Frameworks and Libraries**
4. Click **"+"** and add:
   - `FirebaseAuth`
   - `FirebaseFirestore`  
   - `FirebaseCore`
   - `GoogleSignIn`

### Step 4: Run Tests

Press `Cmd + U` in Xcode or click the test diamond next to any test method.

## Test Structure

```
NexusAITests/
├── Services/
│   └── AuthServiceTests.swift      # 15 tests for AuthService
├── Mocks/
│   └── MockAuthService.swift       # Mock implementation for testing
└── README.md                        # This file
```

## Test Coverage

### AuthServiceTests (15 tests)
- ✅ `testSignInWithGoogle_Success` - Happy path sign-in
- ✅ `testSignInWithGoogle_Cancelled` - User cancels sign-in
- ✅ `testSignInWithGoogle_NetworkError` - Network failure
- ✅ `testSignInWithGoogle_MissingIDToken` - Missing token error
- ✅ `testCreateOrUpdateUserInFirestore_NewUser` - Create new user
- ✅ `testCreateOrUpdateUserInFirestore_ExistingUser` - Update existing user
- ✅ `testCreateOrUpdateUserInFirestore_RetryOnFailure` - Retry logic with delay
- ✅ `testCreateOrUpdateUserInFirestore_RetryExhausted` - Retry exhausted
- ✅ `testSignOut_Success` - Successful sign out
- ✅ `testSignOut_NoCurrentUser` - Sign out with no user
- ✅ `testSignOut_OnlineStatusUpdateFails` - Error during sign out
- ✅ `testErrorMapping_GoogleSignInCancelled` - Error message verification
- ✅ `testErrorMapping_GoogleSignInFailed` - Error message verification
- ✅ `testErrorMapping_FirestoreError` - Error message verification
- ✅ Plus 4 more error scenario tests

## Running Tests

### Run All Tests
```bash
# In Xcode
Cmd + U

# Or from command line
xcodebuild test -scheme NexusAI -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Specific Test
Click the diamond icon next to the test method in Xcode.

### Run Test Class
Click the diamond icon next to the class name.

## What These Tests Cover

### ✅ Covered
- Google Sign-In flow (mocked)
- User profile creation/update (mocked)
- Sign out functionality (mocked)
- Error handling and mapping
- Retry logic behavior
- Edge cases (missing tokens, network errors, etc.)

### ❌ Not Covered (Integration Tests - Manual)
- Real Google OAuth flow
- Real Firebase Auth integration
- Real Firestore document operations
- UI presentation of Google Sign-In

## Notes

- These are **unit tests** using mocks
- Real Firebase integration should be tested manually on simulator
- Tests run fast (~0.5s total) because they don't hit real services
- Add more tests as you build ViewModels and Views

## Troubleshooting

**Problem:** "No such module 'NexusAI'"
- **Solution:** Make sure test target has access to main app target in Build Settings

**Problem:** "Cannot find MockAuthService"  
- **Solution:** Add `MockAuthService.swift` to test target membership

**Problem:** Tests timeout
- **Solution:** Check async/await syntax, ensure mocks don't have long delays

**Problem:** Firebase imports fail
- **Solution:** Add Firebase frameworks to test target dependencies

## Next Steps

After tests pass:
1. ✅ Tests verified working
2. ⏭️ Create AuthViewModel with tests
3. ⏭️ Create LoginView with tests  
4. ⏭️ Integrate authentication flow
5. ⏭️ Manual testing on simulator

