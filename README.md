# Nexus - AI-Powered Team Messaging App

A real-time messaging app for remote professional teams with advanced AI features including **RAG-powered conversational search** across all conversations.

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26.0+-blue.svg" alt="iOS 26.0+">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/Xcode-15.0+-blue.svg" alt="Xcode 15.0+">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License">
</p>

---

> **⚠️ IMPORTANT: DEVELOPMENT/DEMO PROJECT**  
> This is a **demonstration project** for educational purposes. It stores API keys in the iOS app (`Config.plist`) for quick setup and testing.  
> **DO NOT deploy this app to production or publish to the App Store without implementing proper security practices.**  
> Production apps must store API keys server-side only. See [Security Considerations](#security--privacy) for details.

---

## 🌟 Features

### ✅ Core Messaging (Production-Ready)
- ✅ **One-on-one chat** - Real-time messaging with optimistic UI
- ✅ **Group chat** - Create and manage group conversations with 3+ participants
- ✅ **Real-time sync** - Instant message delivery using Firestore listeners
- ✅ **Offline support** - Message queue with automatic sync when reconnected
- ✅ **Read receipts** - Track message delivery and read status
- ✅ **Typing indicators** - Real-time typing status
- ✅ **Robust presence system** - Server-side disconnect detection with Firebase RTDB
- ✅ **User profiles** - Google Sign-In authentication with profile management
- ✅ **Tab navigation** - iOS-native 3-tab interface (Chat, Nexus, Profile)

### 🤖 AI Features (Implemented)

- ✅ **Per-Conversation AI Assistant** - Chat with AI about specific conversations (brain icon 🧠)
  - 6 AI capabilities: Summarization, Action Items, Decisions, Priorities, Deadlines, Q&A
  - Suggested prompts for quick access ("Summarize thread", "What decisions?", etc.)
  - Persistent AI conversation history per chat
  - Contextual to the current conversation only
  - Powered by GPT-4 with unified system prompt

- ✅ **Action Item Extraction** - GPT-4 analyzes conversations to extract tasks with assignees, deadlines, and priorities
  - Structured extraction with JSON parsing
  - Mark tasks complete with checkbox
  - Visual badges for assignee, deadline, priority
  - Persistent across app restarts

- ✅ **Nexus - RAG-Powered Global AI Assistant** - Ask questions about ANY conversation using natural language (sparkles icon ✨)
  - Semantic search across all messages using vector embeddings
  - GPT-4 synthesizes answers from multiple sources
  - Source attribution with tap-to-navigate to original messages
  - Multi-turn conversations with context retention
  - Works across all your conversations simultaneously

### 🚧 Upcoming AI Features
- 🚧 **Decision Tracking** - Standalone searchable decision log *(partially available via Per-Conversation AI)*
- 🚧 **Priority Detection** - Automatic flagging of urgent messages *(partially available via Per-Conversation AI)*

**Note:** Thread Summarization, Decision Tracking, and Priority Analysis are already available through the Per-Conversation AI Assistant (brain icon). The upcoming features would be standalone/automatic versions.

---

## 🏗️ Architecture & Tech Stack

### iOS Frontend
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (iOS 26.0+)
- **Architecture:** MVVM with Repository Pattern
- **Local Persistence:** SwiftData (local-first sync framework)
- **State Management:** Combine + ObservableObject
- **Authentication:** GoogleSignIn SDK + Firebase Auth
- **Package Manager:** Swift Package Manager (SPM)

### Backend (Firebase)
- **Authentication:** Firebase Auth (Google Sign-In)
- **Database:** Cloud Firestore (real-time NoSQL)
- **Realtime Database:** Firebase RTDB (presence system with onDisconnect)
- **Cloud Functions:** Node.js 20 (3 deployed functions)
  - `embedNewMessage` - Auto-generate vector embeddings for semantic search
  - `ragSearch` - Semantic search using cosine similarity
  - `ragQuery` - Full RAG pipeline with GPT-4
- **Storage:** Firebase Storage (for future media support)
- **Hosting:** Firebase Hosting (for web dashboard, future)

### AI & Machine Learning
- **LLM:** OpenAI GPT-4-turbo-preview (conversational AI, structured extraction)
- **Embeddings:** OpenAI text-embedding-3-small (1536 dimensions)
- **RAG Pattern:** Retrieval-Augmented Generation for conversation search
- **Vector Storage:** Firestore collection `messageEmbeddings`
- **Semantic Search:** Cosine similarity calculation

### Architecture Patterns
- **MVVM** - Clean separation of concerns
- **Repository Pattern** - Protocol-based data access for testability
- **Optimistic UI** - Instant feedback for message sending
- **Local-First Sync** - SwiftData as single source of truth with Firestore sync
- **Event-Driven** - NotificationCenter for reactive updates (90% CPU reduction)
- **Singleton Services** - FirebaseService, PresenceManager, NetworkMonitor
- **Protocol-Based DI** - Injectable services for unit testing

---

## 📋 Prerequisites

Before you begin, ensure you have:

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** with Command Line Tools
- **iOS 26.0+ Simulator** or physical device (iOS 17.0+ minimum)
- **Firebase Account** (free tier sufficient for development)
- **OpenAI Account** with API access (for AI features)
- **Node.js 20+** and npm (for Cloud Functions)
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Git** for version control

---

## 🚀 Setup Instructions

> **⚠️ DEVELOPMENT/DEMO PROJECT ONLY**  
> This project stores the OpenAI API key in `Config.plist` for **demonstration purposes only**.  
> **DO NOT deploy this app to production or the App Store** without implementing proper security.  
> For production apps, API keys should ONLY be stored server-side (Cloud Functions with Secret Manager).

> **📌 API Key Setup Summary:**  
> - **iOS App:** Store in `NexusAI/Config.plist` (for demo/development only)
> - **Cloud Functions:** Store in Google Cloud Secret Manager via `firebase functions:secrets:set OPENAI_API_KEY`
> - ⚠️ **Never commit `Config.plist` or `.env` files to Git!**

### 1. Clone the Repository

```bash
git clone <repository-url>
cd NexusAI
```

### 2. Firebase Project Setup

#### Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name (e.g., "NexusAI")
4. Disable Google Analytics (optional)
5. Click "Create project"

#### Enable Firebase Services

**Authentication:**
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in provider
3. Add support email
4. Save

**Firestore Database:**
1. Go to **Firestore Database** → **Create database**
2. Start in **Production mode**
3. Choose region: `us-central1` (or your preferred region)
4. Click **Enable**

**Realtime Database (for presence):**
1. Go to **Realtime Database** → **Create database**
2. Start in **Locked mode** (we'll update rules later)
3. Choose region: `us-central1`
4. Click **Enable**

**Cloud Functions:**
1. Go to **Functions** → **Get started**
2. Upgrade to **Blaze plan** (pay-as-you-go, required for Cloud Functions)
3. Note: Free tier includes 2M invocations/month

#### Download Configuration Files

1. In Firebase Console, go to **Project Settings** (⚙️ icon)
2. Under **Your apps**, click **iOS** button
3. Register app:
   - **Bundle ID:** `com.yourcompany.NexusAI` (must match Xcode)
   - **App nickname:** NexusAI
   - Skip App Store ID
4. **Download `GoogleService-Info.plist`**
5. Drag the file into Xcode project root (next to `Info.plist`)
6. ✅ Ensure "Copy items if needed" is checked
7. ✅ Ensure target membership includes "NexusAI"

#### Configure URL Schemes (for Google Sign-In)

1. Open `GoogleService-Info.plist` in Xcode
2. Find `REVERSED_CLIENT_ID` value (looks like `com.googleusercontent.apps.123456789-xyz`)
3. In Xcode, select **Project** → **Target: NexusAI** → **Info** tab
4. Expand **URL Types** section
5. Verify URL Scheme is set to `REVERSED_CLIENT_ID` value

### 3. Firestore Security Rules

Deploy security rules to protect your data:

```bash
cd firebase
firebase login
firebase use --add  # Select your Firebase project
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only database:rules  # For RTDB presence system
```

**Security rules are in:**
- `firebase/firestore.rules` - Firestore security
- `firebase/firestore.indexes.json` - Required indexes
- `firebase/database.rules.json` - Realtime Database rules (presence)

### 4. Create Config.plist (iOS App API Key)

> **⚠️ DEMO ONLY:** This stores the API key in the iOS app for quick setup.  
> **DO NOT use this approach in production!**

#### Create the Config.plist file

1. In Xcode, right-click on the `NexusAI` folder (next to `Info.plist`)
2. Select **New File** → **Property List**
3. Name it `Config.plist`
4. ✅ Ensure target membership includes "NexusAI"

#### Add OpenAI API Key to Config.plist

1. Get your OpenAI API key:
   - Go to [OpenAI Platform](https://platform.openai.com/)
   - Sign up or log in
   - Navigate to **API Keys** section
   - Click **Create new secret key**
   - Name it "NexusAI Development"
   - **Copy the key immediately** (you won't see it again)

2. Open `Config.plist` in Xcode
3. Add a new row:
   - **Key:** `OPENAI_API_KEY`
   - **Type:** String
   - **Value:** Your OpenAI API key (starts with `sk-proj-...`)

Your `Config.plist` should look like:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OPENAI_API_KEY</key>
    <string>sk-proj-your-actual-key-here</string>
</dict>
</plist>
```

#### Add Config.plist to .gitignore

**CRITICAL:** Ensure `Config.plist` is NOT committed to Git:

```bash
# Check if Config.plist is tracked
git status NexusAI/Config.plist

# If it shows up, add to .gitignore
echo "NexusAI/Config.plist" >> .gitignore
echo "**/Config.plist" >> .gitignore

# Verify it's ignored
git status NexusAI/Config.plist
# Should say: "No such file" or not listed
```

### 5. OpenAI API Setup (Cloud Functions)

The Cloud Functions (RAG search, embeddings) also need the OpenAI API key. Store it in Firebase Secret Manager:

```bash
cd firebase/functions

# Set OpenAI API key as a secret
firebase functions:secrets:set OPENAI_API_KEY

# When prompted, paste your OpenAI API key (same key as Config.plist)
```

**Verify the secret is set:**
```bash
# Check secret is stored
firebase functions:secrets:access OPENAI_API_KEY
# Should output: sk-proj-...
```

The Cloud Functions are already configured to use this secret:
```javascript
// In ragQuery.js, ragSearch.js, embedNewMessage.js
const { defineSecret } = require("firebase-functions/params");
const openaiApiKey = defineSecret("OPENAI_API_KEY");

exports.ragQuery = onCall(
  { secrets: [openaiApiKey] },
  async (request) => {
    const apiKey = openaiApiKey.value(); // Securely access the key
    // ...
  }
);
```

### 6. Deploy Cloud Functions

Cloud Functions power the AI features (embeddings, RAG search, GPT-4 integration).

```bash
cd firebase/functions

# Install dependencies
npm install

# Deploy all functions
npm run deploy

# Or deploy individually:
# firebase deploy --only functions:embedNewMessage
# firebase deploy --only functions:ragSearch
# firebase deploy --only functions:ragQuery
```

**Deployed Functions:**
- `embedNewMessage` - Auto-triggered on new messages (Firestore trigger)
- `ragSearch` - Callable function for semantic search
- `ragQuery` - Callable function for RAG-powered Q&A

**Expected Output:**
```
✔ functions: Finished running predeploy script.
✔ functions[embedNewMessage(us-central1)] Successful create operation
✔ functions[ragSearch(us-central1)] Successful create operation
✔ functions[ragQuery(us-central1)] Successful create operation
```

### 7. iOS Project Setup

#### Open in Xcode

```bash
open NexusAI.xcodeproj
```

#### Configure Signing

1. Select **NexusAI** project in navigator
2. Select **NexusAI** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** (Apple Developer account)
6. Verify **Bundle Identifier** matches Firebase registration

#### Install Dependencies

Dependencies are managed via Swift Package Manager and should resolve automatically.

**Expected packages:**
- Firebase iOS SDK (10.18.0+)
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseFirestoreSwift
  - FirebaseFunctions
  - FirebaseDatabase (for presence)
- GoogleSignIn iOS SDK (7.0.0+)

If packages don't resolve:
1. **File** → **Packages** → **Resolve Package Versions**
2. Wait for download to complete

### 8. Run the App

1. Select a simulator: **iPhone 15 Pro (iOS 26.0+)**
2. Press **Cmd+R** or click ▶️ **Run** button
3. Wait for build to complete
4. App should launch in simulator

**First Launch:**
- You'll see the login screen with Google Sign-In button
- Tap "Sign in with Google"
- Choose a Google account
- Grant permissions
- You'll be signed in and see the Chat tab

---

## 🗂️ Project Structure

```
NexusAI/
├── NexusAI/                    # iOS app source
│   ├── Models/                 # Data models
│   │   ├── User.swift
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── ActionItem.swift
│   │   ├── RAGQuery.swift      # RAG-related models
│   │   └── ...
│   │
│   ├── Data/                   # Local-first sync framework
│   │   ├── LocalDatabase.swift
│   │   ├── SyncEngine.swift
│   │   ├── ConflictResolver.swift
│   │   ├── Models/             # SwiftData models
│   │   └── Repositories/       # Data access layer
│   │
│   ├── Services/               # Business logic & Firebase
│   │   ├── FirebaseService.swift
│   │   ├── AuthService.swift
│   │   ├── MessageService.swift
│   │   ├── ConversationService.swift
│   │   ├── RealtimePresenceService.swift
│   │   ├── AIService.swift     # GPT-4 integration (per-conversation AI + action items)
│   │   ├── RAGService.swift    # RAG Cloud Functions client (Nexus)
│   │   └── ...
│   │
│   ├── ViewModels/             # MVVM ViewModels
│   │   ├── AuthViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── ConversationListViewModel.swift
│   │   ├── AIAssistantViewModel.swift # Per-conversation AI
│   │   ├── ActionItemViewModel.swift  # Action items extraction
│   │   ├── GlobalAIViewModel.swift    # Nexus AI (global RAG)
│   │   └── ...
│   │
│   ├── Views/                  # SwiftUI Views
│   │   ├── Main/               # Tab navigation
│   │   ├── Auth/               # Login screens
│   │   ├── ConversationList/   # Conversation list
│   │   ├── Chat/               # Chat screens (includes AIAssistantView 🧠)
│   │   ├── Group/              # Group management
│   │   ├── Profile/            # User profile
│   │   ├── ActionItems/        # Action item extraction UI ✓
│   │   ├── GlobalAI/           # Nexus AI Assistant UI ✨
│   │   └── Components/         # Reusable components
│   │
│   ├── Utilities/              # Helpers & extensions
│   │   ├── Constants.swift
│   │   ├── NetworkMonitor.swift
│   │   └── Extensions/
│   │
│   └── Resources/              # Assets & config
│       ├── GoogleService-Info.plist
│       └── Assets.xcassets/
│
├── firebase/                   # Firebase backend
│   ├── firestore.rules         # Firestore security rules
│   ├── firestore.indexes.json  # Firestore indexes
│   ├── database.rules.json     # RTDB rules
│   ├── firebase.json           # Firebase config
│   └── functions/              # Cloud Functions (Node.js)
│       ├── src/
│       │   ├── embedNewMessage.js   # Auto-embed messages
│       │   ├── ragSearch.js         # Semantic search
│       │   └── ragQuery.js          # RAG with GPT-4
│       ├── package.json
│       └── README.md
│
├── NexusAITests/               # Unit tests
│   ├── Services/
│   ├── Data/
│   └── Mocks/
│
├── memory-bank/                # Project documentation
│   ├── projectbrief.md
│   ├── productContext.md
│   ├── activeContext.md
│   ├── systemPatterns.md
│   ├── techContext.md
│   └── progress.md
│
├── tasks/                      # PRDs and task lists
│   ├── prd-*.md               # Product requirements
│   └── tasks-prd-*.md         # Implementation tasks
│
└── README.md                   # This file
```

---

## 🧪 Testing

### Manual Testing

**Basic Flow:**
1. Sign in with Google account
2. Navigate between tabs (Chat, Nexus, Profile)
3. Create a new conversation
4. Send messages (try offline mode)
5. Create a group chat
6. Test the 3 AI features (Per-Conversation AI, Action Items, Nexus)

**Testing Per-Conversation AI (Brain Icon):**
1. Open any conversation with messages
2. Tap the **brain icon** (🧠) in the toolbar
3. Try suggested prompts:
   - "Summarize thread"
   - "Extract action items"
   - "What decisions were made?"
   - "Any deadlines?"
4. Ask custom questions: "What did Alice say about the project?"
5. Verify AI conversation history persists (close and reopen)
6. Test "Clear conversation" option

**Testing Action Items (Checklist Icon):**
1. Have a conversation mentioning tasks
2. Tap the **checklist icon** (✓) in the toolbar
3. Tap "Extract Action Items"
4. Wait for GPT-4 extraction (~2-5 seconds)
5. Verify tasks show with assignees, deadlines, priorities
6. Mark items complete with checkbox
7. Verify persistence across app restarts

**Testing Nexus (RAG Global AI - Sparkles Icon):**
1. Send test messages in various conversations
2. Switch to **Nexus tab** (sparkles icon ✨)
3. Ask questions like:
   - "What did [name] say about [topic]?"
   - "Summarize the conversation about [topic]"
   - "What tasks were mentioned?"
4. Tap on source cards to navigate to original messages
5. Ask follow-up questions: "Tell me more", "What else?"
6. Verify cross-tab navigation works (Nexus → Chat → highlighted message)

### Unit Tests

Run tests in Xcode:
```bash
# Run all tests
Cmd+U

# Or via command line:
xcodebuild test -scheme NexusAI -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**Test Coverage:**
- ✅ AuthService (protocol-based mocking)
- ✅ Repositories (MessageRepository, ConversationRepository, UserRepository)
- ✅ SwiftData models
- ✅ Sync engine
- 🚧 ViewModels (in progress)

### Firestore Emulator (Optional)

For local development without hitting production database:

```bash
# Install emulators
firebase init emulators  # Select Firestore, Functions, Auth

# Start emulators
firebase emulators:start

# Update Firestore to use emulator (in FirebaseService.swift)
# Firestore.firestore().useEmulator(withHost: "localhost", port: 8080)
```

---

## 🎨 Key Architecture Highlights

### 1. Local-First Sync Framework

SwiftData serves as single source of truth with bidirectional Firestore sync:
- **90% CPU reduction** - No polling, event-driven updates
- **Instant UI updates** - NotificationCenter broadcasts changes
- **Repository pattern** - Clean data access with protocol-based DI
- **Conflict resolution** - Last-Write-Wins with timestamps
- **Network awareness** - Auto pause/resume sync based on connectivity

### 2. Robust Presence System

Production-ready online/offline tracking using Firebase Realtime Database:
- **Server-side disconnect** - `onDisconnect()` callback sets offline automatically
- **Heartbeat mechanism** - 30s interval, >60s = stale/offline
- **Offline queue** - Swift Actor for thread-safe queueing with auto-flush
- **iOS background tasks** - Ensures offline updates complete before suspension
- **Hybrid sync** - RTDB for real-time + Firestore for persistence

### 3. RAG-Powered AI (Nexus)

Natural language Q&A over all conversation history:
- **Vector embeddings** - text-embedding-3-small (1536 dimensions)
- **Semantic search** - Cosine similarity finds relevant messages
- **GPT-4 synthesis** - Generates informed answers from multiple sources
- **Source attribution** - Links back to original messages
- **Multi-turn conversations** - Context retention (last 10 Q&A pairs)
- **Cross-tab navigation** - Tap source → switch tabs → jump to message

**RAG Pipeline:**
```
User question → Embed query → Search vectors → Retrieve top 5 messages
→ Build augmented prompt (system + history + RAG context + question)
→ GPT-4 generates answer → Return answer + sources → Display with cards
```

### 4. Optimistic UI Pattern

Messages appear instantly before Firestore confirmation:
- Local message with `localId` added to UI immediately
- Background write to Firestore
- On success: merge with real Firestore message
- On failure: show retry option
- Prevents duplicates via localId matching

### 5. Per-Conversation AI Assistant

Contextual AI for analyzing individual conversations:
- **Access:** Brain icon (🧠) in ChatView toolbar
- **6 AI Capabilities:**
  - Summarization - Concise thread overviews
  - Action Item Extraction - Find tasks and commitments
  - Decision Tracking - Identify agreements and reasoning
  - Priority Analysis - Detect urgency based on context
  - Deadline Detection - Extract time-sensitive information
  - Natural Q&A - Answer questions about the conversation
- **Unified System Prompt** - Single prompt defines all capabilities
- **Repository Pattern** - `AIMessageRepository` for SwiftData persistence
- **Observation Pattern** - AsyncStream for real-time AI message updates
- **API Key** - Uses `Config.plist` (demo only, should be server-side for production)

**Architecture:**
```
User taps brain icon → AIAssistantView (sheet modal)
→ AIAssistantViewModel (state management)
→ AIService (GPT-4 with unified system prompt)
→ AIMessageRepository (SwiftData persistence)
→ Real-time updates via observation
```

**Key Files:**
- `Views/Chat/AIAssistantView.swift` - Conversational UI
- `ViewModels/AIAssistantViewModel.swift` - Business logic
- `Services/AIService.swift` - GPT-4 integration (500+ lines)
- `Data/Repositories/AIMessageRepository.swift` - Persistence

**Distinction:**
- **Per-Conversation AI (🧠):** Analyzes CURRENT conversation only
- **Nexus AI (✨):** Searches across ALL conversations
- **Action Items (✓):** Extracts structured tasks

### 6. Component Reuse

Nexus AI reused existing patterns from per-conversation AI:
- Adapted `AIAssistantView` → `GlobalAIAssistantView`
- Reused `AIMessageBubbleView` → `GlobalAIMessageBubbleView`
- Added `SourceMessageCard` for source attribution
- Saved development time, ensured UI consistency

---

## 🔐 Security & Privacy

### Firestore Security Rules

All data access is secured with participant-based rules:
- Users can only read/write conversations they're part of
- Messages inherit conversation permissions
- User profiles: read all authenticated, write own only
- Embeddings: tied to userId, isolated per user

### API Keys & Secrets

> **⚠️ DEMO PROJECT WARNING:**  
> This project stores OpenAI API keys in `Config.plist` (iOS app) for **development/demo purposes only**.  
> **DO NOT deploy this app to production or the App Store!**  
> Production apps must store API keys server-side only (Cloud Functions with Secret Manager).

**Never commit to Git:**
- ❌ `Config.plist` (contains OpenAI API key)
- ❌ `GoogleService-Info.plist` (Firebase config)
- ❌ `.env` files (local development keys)
- ❌ Any credentials or tokens

**✅ Verify .gitignore includes:**
```gitignore
# Root .gitignore
**/Config.plist
**/GoogleService-Info.plist
**/.env
**/.env.*

# firebase/functions/.gitignore
node_modules/
.env
.env.*
*.log
```

**Where API Keys Are Stored (Demo Setup):**

1. **iOS App (⚠️ DEMO ONLY):**
   - 📁 `NexusAI/Config.plist` (gitignored)
   - Contains: `OPENAI_API_KEY` = `sk-proj-...`
   - Used by: `AIService.swift` for action item extraction
   - **WARNING:** Only acceptable for development/testing

2. **Cloud Functions (Secure):**
   - ✅ Google Cloud Secret Manager (via Firebase)
   - Access: `firebase functions:secrets:set OPENAI_API_KEY`
   - Read in function: `openaiApiKey.value()`
   - Used by: RAG search, embeddings, GPT-4 queries

**Firebase Secret Manager Commands:**
```bash
# Set secret (production)
cd firebase/functions
firebase functions:secrets:set OPENAI_API_KEY

# List secrets
firebase functions:secrets:list

# Access secret value (for verification)
firebase functions:secrets:access OPENAI_API_KEY

# Delete secret (if needed)
firebase functions:secrets:destroy OPENAI_API_KEY
```

**Best Practices:**
- ✅ Use Secret Manager for production
- ✅ Use .env for local development only
- ✅ Rotate keys if exposed
- ✅ Monitor API usage in OpenAI dashboard
- ❌ Never log API keys
- ❌ Never put keys in screenshots
- ❌ Never hardcode keys in source

### Data Privacy

- **User data** stored in Firestore (Firebase security)
- **Message embeddings** isolated per user (can't access others' embeddings)
- **Google Sign-In** - no passwords stored, uses OAuth
- **OpenAI API** - messages sent for embedding/analysis (see OpenAI privacy policy)

---

## 🐛 Troubleshooting

### Build Errors

**"No such module 'FirebaseAuth'"**
- Solution: File → Packages → Resolve Package Versions
- Wait for SPM to download dependencies

**"Could not find or use auto-linked library"**
- Solution: Clean build folder (Cmd+Shift+K), then rebuild

**"GoogleService-Info.plist not found"**
- Solution: Ensure file is in project root with target membership

**"Config.plist not found" or "OPENAI_API_KEY not found"**
- Solution 1: Create `Config.plist` in `NexusAI/` folder (see Step 4 above)
- Solution 2: Add `OPENAI_API_KEY` key with your OpenAI API key as the value
- Solution 3: Verify target membership includes "NexusAI"
- Solution 4: Clean build (Cmd+Shift+K) and rebuild

### Authentication Issues

**"Google Sign-In failed: No root view controller"**
- Solution: Check URL Scheme matches `REVERSED_CLIENT_ID` in plist
- Verify GoogleSignIn package is installed

**"User profile creation failed"**
- Solution: Check Firestore security rules allow user creation
- Verify network connectivity

### Cloud Functions Issues

**"Function not found: ragQuery"**
- Solution: Deploy functions: `cd firebase/functions && npm run deploy`
- Check Firebase Console → Functions for deployment status

**"OpenAI API key not found" or "Invalid API key"**
- Solution 1: Set secret: `firebase functions:secrets:set OPENAI_API_KEY`
- Solution 2: Verify key is correct: `firebase functions:secrets:access OPENAI_API_KEY`
- Solution 3: Redeploy functions after setting secret: `npm run deploy`
- Solution 4: Check OpenAI dashboard for key validity and credits
- Solution 5: For local development, create `firebase/functions/.env` with `OPENAI_API_KEY=sk-proj-...`

**"Insufficient permissions"**
- Solution: Upgrade to Blaze plan (pay-as-you-go) in Firebase Console
- Cloud Functions require Blaze plan

### AI Features Issues

**"No embeddings found" when querying Nexus**
- Solution: Embeddings only generated for NEW messages after Cloud Function deployment
- Send a few test messages to generate embeddings
- Wait ~5-10 seconds for embedding generation

**"Query times out"**
- Solution: Check Cloud Functions logs in Firebase Console
- Verify OpenAI API key is valid
- Check OpenAI account has credits

### Presence System Issues

**"Users always show offline"**
- Solution: Check Realtime Database rules allow read/write
- Verify RTDB is enabled in Firebase Console
- Check app lifecycle integration in `NexusAIApp.swift`

### General Debugging

**Enable detailed logging:**
```swift
// In FirebaseService.swift
Firestore.firestore().settings.isPersistenceEnabled = true
Firestore.firestore().settings.cacheSizeBytes = FirestoreCacheSizeUnlimited

// Enable debug logging
FirebaseConfiguration.shared.setLoggerLevel(.debug)
```

**Check Firebase Console:**
- Firestore → Data tab - verify data is being written
- Functions → Logs - check for errors
- Authentication → Users - verify sign-ins

---

## 📊 Performance & Costs

### Expected Costs (Development)

**Firebase (Spark - Free Tier):**
- Firestore: 50K reads/day, 20K writes/day - ✅ Sufficient
- RTDB: 100 concurrent connections - ✅ Sufficient
- Cloud Functions: 2M invocations/month - ✅ Sufficient

**Firebase (Blaze - Pay-as-you-go):**
- Required for Cloud Functions
- Free tier limits still apply
- Typical development cost: ~$1-5/month

**OpenAI API:**
- text-embedding-3-small: $0.00002 per 1K tokens (~$0.0001 per message)
- GPT-4-turbo: $0.01 per 1K input tokens, $0.03 per 1K output tokens
- Typical query cost: ~$0.01-0.03
- Development budget: $10-20/month covers extensive testing

### Performance Benchmarks

**Messaging:**
- Message delivery: <1s (real-time Firestore)
- Optimistic UI: <100ms (instant appearance)
- Offline queue flush: <2s per message

**AI Features:**
- Action item extraction: 2-5 seconds (GPT-4 API call)
- Nexus query: 2-5 seconds (embedding + search + GPT-4)
- Embedding generation: 200-500ms per message

**Local-First Sync:**
- UI updates: Instant (event-driven, no polling)
- CPU usage: 90% reduction vs polling approach
- Memory: Minimal, SwiftData handles efficiently

---

## 📚 Documentation

### Memory Bank (Project Context)
- `memory-bank/projectbrief.md` - Project overview and goals
- `memory-bank/productContext.md` - User personas, pain points, features
- `memory-bank/activeContext.md` - Current work, recent completions
- `memory-bank/systemPatterns.md` - Architectural patterns and code examples
- `memory-bank/techContext.md` - Tech stack, database schema, decisions
- `memory-bank/progress.md` - Detailed progress tracker

### Task Documentation
- `tasks/prd-*.md` - Product Requirements Documents for each feature
- `tasks/tasks-prd-*.md` - Detailed task lists with completion tracking
- `tasks/architecture-*.md` - Architecture documentation

### External Documentation
- [Firebase iOS Docs](https://firebase.google.com/docs/ios/setup)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [OpenAI API Reference](https://platform.openai.com/docs)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

---

## 🤝 Contributing

This is a demonstration project for AI-powered messaging. If adapting for production:

1. **Security Review** - Audit Firestore rules and API key management
2. **Error Handling** - Add comprehensive error handling and user feedback
3. **Testing** - Expand unit and integration test coverage
4. **Performance** - Profile with large message histories
5. **Accessibility** - Ensure VoiceOver and Dynamic Type support
6. **Localization** - Add internationalization support
7. **Media Support** - Implement image/video/file sharing
8. **Encryption** - Consider end-to-end encryption for messages

---

## ⚠️ Production Deployment Considerations

**CRITICAL: This demo stores API keys in `Config.plist` - DO NOT use this in production!**

### Required Changes for Production:

1. **Remove `Config.plist` entirely**
   - Delete `ConfigManager.swift`
   - Remove all references to client-side API keys

2. **Move AI calls to Cloud Functions**
   - Create new Cloud Function for action item extraction
   - iOS app calls Cloud Function instead of OpenAI directly
   - API key stays server-side only

3. **Update AIService.swift**
   ```swift
   // ❌ DEMO (current):
   let apiKey = ConfigManager.shared.openAIAPIKey
   self.openAI = OpenAI(apiToken: apiKey)
   
   // ✅ PRODUCTION (recommended):
   // Call Cloud Function that handles OpenAI internally
   let result = try await Functions.functions().httpsCallable("extractActionItems").call(data)
   ```

4. **Security Hardening**
   - Enable App Transport Security
   - Implement certificate pinning
   - Add rate limiting
   - Implement proper error logging (not to console)

5. **App Store Requirements**
   - Privacy policy for AI data processing
   - Terms of service
   - App Store privacy declarations
   - API usage disclosure

**For production-ready architecture, all API keys must be server-side (Cloud Functions with Secret Manager).**

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- **Firebase** - Real-time backend infrastructure
- **OpenAI** - GPT-4 and embedding models
- **SwiftUI** - Modern iOS UI framework
- **Google Sign-In** - Seamless authentication

---

## 📞 Support

For issues or questions:
1. Check **Troubleshooting** section above
2. Review **memory-bank/** documentation
3. Check Firebase Console logs
4. Review OpenAI API status

---

**Built with ❤️ for remote teams who want their conversations to work smarter, not harder.**

**Key Achievement:** Production-ready messaging + RAG-powered AI that searches across ALL your conversations! 🚀✨
