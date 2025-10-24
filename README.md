# Nexus - AI-Powered Team Messaging App

A real-time messaging app for remote professional teams with built-in AI features.

## Tech Stack
- **iOS:** Swift + SwiftUI
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM)
- **Local Storage:** SwiftData

## Setup Instructions

### Prerequisites
- Xcode 15+
- iOS 17+ deployment target
- Firebase account
- Apple Developer account (for push notifications)

### Installation

1. Clone the repository
```bash
git clone 
cd Nexus
```

2. Open `Nexus.xcodeproj` in Xcode

3. Add `GoogleService-Info.plist`:
   - Download from Firebase Console
   - Drag into Xcode project root
   - Ensure "Copy items if needed" is checked

4. Configure signing:
   - Select project → Target → Signing & Capabilities
   - Select your development team

5. Run the app:
   - Select a simulator or connected device
   - Press Cmd+R

### Firebase Setup

The project requires Firebase services:
- Authentication (Email/Password)
- Cloud Firestore
- Cloud Messaging (FCM)
- Cloud Functions (for notifications)

Firestore security rules are in `firebase/firestore.rules`

### Project Structure
```
Nexus/
├── Models/          # Data models
├── ViewModels/      # MVVM ViewModels
├── Views/           # SwiftUI Views
├── Services/        # Firebase & business logic
├── Utilities/       # Helpers & extensions
└── Resources/       # Assets & config files
```

## Features (MVP)

- [x] One-on-one chat
- [x] Group chat
- [x] Real-time message delivery
- [x] Offline support with sync
- [x] Read receipts
- [x] Typing indicators
- [x] **Robust online/offline presence system**
- [x] Push notifications

## Architecture Highlights

### Robust Presence System

The app implements a production-ready presence tracking system using Firebase Realtime Database (RTDB) for reliable online/offline status.

**Key Features:**
- **Server-Side Disconnect Detection** - Uses RTDB's `onDisconnect()` callback to automatically set users offline when connection drops, even if the app crashes or is force-quit
- **Heartbeat Mechanism** - Sends heartbeat every 30 seconds to keep presence fresh and detect stale connections (>60s = offline)
- **Offline Queue** - Queues presence updates when offline and auto-flushes when network reconnects using Swift Actor for thread-safe operations
- **iOS Background Task Integration** - Ensures offline status updates complete before iOS suspends the app
- **Hybrid Sync** - RTDB for real-time updates + Firestore for persistence and queries

**Architecture:**
```
RTDB (presence/{userId})
├── Real-time presence updates
├── Connection monitoring (.info/connected)
├── onDisconnect() callbacks
└── Heartbeat timestamps

Firestore (users/{userId})
└── Persistent isOnline field for queries
```

**Implementation:**
- `RealtimePresenceService` - Singleton service managing all presence operations
- `PresenceQueue` Actor - Thread-safe offline queue with deduplication
- App lifecycle integration in `NexusAIApp.swift`
- Auth state listener integration in `AuthViewModel`

See `/tasks/prd-robust-presence-system.md` for complete documentation.

## Roadmap

### Post-MVP: AI Features
- Thread summarization
- Action item extraction
- Smart search
- Priority message detection
- Decision tracking
- Proactive AI assistant

## License

MIT

