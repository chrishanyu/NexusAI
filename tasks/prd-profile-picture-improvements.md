# PRD: Profile Picture Improvements

## 1. Introduction/Overview

### Problem Statement
The current profile picture implementation shows single-letter initials and generates colors on-the-fly using hash functions, which can be inconsistent across app restarts. Additionally, profile images downloaded from Google are re-fetched every time they're displayed, wasting bandwidth and causing loading delays.

### Goals
1. **Enhanced Initials:** Display two-letter initials (e.g., "JD" for "John Doe") for better user recognition
2. **Persistent Colors:** Store and persist avatar background colors so users always see the same color for each user
3. **Image Caching:** Cache downloaded profile images locally to reduce network calls and improve performance

### Impact
- **Better UX:** Users will recognize contacts more quickly with two-letter initials
- **Consistency:** Avatar colors remain consistent across app sessions
- **Performance:** Faster image loading and reduced data usage with local caching
- **Offline Support:** Cached images available when offline

---

## 2. Architecture Understanding: UserRepository → Rendering Layer

### Current Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    VIEW LAYER (SwiftUI)                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ProfileImageView                                       │ │
│  │ - Receives: imageUrl, displayName                      │ │
│  │ - Renders: AsyncImage or initials fallback             │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ▲                                │
│                            │ Props (imageUrl, displayName)  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ProfileView / ConversationRowView / ParticipantRow     │ │
│  │ - Observes ProfileViewModel via @ObservedObject        │ │
│  │ - Passes user data to ProfileImageView                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ @Published properties
┌─────────────────────────────────────────────────────────────┐
│                   VIEWMODEL LAYER                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ProfileViewModel (ObservableObject)                    │ │
│  │ @Published var currentUser: User?                      │ │
│  │                                                        │ │
│  │ Computed Properties:                                   │ │
│  │ - displayName: String                                  │ │
│  │ - email: String                                        │ │
│  │ - profileImageUrl: String?                             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ async/await calls
┌─────────────────────────────────────────────────────────────┐
│                  REPOSITORY LAYER                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ UserRepository: UserRepositoryProtocol                 │ │
│  │                                                        │ │
│  │ Methods:                                               │ │
│  │ - getUser(userId) -> User?                             │ │
│  │ - observeUser(userId) -> AsyncStream<User?>            │ │
│  │ - updateProfile(userId, displayName, profileImageUrl) │ │
│  │                                                        │ │
│  │ Converts: LocalUser ↔ User (domain model)              │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ SwiftData operations
┌─────────────────────────────────────────────────────────────┐
│                   DATABASE LAYER                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ LocalDatabase (SwiftData wrapper)                      │ │
│  │                                                        │ │
│  │ Methods:                                               │ │
│  │ - fetchOne(where:) -> LocalUser?                       │ │
│  │ - observeOne(where:) -> AsyncStream<LocalUser?>        │ │
│  │ - insert/update/delete                                 │ │
│  │ - notifyChanges() → NotificationCenter                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ▲                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ LocalUser (@Model)                                     │ │
│  │ - id: String                                           │ │
│  │ - displayName: String                                  │ │
│  │ - email: String                                        │ │
│  │ - profileImageUrl: String?                             │ │
│  │ - isOnline: Bool                                       │ │
│  │ - createdAt, updatedAt, syncStatus                     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns

#### 1. **Protocol-Based Dependency Injection**
- `ProfileViewModel` depends on `UserRepositoryProtocol`, not concrete `UserRepository`
- Enables testing with mock repositories
- Allows swapping implementations without changing ViewModels

#### 2. **Repository Pattern**
- **Purpose:** Abstract data access from ViewModels
- **Responsibilities:**
  - Convert between domain models (`User`) and persistence models (`LocalUser`)
  - Handle CRUD operations
  - Provide reactive queries via `AsyncStream`
  - Notify observers of data changes

#### 3. **Reactive Data Flow**
- LocalDatabase sends `Notification.localDatabaseDidChange` when data changes
- Repositories observe notifications and emit via `AsyncStream`
- ViewModels observe streams and update `@Published` properties
- SwiftUI views automatically re-render when `@Published` properties change

#### 4. **Factory Pattern**
- `RepositoryFactory.shared` provides centralized repository instances
- Ensures single source of truth for data access
- Simplifies dependency injection in ViewModels

### Current Profile Picture Rendering Flow

```
1. User signs in with Google
   └─> AuthService extracts firebaseUser.photoURL
       └─> Saves to Firestore: User.profileImageUrl (String?)

2. SyncEngine pulls from Firestore
   └─> Converts to LocalUser and saves to LocalDatabase (SwiftData)

3. ProfileViewModel initialization
   └─> Calls userRepository.getUser(userId)
       └─> UserRepository.getUser()
           └─> LocalDatabase.fetchOne(LocalUser, where: id == userId)
               └─> Converts LocalUser → User domain model
                   └─> Returns User with profileImageUrl?

4. ProfileViewModel exposes computed property
   └─> var profileImageUrl: String? { currentUser?.profileImageUrl }

5. ProfileView observes ProfileViewModel
   └─> Passes profileImageUrl to ProfileImageView

6. ProfileImageView renders
   └─> If profileImageUrl exists:
       └─> AsyncImage downloads from URL (no caching)
           └─> On success: shows image
           └─> On failure: shows initials fallback
   └─> If profileImageUrl is nil:
       └─> Shows initials fallback (single letter + color from hash)
```

---

## 3. Goals

### Primary Goals
1. **FR-1:** Two-letter initials for better visual recognition
2. **FR-2:** Persistent avatar colors that remain consistent across sessions
3. **FR-3:** Local image caching to reduce network calls and improve performance

### Success Metrics
- Initials display correctly for all name formats (single word, multiple words, empty)
- Avatar colors persist across app restarts and remain consistent
- Profile images load instantly from cache on subsequent views
- Reduced network bandwidth usage for profile image downloads
- Offline support: cached images available when device is offline
- Notification banners show sender's profile picture (not just initials)

---

## 4. User Stories

### US-1: Enhanced Initials Display
**As a** messaging app user  
**I want to** see two-letter initials for contacts without profile pictures  
**So that** I can more easily recognize and distinguish between different users

**Acceptance Criteria:**
- Given a user "John Doe", initials display as "JD"
- Given a user "Alice", initials display as "AL"
- Given a user "Bob Smith Jr.", initials display as "BS"
- Given a user with empty name, initials display as "??"
- Initials are always uppercase

### US-2: Persistent Avatar Colors
**As a** messaging app user  
**I want** each contact to have a consistent avatar color  
**So that** I can quickly recognize users by their color coding

**Acceptance Criteria:**
- User "John Doe" always shows the same background color
- Avatar color persists after app restart
- Avatar color is consistent across all views (conversation list, chat, profile)
- Different users get different colors (8 color options)

### US-3: Image Caching
**As a** messaging app user  
**I want** profile pictures to load instantly  
**So that** I don't see loading spinners every time I view a profile

**Acceptance Criteria:**
- First load downloads image and caches it locally
- Subsequent loads use cached image (instant display)
- Cached images work offline
- Cache respects image URL changes (if user updates their photo)
- Cache has reasonable size limit (e.g., 100MB max)

---

## 5. Functional Requirements

### FR-1: Two-Letter Initials Generation

#### FR-1.1: Initials Extraction Logic
**Requirement:** Extract two letters from display name using smart algorithm

**Implementation:**
```swift
// Priority order:
1. If name has 2+ words: First letter of first word + First letter of second word
   "John Doe" → "JD"
   "Bob Smith Jr." → "BS"
   
2. If name has 1 word with 2+ characters: First two letters
   "Alice" → "AL"
   "Bob" → "BO"
   
3. If name has 1 character: Duplicate the character
   "J" → "JJ"
   
4. If name is empty: Default to "??"
```

#### FR-1.2: Display Formatting
- Initials must always be uppercase
- Font size should scale proportionally with avatar size (40% of diameter)
- Letter spacing should be slightly increased for readability

#### FR-1.3: Accessibility
- Initials must be included in VoiceOver labels
- Sufficient color contrast between text and background (WCAG AA standard)

---

### FR-2: Persistent Avatar Colors

#### FR-2.1: Color Storage in Database
**Requirement:** Store avatar color in LocalUser model for persistence

**Schema Changes:**
```swift
// Add to LocalUser.swift
@Model
final class LocalUser {
    // ... existing properties ...
    
    /// Stored avatar color for consistent display (hex string)
    var avatarColorHex: String?
    
    /// Stored avatar initials for faster display
    var cachedInitials: String?
}
```

**Migration Strategy:**
- Add optional fields to LocalUser model (SwiftData auto-migration)
- Compute and store colors for existing users on first app launch after update
- Default to nil for new fields (computed on-the-fly if missing)

#### FR-2.2: Color Generation and Assignment
**Requirement:** Generate color once and persist it

**Algorithm:**
```swift
// On first encounter with a user:
1. Check if user.avatarColorHex exists
   - If exists: use stored color
   - If nil: generate and store

2. Generate color:
   - Use displayName.hashValue to pick from 8 colors
   - Convert Color to hex string
   - Save to LocalUser.avatarColorHex
   - Mark syncStatus as .pending for backend sync
```

**Color Palette:**
```swift
static let avatarColors: [Color] = [
    Color(hex: "#007AFF"), // Blue
    Color(hex: "#34C759"), // Green
    Color(hex: "#FF9500"), // Orange
    Color(hex: "#AF52DE"), // Purple
    Color(hex: "#FF2D55"), // Pink
    Color(hex: "#FF3B30"), // Red
    Color(hex: "#5856D6"), // Indigo
    Color(hex: "#30B0C7")  // Teal
]
```

#### FR-2.3: Repository Layer Integration
**Requirement:** Update UserRepository to handle avatar color

```swift
// Update UserRepositoryProtocol
protocol UserRepositoryProtocol {
    // ... existing methods ...
    
    /// Update user's cached avatar properties
    func updateAvatarCache(
        userId: String,
        initials: String,
        colorHex: String
    ) async throws
}
```

---

### FR-3: Fix Notification Banner Profile Pictures

#### FR-3.1: Current Problem
**Issue:** Notification banners always show initials, never actual profile pictures

**Root Cause Analysis:**
1. `Message` model doesn't store sender's `profileImageUrl`
2. `BannerData.init(from: Message)` always sets `profileImageUrl = nil`
3. `NotificationBannerManager` doesn't look up sender's User profile
4. Result: All notification banners display initials fallback

**Evidence:**
```swift
// BannerData.swift:65
self.profileImageUrl = nil // Will be fetched separately if needed
// ❌ This "separate fetch" never happens
```

#### FR-3.2: Solution Requirements
**Requirement:** Look up sender's User profile when creating notification banners

**Implementation:**
```swift
// In NotificationBannerManager.swift - handleNewMessage()
func handleNewMessage(_ message: Message) async {
    // ... existing filters ...
    
    // NEW: Look up sender's profile from UserRepository
    let userRepository = RepositoryFactory.shared.userRepository
    let senderUser = try? await userRepository.getUser(userId: message.senderId)
    
    // Create banner with profile image URL
    let bannerData = BannerData(
        conversationId: message.conversationId,
        senderId: message.senderId,
        senderName: message.senderName,
        messageText: message.text,
        profileImageUrl: senderUser?.profileImageUrl,  // ✅ Use fetched URL
        timestamp: message.timestamp
    )
    
    showBanner(bannerData)
}
```

#### FR-3.3: Performance Considerations
- **Lookup Source:** LocalDatabase (UserRepository) - fast, local-only query
- **Cache Hit:** If user is cached, lookup is <10ms
- **Cache Miss:** If user not cached, falls back to initials (acceptable)
- **No Network Call:** Uses existing local-first sync architecture

#### FR-3.4: Fallback Behavior
- If User lookup fails → Show initials (current behavior)
- If profileImageUrl is nil → Show initials (current behavior)  
- If image download fails → Show initials (existing AsyncImage fallback)

---

### FR-4: Local Image Caching

#### FR-4.1: Cache Storage Layer
**Requirement:** Create dedicated image cache manager

**New Service:**
```swift
// New file: Services/ImageCacheService.swift
actor ImageCacheService {
    static let shared = ImageCacheService()
    
    /// Save image to cache
    func cacheImage(_ data: Data, for url: String) async throws
    
    /// Retrieve cached image
    func getCachedImage(for url: String) async -> Data?
    
    /// Check if image is cached
    func isCached(url: String) async -> Bool
    
    /// Clear entire cache
    func clearCache() async throws
    
    /// Get cache size
    func cacheSize() async -> Int64
    
    /// Prune old cache entries (LRU strategy)
    func pruneCache(maxSize: Int64) async throws
}
```

**Storage Location:**
- Use `FileManager.default.urls(for: .cachesDirectory)` + `/ProfileImages/`
- File naming: SHA256 hash of image URL
- Metadata: Store URL → filename mapping in UserDefaults or SQLite

#### FR-4.2: ProfileImageView Integration
**Requirement:** Update ProfileImageView to use cache before downloading

**New Logic:**
```swift
// In ProfileImageView
1. Check if imageUrl exists
   ├─> Check ImageCacheService for cached image
   │   ├─> If cached: Load from disk → display immediately
   │   └─> If not cached: Show loading → Download → Cache → Display
   └─> If nil: Show initials fallback
```

#### FR-4.3: Cache Management
**Requirements:**
- Maximum cache size: 100MB
- Cache invalidation: When user updates profile picture (URL changes)
- LRU eviction: Remove least recently used images when cache is full
- Cache clearing: Provide manual clear option in settings (future)

#### FR-4.4: LocalUser Schema Update
**Requirement:** Track cached image metadata

```swift
// Add to LocalUser.swift
@Model
final class LocalUser {
    // ... existing properties ...
    
    /// Local file path to cached profile image
    var cachedImagePath: String?
    
    /// Last time cached image was accessed (for LRU)
    var cachedImageLastAccess: Date?
}
```

---

## 6. Non-Goals (Out of Scope)

### Explicitly NOT Including:
1. **Custom Avatar Upload:** Users cannot upload custom profile pictures (MVP uses Google photos only)
2. **Avatar Editing:** No in-app avatar editor or emoji avatars
3. **Animated Avatars:** No GIF or video avatars
4. **Avatar Groups:** No composite avatars for group chats (still uses group icon)
5. **High-Resolution Downloads:** Cache uses standard resolution from Google (no 4K/retina optimization)
6. **CDN Integration:** No CDN for profile image delivery (direct Google URLs only)
7. **Image Compression:** No automatic compression/optimization of cached images

---

## 7. Technical Considerations

### 7.1 Database Schema Changes

#### SwiftData Models
```swift
// LocalUser.swift additions
@Model
final class LocalUser {
    // ... existing properties ...
    
    // New properties for avatar improvements
    var avatarColorHex: String?          // Persistent color
    var cachedInitials: String?          // Precomputed initials
    var cachedImagePath: String?         // Local file path
    var cachedImageLastAccess: Date?     // LRU tracking
}
```

**Migration:**
- SwiftData supports automatic lightweight migration for optional property additions
- No custom migration code needed
- Existing users will have nil values, computed on-demand

#### Firestore Schema (Optional - for cross-device sync)
```javascript
// users/{userId}
{
  // ... existing fields ...
  avatarColorHex: string | null,       // Optional
  cachedInitials: string | null        // Optional
}
```

**Sync Strategy:**
- Avatar color syncs to Firestore for consistency across devices
- Initials recomputed on each device (lightweight, no need to sync)
- Cached image paths NOT synced (local-only optimization)

---

### 7.2 Performance Considerations

#### Memory Management
- **ProfileImageView:** Ensure AsyncImage releases memory after image loads
- **Cache Size:** Limit to 100MB to prevent storage bloat
- **Batch Operations:** Use `insertBatch()` when updating multiple users' avatar data

#### Network Optimization
- **Cache-First Strategy:** Always check cache before network request
- **Parallel Downloads:** Use TaskGroup for downloading multiple images
- **Cache Warm-Up:** Preload conversation participants' images in background

#### Database Performance
- **Index on avatarColorHex:** Fast lookups for users with specific colors
- **Index on cachedImageLastAccess:** Efficient LRU sorting for cache eviction

---

### 7.3 Sync Engine Integration

#### Conflict Resolution
```swift
// In ConflictResolver.swift
func resolveUser(local: LocalUser, remote: User) -> ConflictResolution<LocalUser> {
    // Avatar color and initials are local-first
    // Always keep local avatar metadata
    if remoteIsNewer {
        local.displayName = remote.displayName
        local.email = remote.email
        local.profileImageUrl = remote.profileImageUrl
        
        // Recompute initials if displayName changed
        if local.displayName != remote.displayName {
            local.cachedInitials = computeInitials(remote.displayName)
        }
        
        // Keep local avatarColorHex (don't overwrite)
    }
}
```

#### Pull Sync (Firestore → LocalDatabase)
```swift
// In SyncEngine.swift - pullUsers()
func syncUserFromFirestore(_ user: User) async throws {
    // Check if avatarColorHex is set in Firestore
    if let colorHex = user.avatarColorHex, !colorHex.isEmpty {
        localUser.avatarColorHex = colorHex
    } else if localUser.avatarColorHex == nil {
        // Generate and store color if missing
        localUser.avatarColorHex = generateAvatarColor(user.displayName)
    }
}
```

---

### 7.4 Image Caching Implementation Details

#### File System Structure
```
/Library/Caches/ProfileImages/
├── metadata.json              // URL → filename mapping
├── 5f4dcc3b.jpg              // SHA256(imageUrl)
├── 7c6a180b.jpg
└── d3d9446a.jpg
```

#### Metadata Schema
```json
{
  "https://lh3.googleusercontent.com/abc123": {
    "filename": "5f4dcc3b.jpg",
    "lastAccess": "2025-10-26T12:34:56Z",
    "fileSize": 45678
  }
}
```

#### Cache Eviction Strategy (LRU)
```swift
// Pseudocode
func pruneCache(maxSize: Int64) async throws {
    let currentSize = await cacheSize()
    if currentSize > maxSize {
        // Sort by lastAccess (oldest first)
        let sortedFiles = metadata.sorted { $0.lastAccess < $1.lastAccess }
        
        var freedSpace: Int64 = 0
        for file in sortedFiles {
            deleteFile(file.filename)
            freedSpace += file.fileSize
            
            if currentSize - freedSpace <= maxSize * 0.8 { // 80% threshold
                break
            }
        }
    }
}
```

---

## 8. Design Considerations

### 8.1 Visual Design

#### Two-Letter Initials
- **Font:** SF Pro Rounded (system default)
- **Weight:** Semibold
- **Size:** 40% of avatar diameter
- **Color:** White (#FFFFFF)
- **Letter Spacing:** +2% for readability

#### Avatar Color Palette
- **Saturation:** 70-80% (vibrant but not neon)
- **Lightness:** 50-60% (ensures good contrast with white text)
- **Accessibility:** All colors tested for WCAG AA contrast (4.5:1 minimum)

### 8.2 Loading States

#### Progressive Enhancement
```
1. Initial State: Gray circle + spinner
   ↓
2. Cache Check: Instant display if cached
   ↓
3. Network Download: Show initials during download
   ↓
4. Success: Fade to downloaded image
   ↓
5. Failure: Keep initials (don't flicker)
```

#### Animation
- Fade transition: 0.2s ease-in-out
- No jarring flashes or layout shifts
- Skeleton loading for profile screens (optional enhancement)

---

## 9. Open Questions

### Q1: Should avatar colors sync across devices?
**Options:**
- A) Yes - Sync via Firestore for consistency (adds network overhead)
- B) No - Generate per-device (simpler, no sync complexity)

**Recommendation:** **Option A** - Users expect consistency across their devices

### Q2: How to handle profile image updates?
**Scenario:** User changes Google profile picture

**Options:**
- A) Detect URL change and re-download (requires tracking previous URL)
- B) Cache expiration time (e.g., 7 days, then re-download)
- C) Manual refresh button in profile settings

**Recommendation:** **Option A + B** - Detect URL changes and use 7-day TTL as fallback

### Q3: Should we cache images for ALL users or only recent contacts?
**Options:**
- A) Cache all users (could fill 100MB quickly with large contact list)
- B) Cache only recent conversations (last 50 participants)
- C) Adaptive caching (based on interaction frequency)

**Recommendation:** **Option C** - Cache users from active conversations + manual profile views

### Q4: What happens when display name changes?
**Scenario:** User changes name from "John Doe" to "Jonathan Doe"

**Actions:**
- Recompute initials: "JD" → "JD" (same)
- Recompute or keep color?
  - **Option A:** Keep existing color (user recognition)
  - **Option B:** Recompute color (could change)

**Recommendation:** **Option A** - Once assigned, avatar color never changes (even if name changes)

---

## 10. Success Metrics

### User Experience Metrics
- **Initials Display Rate:** 100% of users without Google photos show two-letter initials
- **Color Consistency:** 100% of users see same color across app sessions
- **Cache Hit Rate:** >80% of profile image loads served from cache (after warm-up)

### Performance Metrics
- **Image Load Time:** <100ms for cached images (vs ~500-1000ms for network)
- **Cache Storage:** <50MB average per user (under 100MB limit)
- **Network Savings:** 70-80% reduction in profile image download bandwidth

### Technical Metrics
- **Cache Eviction Frequency:** <5% of cached images evicted per day
- **Sync Conflicts:** <1% conflict rate on avatar color sync
- **Database Query Time:** <10ms for avatar metadata lookups

---

## 11. Implementation Phases

### Phase 1: Fix Notification Profile Pictures (1-2 hours)
1. Update NotificationBannerManager.handleNewMessage() to look up User
2. Pass profileImageUrl to BannerData constructor
3. Test notification banners show profile pictures
4. Test fallback to initials when User not found

### Phase 2: Two-Letter Initials (2-3 hours)
1. Update initials generation logic in ProfileImageView
2. Add unit tests for all name formats
3. Manual testing across all views

### Phase 3: Persistent Avatar Colors (3-4 hours)
1. Add avatarColorHex and cachedInitials to LocalUser model
2. Update UserRepository with new methods
3. Implement color generation and storage logic
4. Update ProfileImageView to use stored color
5. Add Firestore sync for avatar color
6. Migration script for existing users

### Phase 4: Image Caching (4-5 hours)
1. Create ImageCacheService actor
2. Implement file-based cache storage
3. Add LRU eviction logic
4. Update ProfileImageView to check cache first
5. Add cache metadata to LocalUser
6. Implement cache pruning on app launch
7. Add cache statistics logging

### Phase 5: Testing & Polish (2-3 hours)
1. Unit tests for ImageCacheService
2. Integration tests for cache → view flow
3. Performance testing with 100+ cached images
4. Memory leak testing
5. Offline scenario testing
6. Documentation updates

**Total Estimated Time:** 12-17 hours

---

## 12. Testing Strategy

### Unit Tests

#### Initials Generation
```swift
// ProfileImageViewTests.swift
func testInitialsGeneration() {
    XCTAssertEqual(generateInitials("John Doe"), "JD")
    XCTAssertEqual(generateInitials("Alice"), "AL")
    XCTAssertEqual(generateInitials("Bob Smith Jr."), "BS")
    XCTAssertEqual(generateInitials("J"), "JJ")
    XCTAssertEqual(generateInitials(""), "??")
}
```

#### Color Persistence
```swift
// UserRepositoryTests.swift
func testAvatarColorPersistence() async throws {
    let userId = "user123"
    let colorHex = "#007AFF"
    
    try await repository.updateAvatarCache(
        userId: userId,
        initials: "JD",
        colorHex: colorHex
    )
    
    let user = try await repository.getUser(userId: userId)
    XCTAssertEqual(user?.avatarColorHex, colorHex)
}
```

#### Image Caching
```swift
// ImageCacheServiceTests.swift
func testImageCaching() async throws {
    let imageData = createTestImageData()
    let url = "https://example.com/image.jpg"
    
    // Cache image
    try await cache.cacheImage(imageData, for: url)
    
    // Verify cached
    XCTAssertTrue(await cache.isCached(url: url))
    
    // Retrieve cached
    let cached = await cache.getCachedImage(for: url)
    XCTAssertEqual(cached, imageData)
}

func testLRUEviction() async throws {
    // Fill cache to 100MB
    // Add one more image (should evict oldest)
    // Verify oldest is gone, newest remains
}
```

### Integration Tests

#### End-to-End Flow
```swift
// ProfileFlowTests.swift
func testProfileImageCacheFlow() async throws {
    // 1. Load profile (should download + cache)
    // 2. Navigate away
    // 3. Load profile again (should use cache)
    // 4. Verify no network request made
}
```

### Manual Testing Scenarios

#### Checklist
- [ ] Single-word names show two letters ("Alice" → "AL")
- [ ] Multi-word names show first letters ("John Doe" → "JD")
- [ ] Empty names show "??"
- [ ] Avatar colors remain same after app restart
- [ ] Different users have different colors
- [ ] Images load from cache on second view (instant)
- [ ] Cache works offline
- [ ] New profile pictures download when URL changes
- [ ] Cache eviction works when limit reached
- [ ] Memory usage stays under 100MB

---

## 13. Documentation Requirements

### Code Documentation
- Inline comments for initials generation algorithm
- Doc comments for ImageCacheService public methods
- README update with caching architecture
- Migration guide for avatarColorHex field

### Developer Documentation
- Architecture decision record (ADR) for caching strategy
- Performance benchmarks document
- Cache debugging guide

### User-Facing Documentation
- No user-facing changes (all internal improvements)
- Future: Settings screen for cache management

---

## 14. Risks & Mitigations

### Risk 1: Cache Storage Bloat
**Risk:** Users with large contact lists fill 100MB cache quickly  
**Likelihood:** Medium  
**Impact:** High (storage issues, slow performance)  
**Mitigation:**
- Implement LRU eviction strictly
- Monitor cache size with analytics
- Set aggressive eviction threshold (80MB)

### Risk 2: Color Sync Conflicts
**Risk:** Avatar color different on different devices  
**Likelihood:** Low  
**Impact:** Medium (minor UX inconsistency)  
**Mitigation:**
- First-write-wins strategy for color assignment
- Sync color to Firestore immediately after generation
- Conflict resolver keeps older color

### Risk 3: Image URL Changes Not Detected
**Risk:** User updates Google photo but cache shows old image  
**Likelihood:** Medium  
**Impact:** Medium (stale profile pictures)  
**Mitigation:**
- Track previous URL in LocalUser
- Re-download if URL changes
- 7-day TTL as fallback refresh

### Risk 4: SwiftData Migration Issues
**Risk:** Adding new fields causes migration errors  
**Likelihood:** Low  
**Impact:** High (app crashes)  
**Mitigation:**
- Use optional fields for new properties
- Test migration on simulator with existing database
- Implement rollback strategy

---

## 15. Future Enhancements (Post-MVP)

### Phase 2 Improvements
1. **Gradient Avatars:** Use two-color gradients instead of solid colors
2. **Profile Picture Upload:** Allow custom image uploads (not just Google)
3. **Avatar Animations:** Subtle bounce/scale animations on tap
4. **Settings Screen:** Manual cache clearing, cache size display
5. **Batch Prefetching:** Preload images for all conversation participants

### Advanced Features
1. **Avatar Border Colors:** Indicate user status (online=green, away=yellow)
2. **Emoji Avatars:** Let users pick emoji as avatar
3. **Avatar History:** Show previous profile pictures
4. **High-Res Mode:** Download 2x resolution for retina displays
5. **WebP Support:** Use WebP for smaller file sizes

---

## 16. Appendix

### A. Color Palette Details

| Color Name | Hex Code | RGB | Use Case |
|------------|----------|-----|----------|
| Blue | #007AFF | (0, 122, 255) | Primary color, most common |
| Green | #34C759 | (52, 199, 89) | Positive associations |
| Orange | #FF9500 | (255, 149, 0) | Warm, friendly |
| Purple | #AF52DE | (175, 82, 222) | Creative, unique |
| Pink | #FF2D55 | (255, 45, 85) | Attention-grabbing |
| Red | #FF3B30 | (255, 59, 48) | Bold, assertive |
| Indigo | #5856D6 | (88, 86, 214) | Professional |
| Teal | #30B0C7 | (48, 176, 199) | Calm, modern |

### B. File Size Estimates

| Component | Estimated Size |
|-----------|----------------|
| Average cached image | 30-50KB |
| Metadata JSON | <1KB |
| Code additions | ~500 lines |
| Database overhead | ~10KB per user |

### C. Performance Benchmarks (Expected)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Image load time (cold) | 800ms | 800ms | 0% (same) |
| Image load time (warm) | 800ms | 80ms | 90% faster |
| Network requests per session | 50 | 10 | 80% reduction |
| Storage used | 0MB | 30-50MB | Acceptable |

---

## 17. Approval & Sign-off

### Stakeholders
- [ ] Product Owner
- [ ] Engineering Lead
- [ ] Designer
- [ ] QA Lead

### Decision Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-26 | Use two-letter initials | Better user recognition |
| 2025-10-26 | Store color in database | Consistency across sessions |
| 2025-10-26 | 100MB cache limit | Balance performance vs storage |
| 2025-10-26 | Sync color to Firestore | Cross-device consistency |

---

**Status:** ✅ Ready for Implementation  
**Created:** October 26, 2025  
**Last Updated:** October 26, 2025  
**Version:** 1.0

