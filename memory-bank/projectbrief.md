# NexusAI Project Brief

## Project Overview

**Project Name:** Nexus (NexusAI)  
**Type:** iOS Messaging Application  
**Target Users:** Remote Team Professionals  
**Primary Goal:** Production-quality real-time messaging platform with AI integration capabilities

## Core Mission

Build a robust, real-time messaging infrastructure that:
1. Delivers messages instantly with WhatsApp-like reliability
2. Works seamlessly offline with automatic sync
3. Provides foundation for AI-powered team collaboration features
4. Handles edge cases gracefully (poor network, app lifecycle, rapid messages)

## Success Definition

The MVP is successful when:
- Two users can chat in real-time without message loss
- Group chat works with 3+ participants
- Messages persist through app restarts and offline scenarios
- Read receipts, typing indicators, and presence work reliably
- Push notifications deliver correctly (simulator testing via .apns files)
- Offline queuing and sync happens seamlessly

## Key Constraints

- **Timeline:** 24-hour MVP sprint
- **Platform:** iOS only (Swift + SwiftUI)
- **Testing:** Simulator-focused (real device deployment post-MVP)
- **Scope:** Core messaging infrastructure first, AI features second phase

## What Makes This Different

This isn't just another chat app - it's a **messaging infrastructure** designed for remote teams with built-in AI integration path. The architecture supports future AI features like:
- Thread summarization
- Action item extraction
- Smart search and priority detection
- Decision tracking
- Proactive AI assistant

## Non-Goals for MVP

- Beautiful UI (functional > pretty)
- Media sharing (images, voice, video)
- End-to-end encryption
- Real device deployment
- Advanced features beyond core messaging

## Project Phases

### Phase 1: MVP (Current)
Build rock-solid messaging foundation:
- One-on-one and group chat
- Real-time sync with offline support
- Read receipts and typing indicators
- Push notification architecture

### Phase 2: AI Integration (Post-MVP)
Add 5 required AI features + 1 advanced feature:
- Thread summarization, action items, smart search
- Priority detection, decision tracking
- Multi-step agent OR proactive assistant

## Core Principles

1. **Messages never get lost** - Optimistic UI + retry logic + offline queuing
2. **Feels instant** - Real-time Firestore listeners + local caching
3. **Works offline** - SwiftData persistence + message queue
4. **Handles edge cases** - App lifecycle, poor network, rapid messages
5. **Scalable architecture** - Ready for AI features without major refactoring

## Repository Structure

```
NexusAI/
├── NexusAI/                    # iOS app source
│   ├── Models/                 # Data models
│   ├── ViewModels/             # MVVM ViewModels
│   ├── Views/                  # SwiftUI Views
│   ├── Services/               # Business logic & Firebase
│   └── Utilities/              # Helpers & extensions
├── firebase/                   # Backend configuration
├── memory-bank/                # Project documentation
└── [documentation files]       # PRD, architecture, etc.
```

## Reference Documents

- `PRD.md` - Detailed product requirements
- `architecture.md` - System architecture diagram
- `building-phases.md` - PR breakdown and build phases
- `README.md` - Setup instructions

## Current Status

**Phase:** Foundation building (PR #2: Core Models & Constants)  
**Completed:** Project setup, Firebase configuration, core models  
**Next:** Services layer, authentication, then core messaging features

