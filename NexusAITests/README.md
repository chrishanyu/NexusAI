# NexusAI Tests - Setup Guide

## Testing Framework

This project uses **XCTest** (Apple's standard testing framework) for all unit tests.

- ✅ Mature and stable (iOS 7+)
- ✅ Excellent Xcode integration
- ✅ Works with SwiftData in-memory testing
- ✅ Standard assertions: `XCTAssertEqual()`, `XCTAssertTrue()`, etc.

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
- `NexusAITests/Data/LocalDatabaseTests.swift`
- `NexusAITests/Data/Models/LocalMessageTests.swift`
- `NexusAITests/Data/Models/LocalConversationTests.swift`
- `NexusAITests/Data/Models/LocalUserTests.swift`

### Step 3: Add Dependencies to Test Target

**No external dependencies needed!** These tests only use SwiftData which is built into iOS 17+.

### Step 4: Run Tests

Press `Cmd + U` in Xcode or click the test diamond next to any test method.

## Test Structure

```
NexusAITests/
├── Data/
│   ├── LocalDatabaseTests.swift           # Database CRUD operations
│   └── Models/
│       ├── LocalMessageTests.swift        # Message model tests
│       ├── LocalConversationTests.swift   # Conversation model tests
│       └── LocalUserTests.swift           # User model tests
└── README.md                               # This file
```

## Test Coverage

### SwiftData Local Storage Tests

**LocalDatabaseTests** - Generic database operations:
- ✅ Insert single entity
- ✅ Insert batch of entities
- ✅ Fetch with limit
- ✅ Fetch with predicates
- ✅ Fetch one entity
- ✅ Update entities
- ✅ Delete single entity
- ✅ Delete batch
- ✅ Delete all with predicate
- ✅ Count entities

**LocalMessageTests** - Message-specific tests:
- ✅ Message initialization and properties
- ✅ Sync status transitions
- ✅ Read/delivered tracking
- ✅ Timestamp handling

**LocalConversationTests** - Conversation-specific tests:
- ✅ Conversation initialization
- ✅ Participant management
- ✅ Last message tracking
- ✅ Unread count logic

**LocalUserTests** - User model tests:
- ✅ User initialization
- ✅ Online status tracking
- ✅ Profile data management

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
- SwiftData model definitions and properties
- Local database CRUD operations (Create, Read, Update, Delete)
- Query predicates and filtering
- Batch operations
- Entity counting
- Sync status tracking
- In-memory testing (no persistence between tests)

### ❌ Not Covered (Integration Tests - Future)
- Real Firebase integration
- Network synchronization
- Conflict resolution
- Background sync
- Migration between schema versions

## Notes

- These are **unit tests** using in-memory SwiftData
- No external dependencies required (no Firebase, no network)
- Tests run fast (~0.5s total) because they use in-memory storage
- Each test gets a fresh database (clean slate)
- Tests require iOS 17+ for SwiftData support

## Troubleshooting

**Problem:** "No such module 'NexusAI'"
- **Solution:** Make sure test target has access to main app target in Build Settings
- Enable Testability: Build Settings → "Enable Testability" = Yes

**Problem:** "Cannot find 'LocalDatabase' in scope"  
- **Solution:** Ensure `@testable import NexusAI` is at the top of test files
- Verify main app files are in NexusAI target (not test target)

**Problem:** Tests timeout or crash
- **Solution:** Ensure iOS deployment target is iOS 17+ for SwiftData
- Check that `@MainActor` is present on test classes using SwiftData

**Problem:** SwiftData compilation errors
- **Solution:** Make sure deployment target is iOS 17.0 or higher

## Next Steps

After tests pass:
1. ✅ SwiftData models tested and verified
2. ⏭️ Add service layer tests (when Firebase is integrated)
3. ⏭️ Add ViewModel tests
4. ⏭️ Add integration tests for sync logic
5. ⏭️ Test on device for performance

