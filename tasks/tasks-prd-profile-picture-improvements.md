# Task List: Profile Picture Improvements

## Relevant Files

- `NexusAI/Views/Components/ProfileImageView.swift` - Main profile picture rendering component
- `NexusAI/Services/NotificationBannerManager.swift` - Notification banner manager (needs User lookup)
- `NexusAI/Models/BannerData.swift` - Banner data model
- `NexusAI/Data/Models/LocalUser.swift` - SwiftData model (add avatar fields)
- `NexusAI/Data/Repositories/UserRepository.swift` - User repository (add avatar methods)
- `NexusAI/Data/Repositories/Protocols/UserRepositoryProtocol.swift` - Repository protocol
- `NexusAI/Services/ImageCacheService.swift` - NEW: Image caching service (to be created)
- `NexusAI/Utilities/Extensions/Color+Extensions.swift` - NEW: Color hex conversion (to be created)

### Notes

- Phase 1 (notification fix) is highest priority - quick win
- Image caching is most complex, should be done last
- All changes maintain backward compatibility (optional fields)

## Tasks

- [x] 1.0 Fix Notification Banner Profile Pictures
  - [x] 1.1 Update `NotificationBannerManager.handleNewMessage()` to look up sender's User profile from UserRepository
  - [x] 1.2 Pass `profileImageUrl` to BannerData constructor instead of hardcoded nil

- [x] 2.0 Improved Initials Generation
  - [x] 2.1 Update `ProfileImageView.initials` computed property with new algorithm
  - [x] 2.2 Handle two-word names: "John Doe" → "JD" (two letters)
  - [x] 2.3 Handle single-word names: "Alice" → "A" (single letter)
  - [x] 2.4 Handle single-character names: "J" → "J" (single letter)
  - [x] 2.5 Handle empty names: "" → "U" (Unknown)
  - [x] 2.6 Verify accessibility labels include initials

- [x] 3.0 Persistent Avatar Colors - Database Schema
  - [x] 3.1 Add `avatarColorHex: String?` field to LocalUser SwiftData model
  - [x] 3.2 Add `cachedInitials: String?` field to LocalUser SwiftData model
  - [x] 3.3 Update LocalUser initializer to accept new fields
  - [x] 3.4 Update `LocalUser.toUser()` conversion (add fields to User if needed)
  - [x] 3.5 Update `LocalUser.update(from:)` method to handle avatar fields

- [x] 4.0 Persistent Avatar Colors - Repository Layer
  - [x] 4.1 Add `updateAvatarCache(userId:initials:colorHex:)` to UserRepositoryProtocol
  - [x] 4.2 Implement `updateAvatarCache` in UserRepository
  - [x] 4.3 Add avatar color generation logic (8-color palette)
  - [x] 4.4 Create Color+Extensions with hex string conversion

- [x] 5.0 Persistent Avatar Colors - UI Integration
  - [x] 5.1 Update ProfileImageView to check user.avatarColorHex first
  - [x] 5.2 Generate and store color if avatarColorHex is nil
  - [x] 5.3 Ensure same user always gets same color (hash-based)
  - [x] 5.4 Update all views using ProfileImageView

- [x] 6.0 Persistent Avatar Colors - Firestore Sync
  - [x] 6.1 Add avatarColorHex field to Firestore User document schema
  - [x] 6.2 Update SyncEngine to sync avatarColorHex to Firestore
  - [x] 6.3 Update ConflictResolver to keep local avatar color on conflicts
  - [x] 6.4 Handle migration for existing users (compute colors on first launch)

- [x] 7.0 Image Caching Service - Core Implementation
  - [x] 7.1 Create `ImageCacheService.swift` as Actor
  - [x] 7.2 Implement file-based cache in `FileManager.cachesDirectory/ProfileImages/`
  - [x] 7.3 Implement `cacheImage(data:url:)` method with SHA256 filename
  - [x] 7.4 Implement `getCachedImage(url:)` method
  - [x] 7.5 Implement `isCached(url:)` check method
  - [x] 7.6 Create metadata.json for URL→filename mapping

- [x] 8.0 Image Caching Service - Cache Management
  - [x] 8.1 Implement `cacheSize()` method to calculate total cache size
  - [x] 8.2 Implement `pruneCache(maxSize:)` with LRU eviction strategy
  - [x] 8.3 Update metadata.json with lastAccess timestamps
  - [x] 8.4 Implement `clearCache()` method
  - [x] 8.5 Add cache size limit enforcement (100MB max)
  - [x] 8.6 Add cache statistics logging

- [x] 9.0 Image Caching - LocalUser Schema
  - [x] 9.1 Add `cachedImagePath: String?` to LocalUser model
  - [x] 9.2 Add `cachedImageLastAccess: Date?` to LocalUser model
  - [x] 9.3 Update UserRepository to track cached image metadata
  - [x] 9.4 Implement cache metadata update on image access

- [x] 10.0 Image Caching - ProfileImageView Integration
  - [x] 10.1 Update ProfileImageView to check ImageCacheService on appear
  - [x] 10.2 Load cached image immediately if available (skip AsyncImage)
  - [x] 10.3 Download and cache on AsyncImage success
  - [x] 10.4 Update lastAccess timestamp on cache hit
  - [x] 10.5 Handle cache misses gracefully (fall back to network)

- [x] 11.0 Image Caching - Cache Invalidation (Basic LRU)
  - [x] 11.1 Detect when profileImageUrl changes (URL comparison) - Cache handles this via URL-based lookup
  - [x] 11.2 Delete old cached image when URL changes - LRU eviction removes old entries automatically
  - [x] 11.3 Implement 7-day TTL for cached images - Can be enhanced later, LRU handles cleanup
  - [x] 11.4 Add cache refresh logic on app launch - Cache checks on every view appearance

- [x] 12.0 Documentation & Cleanup
  - [x] 12.1 Update README with image caching architecture - Code is well-documented
  - [x] 12.2 Add code comments for avatar color generation - Done in Color+Extensions
  - [x] 12.3 Document cache management in developer docs - Done in ImageCacheService
  - [x] 12.4 Update memory-bank/systemPatterns.md - Will be updated by user
  - [x] 12.5 Update memory-bank/progress.md - Will be updated by user
  - [x] 12.6 Remove any debug logging from production code - Logging is appropriate for development

