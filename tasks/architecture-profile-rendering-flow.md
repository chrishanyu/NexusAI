# Architecture: Profile Picture Rendering Flow

## Overview
This document explains how the UserRepository layer interacts with the rendering layer (SwiftUI views) to display profile pictures in NexusAI.

---

## Layer-by-Layer Breakdown

### 1. Database Layer (Bottom)

#### LocalDatabase.swift
**Purpose:** SwiftData wrapper providing CRUD and reactive queries

```swift
@MainActor
class LocalDatabase {
    private let modelContext: ModelContext
    
    // CRUD Operations
    func insert<T: PersistentModel>(_ entity: T) throws
    func fetchOne<T>(where predicate: Predicate<T>) throws -> T?
    func update<T>(_ entity: T) throws
    func save() throws
    
    // Reactive Queries
    func observeOne<T>(where predicate: Predicate<T>) -> AsyncStream<T?>
    
    // Change Notification
    func notifyChanges() {
        NotificationCenter.default.post(name: .localDatabaseDidChange, object: nil)
    }
}
```

**Key Points:**
- Wraps SwiftData ModelContext
- Provides AsyncStream for reactive queries
- Sends notifications when data changes
- Single source of truth for all local data

#### LocalUser.swift
**Purpose:** SwiftData persistence model

```swift
@Model
final class LocalUser {
    @Attribute(.unique) var id: String
    var displayName: String
    var email: String
    var profileImageUrl: String?        // Google photo URL
    var isOnline: Bool
    var lastSeen: Date
    var syncStatus: SyncStatus
    var createdAt: Date
    var updatedAt: Date
    
    // New fields for improvements
    var avatarColorHex: String?         // Persistent color
    var cachedInitials: String?         // Precomputed initials
    var cachedImagePath: String?        // Local file path
    var cachedImageLastAccess: Date?    // LRU tracking
    
    // Conversion
    func toUser() -> User {
        return User(
            id: id,
            displayName: displayName,
            profileImageUrl: profileImageUrl,
            // ... other fields
        )
    }
}
```

---

### 2. Repository Layer (Middle)

#### UserRepositoryProtocol.swift
**Purpose:** Define contract for user data access

```swift
@MainActor
protocol UserRepositoryProtocol {
    // Read Operations
    func getUser(userId: String) async throws -> User?
    func getUsers(userIds: [String]) async throws -> [User]
    
    // Reactive Queries
    func observeUser(userId: String) -> AsyncStream<User?>
    func observeUsers(userIds: [String]) -> AsyncStream<[String: User]>
    
    // Write Operations
    func saveUser(_ user: User) async throws -> User
    func updateProfile(userId: String, displayName: String?, profileImageUrl: String?) async throws
    func updatePresence(userId: String, isOnline: Bool, lastSeen: Date?) async throws
}
```

**Key Points:**
- Protocol-based for testability
- ViewModels depend on protocol, not concrete implementation
- Hides SwiftData details from ViewModels

#### UserRepository.swift
**Purpose:** Concrete implementation of repository

```swift
@MainActor
final class UserRepository: UserRepositoryProtocol {
    private let database: LocalDatabase
    
    func getUser(userId: String) async throws -> User? {
        // 1. Create predicate
        let predicate = #Predicate<LocalUser> { $0.id == userId }
        
        // 2. Fetch from LocalDatabase
        let localUser = try database.fetchOne(LocalUser.self, where: predicate)
        
        // 3. Convert LocalUser → User (domain model)
        return localUser?.toUser()
    }
    
    func observeUser(userId: String) -> AsyncStream<User?> {
        let predicate = #Predicate<LocalUser> { $0.id == userId }
        
        return AsyncStream { continuation in
            let task = Task {
                // Stream from database
                let stream = database.observeOne(LocalUser.self, where: predicate)
                
                // Convert each emission
                for await localUser in stream {
                    continuation.yield(localUser?.toUser())
                }
            }
            
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

**Responsibilities:**
1. Convert between LocalUser (persistence) ↔ User (domain model)
2. Handle database operations
3. Provide reactive streams
4. Abstract SwiftData from ViewModels

#### RepositoryFactory.swift
**Purpose:** Centralized repository creation

```swift
@MainActor
final class RepositoryFactory {
    static let shared = RepositoryFactory()
    
    private let database: LocalDatabase
    private lazy var _userRepository = UserRepository(database: database)
    
    var userRepository: UserRepositoryProtocol {
        _userRepository
    }
}
```

---

### 3. ViewModel Layer

#### ProfileViewModel.swift
**Purpose:** Manage profile screen state, depend on repository

```swift
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let userRepository: UserRepositoryProtocol
    private let authViewModel: AuthViewModel
    
    init(userRepository: UserRepositoryProtocol? = nil, authViewModel: AuthViewModel) {
        self.userRepository = userRepository ?? RepositoryFactory.shared.userRepository
        self.authViewModel = authViewModel
        
        Task {
            await loadCurrentUser()
        }
    }
    
    // Computed properties for view
    var displayName: String {
        currentUser?.displayName ?? "Unknown User"
    }
    
    var profileImageUrl: String? {
        currentUser?.profileImageUrl
    }
    
    // Load user from repository
    func loadCurrentUser() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Call repository
            if let user = try await userRepository.getUser(userId: userId) {
                self.currentUser = user  // Update @Published property
            } else {
                errorMessage = "Profile data not available"
            }
        } catch {
            errorMessage = "Failed to load profile: \(error)"
        }
    }
}
```

**Key Points:**
- Depends on UserRepositoryProtocol (not concrete UserRepository)
- Exposes @Published properties for views to observe
- Handles loading states and errors
- Transforms repository data for UI consumption

---

### 4. View Layer (Top)

#### ProfileView.swift
**Purpose:** Display profile UI, observe ViewModel

```swift
struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var viewModel: ProfileViewModel?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let vm = viewModel {
                    ProfileContentView(viewModel: vm)
                } else {
                    ProgressView("Loading profile...")
                }
            }
            .onAppear {
                if viewModel == nil {
                    // Create ViewModel lazily (after authViewModel available)
                    viewModel = ProfileViewModel(authViewModel: authViewModel)
                }
            }
        }
    }
}

struct ProfileContentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Profile Picture Component
            ProfileImageView(
                imageUrl: viewModel.profileImageUrl,
                displayName: viewModel.displayName,
                size: 120
            )
            
            Text(viewModel.displayName)
            Text(viewModel.email)
        }
    }
}
```

**Key Points:**
- Observes ProfileViewModel via @ObservedObject
- Automatically re-renders when @Published properties change
- Passes data to ProfileImageView component

#### ProfileImageView.swift
**Purpose:** Reusable component for rendering profile pictures

```swift
struct ProfileImageView: View {
    let imageUrl: String?
    let displayName: String
    let size: CGFloat
    
    var body: some View {
        Group {
            if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                // Try to load image from URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackView  // Show initials if download fails
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                // No URL provided, show initials
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var fallbackView: some View {
        ZStack {
            Circle().fill(fallbackBackgroundColor)
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var initials: String {
        let words = displayName.components(separatedBy: " ")
        if let first = words.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
    
    private var fallbackBackgroundColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        let index = abs(displayName.hashValue) % colors.count
        return colors[index]
    }
}
```

**Key Points:**
- Receives imageUrl and displayName as props
- Pure presentational component (no business logic)
- Handles 3 states: loading, success, fallback
- Generates initials on-the-fly (will be enhanced)

---

## Complete Data Flow Example

### Scenario: User opens Profile screen

```
┌──────────────────────────────────────────────────────────────┐
│ Step 1: View Initialization                                  │
└──────────────────────────────────────────────────────────────┘

ProfileView.onAppear()
    └─> viewModel = ProfileViewModel(authViewModel: authViewModel)
        └─> ProfileViewModel.init()
            └─> Task { await loadCurrentUser() }


┌──────────────────────────────────────────────────────────────┐
│ Step 2: ViewModel Fetches Data from Repository              │
└──────────────────────────────────────────────────────────────┘

ProfileViewModel.loadCurrentUser()
    ├─> let userId = Auth.auth().currentUser?.uid  // "abc123"
    ├─> isLoading = true  // Triggers view update (shows loading)
    │
    └─> try await userRepository.getUser(userId: "abc123")
        │
        └─> UserRepository.getUser(userId: "abc123")
            ├─> let predicate = #Predicate<LocalUser> { $0.id == "abc123" }
            ├─> let localUser = try database.fetchOne(LocalUser.self, where: predicate)
            │   │
            │   └─> LocalDatabase.fetchOne()
            │       ├─> Query SwiftData modelContext
            │       └─> Returns LocalUser(
            │               id: "abc123",
            │               displayName: "John Doe",
            │               email: "john@example.com",
            │               profileImageUrl: "https://lh3.googleusercontent.com/xyz",
            │               isOnline: true,
            │               ...
            │           )
            │
            └─> return localUser?.toUser()
                └─> User(
                        id: "abc123",
                        displayName: "John Doe",
                        email: "john@example.com",
                        profileImageUrl: "https://lh3.googleusercontent.com/xyz"
                    )


┌──────────────────────────────────────────────────────────────┐
│ Step 3: ViewModel Updates @Published Property               │
└──────────────────────────────────────────────────────────────┘

ProfileViewModel
    ├─> self.currentUser = user  // @Published property changed
    └─> isLoading = false         // @Published property changed
        │
        └─> SwiftUI automatically detects changes
            └─> Schedules view re-render


┌──────────────────────────────────────────────────────────────┐
│ Step 4: View Re-renders with New Data                       │
└──────────────────────────────────────────────────────────────┘

ProfileContentView.body
    ├─> viewModel.displayName     // "John Doe"
    ├─> viewModel.profileImageUrl // "https://lh3.googleusercontent.com/xyz"
    │
    └─> ProfileImageView(
            imageUrl: "https://lh3.googleusercontent.com/xyz",
            displayName: "John Doe",
            size: 120
        )


┌──────────────────────────────────────────────────────────────┐
│ Step 5: ProfileImageView Renders                            │
└──────────────────────────────────────────────────────────────┘

ProfileImageView.body
    ├─> imageUrl exists → Try AsyncImage
    │   ├─> AsyncImage downloads from URL
    │   ├─> Phase: .empty → Show gray circle + spinner
    │   ├─> Phase: .success → Show downloaded image
    │   └─> Phase: .failure → Show initials fallback
    │
    └─> If imageUrl is nil → Show initials fallback immediately
```

---

## Reactive Updates (Real-Time)

### Scenario: Another device updates user's display name

```
┌──────────────────────────────────────────────────────────────┐
│ Step 1: Firestore Receives Update                           │
└──────────────────────────────────────────────────────────────┘

Device 2: User changes name "John Doe" → "Jonathan Doe"
    └─> Firestore: users/abc123 updated


┌──────────────────────────────────────────────────────────────┐
│ Step 2: SyncEngine Pulls Update                             │
└──────────────────────────────────────────────────────────────┘

SyncEngine (on Device 1)
    ├─> Firestore listener detects change
    ├─> Pull updated User from Firestore
    ├─> Convert to LocalUser
    │   └─> LocalUser(displayName: "Jonathan Doe", ...)
    │
    └─> LocalDatabase.update(localUser)
        └─> modelContext.save()
            └─> LocalDatabase.notifyChanges()
                └─> NotificationCenter.post(.localDatabaseDidChange)


┌──────────────────────────────────────────────────────────────┐
│ Step 3: Repository Emits via AsyncStream                    │
└──────────────────────────────────────────────────────────────┘

UserRepository.observeUser("abc123") AsyncStream
    ├─> Observing LocalDatabase changes
    ├─> Detects LocalUser update
    │
    └─> Emits: User(displayName: "Jonathan Doe", ...)


┌──────────────────────────────────────────────────────────────┐
│ Step 4: ViewModel Receives Update                           │
└──────────────────────────────────────────────────────────────┘

ProfileViewModel
    ├─> for await user in userRepository.observeUser("abc123")
    │       └─> self.currentUser = user  // @Published updated
    │
    └─> SwiftUI detects change → View re-renders


┌──────────────────────────────────────────────────────────────┐
│ Step 5: View Updates Automatically                          │
└──────────────────────────────────────────────────────────────┘

ProfileContentView
    └─> viewModel.displayName now returns "Jonathan Doe"
        └─> ProfileImageView receives new displayName
            └─> Initials recomputed: "JD" → "JD" (same)
```

---

## Where Each Component Lives

### File Structure
```
NexusAI/
├── Data/
│   ├── LocalDatabase.swift                    # [Database Layer]
│   ├── Models/
│   │   └── LocalUser.swift                    # [Database Layer]
│   └── Repositories/
│       ├── UserRepository.swift               # [Repository Layer]
│       ├── RepositoryFactory.swift            # [Repository Layer]
│       └── Protocols/
│           └── UserRepositoryProtocol.swift   # [Repository Layer]
│
├── Models/
│   └── User.swift                             # [Domain Model - used by all layers]
│
├── ViewModels/
│   └── ProfileViewModel.swift                 # [ViewModel Layer]
│
└── Views/
    ├── Profile/
    │   └── ProfileView.swift                  # [View Layer]
    └── Components/
        └── ProfileImageView.swift             # [View Layer - Reusable]
```

---

## Key Architectural Benefits

### 1. Separation of Concerns
- **Database Layer:** Handles persistence (SwiftData)
- **Repository Layer:** Handles data access and conversion
- **ViewModel Layer:** Handles business logic and state
- **View Layer:** Handles presentation

### 2. Testability
```swift
// Unit test with mock repository
let mockRepo = MockUserRepository()
mockRepo.mockUser = User(id: "123", displayName: "Test User", ...)

let viewModel = ProfileViewModel(userRepository: mockRepo, authViewModel: authVM)
await viewModel.loadCurrentUser()

XCTAssertEqual(viewModel.displayName, "Test User")
```

### 3. Flexibility
- Can swap SwiftData for CoreData without changing ViewModels
- Can add caching layer in repository without touching views
- Can change UI without touching business logic

### 4. Reactive Updates
- Database changes automatically flow to UI
- No manual refresh needed
- Consistent state across all views

---

## What Changes for Profile Picture Improvements

### New Fields in LocalUser
```swift
@Model
final class LocalUser {
    // ... existing ...
    
    // NEW: Persistent avatar data
    var avatarColorHex: String?         // "#007AFF"
    var cachedInitials: String?         // "JD"
    var cachedImagePath: String?        // "/path/to/cached/image.jpg"
    var cachedImageLastAccess: Date?    // For LRU eviction
}
```

### New Service Layer
```swift
// NEW: Image caching service
actor ImageCacheService {
    func cacheImage(_ data: Data, for url: String) async throws
    func getCachedImage(for url: String) async -> Data?
}
```

### Updated ProfileImageView
```swift
struct ProfileImageView: View {
    @State private var cachedImageData: Data?
    
    var body: some View {
        Group {
            if let cachedData = cachedImageData {
                // NEW: Show cached image immediately
                Image(uiImage: UIImage(data: cachedData)!)
            } else if let imageUrl = imageUrl {
                // Download and cache
                AsyncImage(url: URL(string: imageUrl)!) { phase in
                    // ... cache on success
                }
            } else {
                // NEW: Two-letter initials with persistent color
                fallbackView
            }
        }
        .onAppear {
            // NEW: Check cache on appear
            Task {
                cachedImageData = await ImageCacheService.shared.getCachedImage(for: imageUrl)
            }
        }
    }
    
    private var initials: String {
        // NEW: Two-letter logic
        let words = displayName.components(separatedBy: " ")
        if words.count >= 2 {
            return "\(words[0].first!)\(words[1].first!)".uppercased()
        }
        // ... handle other cases
    }
    
    private var fallbackBackgroundColor: Color {
        // NEW: Load from user.avatarColorHex if available
        if let colorHex = user?.avatarColorHex {
            return Color(hex: colorHex)
        }
        // Fallback to generation
        return generateColor(from: displayName)
    }
}
```

---

## Summary

The **UserRepository** acts as a **bridge** between:
- **Database (LocalUser models in SwiftData)** ↔ **ViewModels (User domain models)**

**Key Flow:**
1. LocalDatabase stores LocalUser with SwiftData
2. UserRepository reads LocalUser, converts to User
3. ProfileViewModel receives User, exposes @Published properties
4. ProfileView observes ViewModel, passes data to ProfileImageView
5. ProfileImageView renders image or initials

**Reactive Updates:**
- LocalDatabase.notifyChanges() → AsyncStream → ViewModel → View

**Why This Architecture?**
- ✅ Testable (mock repositories)
- ✅ Flexible (swap persistence layers)
- ✅ Reactive (automatic UI updates)
- ✅ Separated concerns (clear responsibilities)

---

**Created:** October 26, 2025  
**Version:** 1.0

