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
- [x] Online/offline presence
- [x] Push notifications

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

