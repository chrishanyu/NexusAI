# Product Requirements Document: AI Contextual Assistant

## Introduction/Overview

This PRD outlines the development of an AI-powered contextual assistant integrated into conversation threads. The assistant provides intelligent chat capabilities with conversation context, starting with thread summarization. Each conversation has its own AI chat history that persists across sessions. This is a prototype feature using OpenAI's GPT-4 API with client-side integration.

**Problem it solves:** Users need quick insights and assistance about their conversation threads without manually reading through all messages. The AI assistant provides intelligent summaries and can answer questions about the conversation.

**Goal:** Implement a functional AI assistant that can summarize conversation threads and interact naturally with users while maintaining persistent chat history per conversation.

## Goals

1. Enable users to get AI-powered summaries of entire conversation threads
2. Provide persistent AI chat history specific to each conversation
3. Create an intuitive interface with suggested prompts for quick actions
4. Integrate OpenAI GPT-4 API for high-quality AI responses
5. Store AI chat messages locally with proper data persistence
6. Allow users to clear AI chat history and start fresh

## User Stories

1. As a user, I want to click "Summarize this thread" and immediately receive a concise summary of all messages in the conversation
2. As a user, I want to ask the AI questions about my conversation and receive contextual answers
3. As a user, I want my AI chat history to persist so I can see previous interactions when I reopen the AI assistant
4. As a user, I want to clear the AI chat history and start a fresh conversation with the AI
5. As a user, I want to see a welcoming message when I first open the AI assistant
6. As a user, I want the AI to have context about conversation participants and their messages
7. As a user, I want quick access to the AI assistant from any conversation thread

## Functional Requirements

### 1. Data Model & Storage

**1.1** Create an `AIMessage` model that stores:
- Unique identifier (UUID)
- Message text content
- Sender type (user or AI)
- Timestamp
- Associated conversation ID
- Message order/sequence number

**1.2** Create an `AIConversation` model that stores:
- Unique identifier (UUID)
- Associated conversation thread ID
- Creation timestamp
- Last updated timestamp
- Message count

**1.3** Implement local storage using SwiftData/CoreData to persist AI messages

**1.4** Implement data retrieval to load AI chat history when assistant is opened

**1.5** Implement data deletion to clear AI chat history for a conversation

### 2. OpenAI Integration

**2.1** Create a configuration file (e.g., `Config.plist` or `APIConfig.swift`) that:
- Stores the OpenAI API key
- Is added to `.gitignore` to prevent source control check-in
- Includes a template/example file for developers

**2.2** Create an `AIService` that:
- Manages OpenAI API communication
- Constructs chat completion requests
- Handles API responses
- Manages conversation context

**2.3** Use GPT-4 model for all AI interactions

**2.4** Build conversation context by including:
- All messages from the conversation thread
- Participant names and display information
- No timestamps or message metadata

**2.5** Format context appropriately for OpenAI API (system prompt + conversation history)

### 3. AI Assistant UI

**3.1** Display existing AI chat history when assistant opens for a conversation

**3.2** Show welcome message on first open (keep existing mockup message)

**3.3** Implement a "Suggested Prompt" section with:
- "Summarize this thread" button/chip
- Clickable interaction that auto-sends the prompt
- Visual styling consistent with the AI theme (purple/blue gradient)

**3.4** Add a "Clear Chat" button in the navigation bar or settings that:
- Prompts user for confirmation
- Clears all AI messages for this conversation
- Shows fresh welcome state after clearing

**3.5** Display AI messages with gradient styling (existing design)

**3.6** Display user messages with standard styling (existing design)

**3.7** Show loading indicator while waiting for AI response

### 4. Message Flow

**4.1** When user clicks "Summarize this thread":
- Automatically send the prompt to AI service
- Show user's message in chat
- Display loading indicator
- Fetch all conversation messages as context
- Send to OpenAI with appropriate system prompt
- Display AI response in chat
- Save both messages to local storage

**4.2** When user sends a custom message:
- Display user's message immediately
- Show loading indicator
- Include conversation context in API request
- Display AI response
- Save both messages to local storage

**4.3** Maintain message order and conversation flow

### 5. Error Handling (Simple Implementation)

**5.1** Display error alert if API request fails

**5.2** Show error message in chat if response cannot be retrieved

**5.3** Allow user to retry failed requests

**5.4** Handle network offline state with basic error message

### 6. ViewModel & Business Logic

**6.1** Create `AIAssistantViewModel` that:
- Manages AI chat state
- Loads chat history on initialization
- Sends messages to AI service
- Updates UI with responses
- Handles loading states
- Manages errors

**6.2** Integrate with existing `ChatViewModel` to access conversation context

**6.3** Implement conversation context building logic

## Non-Goals (Out of Scope)

1. **Global AI assistant history** - Will be implemented in a future phase
2. **Advanced suggested prompts** - Only "Summarize this thread" for now
3. **Token usage optimization** - Assuming context window is sufficient for prototype
4. **Rate limiting/throttling** - Not implementing for prototype
5. **Character limits on responses** - AI can respond with any length
6. **Message timestamps in AI chat** - Simple display without detailed timestamps
7. **Read receipts for AI messages** - Not applicable
8. **Sync to Firebase** - Local storage only for now
9. **Advanced error retry logic** - Keeping error handling simple
10. **API key configuration UI** - Hardcoded in config file
11. **Message editing or regeneration** - Not in initial version
12. **Multiple conversation threads with AI** - Each conversation has one AI thread

## Design Considerations

### UI/UX
- Maintain existing AI assistant design with purple/blue gradient theme
- Sparkles icon represents AI throughout the interface
- Clear visual distinction between user and AI messages
- Suggested prompt appears prominently at the top of the chat
- Welcome message sets friendly, helpful tone

### Component Structure
```
AIAssistantView (existing)
├── Navigation Bar (X button)
├── ScrollView
│   ├── Welcome Message / Header
│   ├── Suggested Prompts (new)
│   │   └── "Summarize this thread" button
│   └── AI Message List
│       ├── AIMessageBubble (user messages)
│       └── AIMessageBubble (AI messages)
└── Input Bar
    ├── Text Input
    └── Send Button
```

### Styling Guidelines
- Use existing gradient colors (purple, blue, cyan)
- Maintain rounded corners (16pt) for message bubbles
- Keep consistent padding and spacing
- Loading indicator: subtle animation with AI theme colors

## Technical Considerations

### Dependencies
- OpenAI Swift SDK (or URLSession for direct API calls)
- SwiftData/CoreData for local persistence
- Existing Data layer architecture

### Data Flow
```
User Action
    ↓
AIAssistantViewModel
    ↓
AIService (formats context, calls OpenAI)
    ↓
OpenAI API
    ↓
AIService (receives response)
    ↓
AIAssistantViewModel (updates state)
    ↓
Local Storage (persists message)
    ↓
UI Update
```

### Context Building
```swift
System Prompt: "You are a helpful AI assistant analyzing a conversation thread."

Context Format:
"""
Participants:
- [Participant 1 Name]
- [Participant 2 Name]
...

Conversation:
[Participant 1]: [Message 1]
[Participant 2]: [Message 2]
...
"""
```

### API Configuration
- Use `.gitignore` to exclude config file
- Provide template file: `APIConfig.template.swift`
- Document setup steps in README or comments

### Performance Considerations
- Load AI history asynchronously
- Implement pagination if history becomes long (future enhancement)
- Cache conversation context during session
- Assume all messages fit in GPT-4 context window for prototype

## Success Metrics

1. Users can successfully receive thread summaries
2. AI chat history persists across app sessions
3. AI responses are contextually relevant to the conversation
4. No crashes or critical errors during AI interactions
5. Clear chat functionality works reliably
6. API integration is functional and secure (for prototype)

## Open Questions

None at this time - all clarifications received.

## Implementation Notes

### Phase 1: Data Layer
1. Create AI message models
2. Implement local storage
3. Create repository pattern for AI data

### Phase 2: AI Service
1. Set up OpenAI integration
2. Implement context building
3. Create API service with error handling

### Phase 3: ViewModel
1. Create AIAssistantViewModel
2. Implement state management
3. Connect to AI service and storage

### Phase 4: UI Implementation
1. Update AIAssistantView with suggested prompts
2. Implement clear chat functionality
3. Add loading states and error displays
4. Connect to ViewModel

### Phase 5: Testing & Polish
1. Test with various conversation sizes
2. Verify persistence works correctly
3. Test error scenarios
4. Refine UI/UX based on usage

## Security Notes

⚠️ **Prototype Only**: This implementation stores the API key client-side, which is NOT suitable for production. For production deployment, API calls should go through a secure backend service.

## Future Enhancements (Not in This PRD)

- Global AI assistant (separate from conversation-specific)
- Multiple suggested prompts
- Smart context window management
- Message regeneration
- Conversation export
- Voice input
- Streaming responses
- Token usage tracking

