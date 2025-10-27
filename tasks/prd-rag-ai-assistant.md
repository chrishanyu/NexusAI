# Product Requirements Document: RAG-Powered Global AI Assistant

## Introduction/Overview

This PRD outlines the development of a global AI Assistant tab for NexusAI that uses Retrieval-Augmented Generation (RAG) to provide contextual search and intelligent Q&A across all conversations. Unlike the existing per-conversation AI Assistant, this feature gives users a unified interface to query their entire conversation history, find decisions, detect priorities, and get answers based on semantic understanding rather than keyword matching.

**Problem it solves:** Remote teams have valuable information scattered across multiple conversations. Finding past decisions, tracking commitments across chats, and getting quick answers requires manually scrolling through numerous threads. This wastes time and leads to repeated questions or missed context.

**Goal:** Implement a conversational AI assistant that can semantically search and answer questions across all user conversations using RAG (Retrieval-Augmented Generation) with vector embeddings.

---

## Goals

1. **Semantic Search**: Enable natural language queries that understand meaning, not just exact keywords
2. **Cross-Conversation Context**: Search and synthesize information from all conversations user participates in
3. **Conversational Interface**: Chat-like UI familiar to users (similar to ChatGPT)
4. **Source Attribution**: Every answer shows which messages it came from with ability to jump to original context
5. **Decision Intelligence**: Automatically identify and track decisions made across conversations
6. **Priority Detection**: Flag urgent or important items mentioned across all chats
7. **Coexist with Existing AI**: Global AI complements (not replaces) per-conversation AI Assistant

---

## User Stories

### Primary User: Remote Team Professional

1. **As a team lead**, I want to ask "What did we decide about the Q4 roadmap?" and get answers from all relevant conversations
2. **As a developer**, I want to search "What features need to be done by Friday?" across all my group chats and DMs
3. **As a project manager**, I want to see which decisions were made this week so I can track progress
4. **As a remote worker**, I want to click on an AI answer and jump to the original message to see full context
5. **As a team member**, I want to ask "What are my urgent tasks?" and get a unified view across all conversations
6. **As a manager**, I want to query "What did Bob commit to?" and see all his commitments from different discussions
7. **As a user**, I want to have a conversation with the AI, asking follow-up questions naturally

---

## Functional Requirements

### 1. Tab Navigation & UI Structure

**1.1** Add a third tab to bottom navigation: **Chat | AI Assistant | Profile**

**1.2** AI Assistant tab icon: Brain or sparkles SF Symbol (`brain` or `sparkles`)

**1.3** AI Assistant tab shows conversational interface with:
- Chat-like message bubbles
- User messages (right side, blue)
- AI responses (left side, gray/white with source attribution)
- Text input at bottom
- Message history preserved during session

**1.4** Navigation bar title: "AI Assistant" with subtitle showing status (e.g., "Ready" or "Searching X conversations")

---

### 2. Conversational Interface

**2.1** Text input bar at bottom:
- Placeholder: "Ask me anything about your conversations..."
- Send button (paper plane icon)
- Multi-line text support
- Auto-grow up to 5 lines

**2.2** User messages display:
- Right-aligned bubbles (blue)
- Timestamp (optional, hidden by default)
- Simple, clean design

**2.3** AI response messages display:
- Left-aligned bubbles (gray/white)
- Loading state: "Searching your conversations..." with animated dots
- Response text with markdown support (bold, lists, etc.)
- Source attribution section (see 2.4)

**2.4** Source Attribution (below each AI response):
- "Based on X messages from Y conversations:"
- List of source messages with:
  - Conversation name or participant
  - Message excerpt (truncated to ~100 chars)
  - Timestamp
  - Relevance indicator (optional: "95% relevant")
  - Tap to jump to original message in ChatView

**2.5** Conversation History:
- Scroll to see previous queries and responses
- Persist during app session
- Clear when app is terminated (no persistence for MVP)

**2.6** Empty State (first time user opens tab):
- Icon: Brain or sparkles
- Title: "Your AI Assistant"
- Description: "Ask me anything about your conversations. I can search, summarize, and help you find information across all your chats."
- Example queries:
  - "What decisions were made this week?"
  - "What are my upcoming deadlines?"
  - "Find discussions about the new feature"

---

### 3. RAG Architecture & Implementation

**3.1** Vector Embedding Pipeline:
- Use OpenAI `text-embedding-3-small` model (1536 dimensions)
- Embed all messages from conversations user participates in
- Store embeddings in Firestore collection: `message_embeddings`

**3.2** Firestore Schema for Embeddings:
```
message_embeddings/{messageId}
{
  messageId: string
  conversationId: string
  senderId: string
  senderName: string
  text: string (original message text)
  embedding: [double] (1536-element array)
  timestamp: Date
  conversationName: string (for display)
  conversationType: string ("direct" | "group")
  createdAt: Date (when embedded)
}
```

**3.3** Cloud Function: `embedNewMessage`
- Trigger: Firestore onCreate for `conversations/{id}/messages/{msgId}`
- Action: Generate embedding, store in `message_embeddings`
- Error handling: Retry on failure, log errors

**3.4** Cloud Function: `ragSearch`
- Input: User query + userId
- Steps:
  1. Embed user query using OpenAI
  2. Fetch all user's message embeddings
  3. Calculate cosine similarity
  4. Return top K matches (default K=5)
  5. Filter: Only messages from conversations user is part of
- Output: Array of {messageId, text, conversationId, similarity}

**3.5** Cloud Function: `ragQuery`
- Input: User question + userId + optional filters
- Steps:
  1. Call `ragSearch` to get relevant messages
  2. Build augmented prompt with retrieved context
  3. Send to GPT-4 with prompt
  4. Return answer + source message references
- Output: {answer: string, sources: [SourceMessage]}

**3.6** Augmented Prompt Template:
```
You are an AI assistant helping users search their conversation history in NexusAI.

User Question: {user_query}

Relevant Context from Conversations:
---
Conversation: {conversation_name}
Date: {timestamp}
Sender: {sender_name}
Message: {message_text}
---
(repeat for top 5 messages)

Instructions:
1. Answer the user's question based on the provided context
2. Be specific and cite which conversation the information came from
3. If the context doesn't contain relevant information, say "I couldn't find information about that in your conversations"
4. Keep answers concise (2-3 sentences)
5. If asked about decisions, explicitly state what was decided
6. If asked about action items or tasks, list them clearly

Answer:
```

---

### 4. Core Features (Priority Order)

#### Feature 1: Contextual Search (Priority 1)

**4.1** Natural language search queries:
- "What did we decide about X?"
- "Find messages about Y"
- "When did Z happen?"

**4.2** Semantic understanding:
- "schedule a meeting" matches "set up a call"
- "deadline" matches "due date" or "needs to be done by"
- Understands synonyms and related concepts

**4.3** Search scope:
- All conversations user participates in
- No date filtering for MVP
- No manual conversation selection for MVP

---

#### Feature 2: Ask Anything (Priority 2)

**4.4** General Q&A about conversation history:
- "What has Bob been working on?"
- "Summarize this week's discussions"
- "What are the main topics we've discussed?"

**4.5** Multi-turn conversation:
- Support follow-up questions
- Maintain conversation context during session
- "Tell me more about that" or "What else did they say?"

**4.6** Answer formatting:
- Clear, concise responses
- Use bullet points for lists
- Bold for emphasis on key points

---

#### Feature 3: Decision Tracking (Priority 3)

**4.7** Decision detection prompt:
- "What decisions were made this week?"
- "Show me all decisions about X"
- "What did we decide?"

**4.8** Decision identification:
- Phrases like "let's go with", "we decided", "final decision", "agreed on"
- Clear yes/no decisions
- Who made the decision (if clear)

**4.9** Decision display format:
```
Decision: [Clear statement of what was decided]
When: [Date/time]
Conversation: [Name/participants]
Context: [Brief excerpt]
[Jump to message button]
```

---

#### Feature 4: Priority Detection (Priority 4)

**4.10** Priority/urgency queries:
- "What needs immediate attention?"
- "Show me urgent items"
- "What's high priority?"

**4.11** Urgency signals:
- Keywords: "urgent", "ASAP", "immediately", "critical", "emergency"
- Phrases: "needs to be done by today", "blocking", "can't proceed without"
- Time pressure: mentions of near-term deadlines

**4.12** Priority display:
- Group by urgency level (Critical, High, Medium)
- Show deadline if mentioned
- Show conversation context
- Allow jump to original message

---

#### Feature 5: Action Items Dashboard (Priority 5)

**4.13** Action item queries:
- "What are my tasks?"
- "Show all action items"
- "What do I need to do?"

**4.14** Integration with existing Action Items feature:
- Query mentions action items extraction
- Don't duplicate the existing per-conversation action items
- Simply answer questions about tasks across conversations

**4.15** Display format:
- List of tasks mentioned
- Who it's assigned to
- Source conversation
- Jump to message link

---

### 5. Message Jump Navigation

**5.1** Source message cards:
- Display conversation name/participants
- Show message excerpt (truncated)
- Show timestamp
- Tappable area

**5.2** Jump action:
- Tap source message → Navigate to Chat tab
- Open the specific conversation
- Scroll to the exact message
- Highlight the message briefly (yellow background fade)

**5.3** Navigation state preservation:
- After jumping, back button returns to AI Assistant tab
- AI Assistant tab preserves conversation state

**5.4** Message not found handling:
- If message was deleted: Show "Message no longer available"
- If conversation removed: Show "Conversation no longer accessible"

---

### 6. Backend Services & APIs

**6.1** Create `MessageEmbeddingService`:
- `embedMessage(_ message: Message)` → Store embedding in Firestore
- `searchMessages(query: String, userId: String, topK: Int)` → Call Cloud Function
- `ragQuery(question: String, userId: String)` → Get answer + sources

**6.2** Create `RAGService`:
- `query(_ question: String)` → Main entry point
- `processResponse(_ response: RAGResponse)` → Parse and format
- Handle errors (network, API limits, no results)

**6.3** Cloud Functions to create:
- `embedNewMessage` (Firestore trigger)
- `ragSearch` (HTTPS callable)
- `ragQuery` (HTTPS callable)

**6.4** Error handling:
- Network errors: "Unable to connect. Check your internet."
- No results: "I couldn't find relevant information about that."
- API errors: "Something went wrong. Please try again."
- Rate limits: "Too many requests. Please wait a moment."

---

### 7. Data Models

**7.1** `RAGQuery` (User input):
```swift
struct RAGQuery {
    let id: UUID
    let question: String
    let userId: String
    let timestamp: Date
}
```

**7.2** `RAGResponse` (AI answer):
```swift
struct RAGResponse: Codable {
    let answer: String
    let sources: [SourceMessage]
    let queryTime: Date
}
```

**7.3** `SourceMessage` (Attribution):
```swift
struct SourceMessage: Codable, Identifiable {
    let id: String // messageId
    let conversationId: String
    let conversationName: String
    let messageText: String
    let senderName: String
    let timestamp: Date
    let relevanceScore: Double // 0.0 to 1.0
}
```

**7.4** `ConversationMessage` (Display in AI chat):
```swift
struct ConversationMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    let text: String
    let timestamp: Date
    var sources: [SourceMessage]? // Only for AI responses
    var isLoading: Bool = false
}
```

---

### 8. ViewModels & Views

**8.1** Create `GlobalAIViewModel`:
- `@Published var messages: [ConversationMessage]`
- `@Published var isLoading: Bool`
- `@Published var errorMessage: String?`
- `func sendQuery(_ question: String)`
- `func clearHistory()`
- Inject `RAGService` dependency

**8.2** Create `GlobalAIAssistantView`:
- Main view for AI Assistant tab
- ScrollView with message list
- Text input bar at bottom
- Empty state view
- Loading states

**8.3** Create `AIMessageBubbleView`:
- User message bubble (right, blue)
- AI message bubble (left, gray/white)
- Loading indicator bubble

**8.4** Create `SourceMessageCard`:
- Display source attribution
- Conversation name
- Message excerpt
- Timestamp
- Tap gesture for navigation

**8.5** Update `MainTabView`:
- Add third tab: AI Assistant
- Icon: `brain` or `sparkles`
- Badge: None (no notification count)

---

## Non-Goals (Out of Scope for MVP)

1. **No Action Items Consolidation**: Don't create a unified action items view across conversations
2. **No Separate Action Items UI**: Use existing per-conversation action items feature
3. **No Conversation Filtering**: Can't manually select which conversations to search
4. **No Date Range Filtering**: Searches all history (no "last 30 days" filter)
5. **No Real-Time Embedding**: Messages embedded asynchronously via Cloud Functions (not instant)
6. **No Offline Support**: Requires internet connection for all features
7. **No Conversation Editing**: Can't edit/delete messages from AI tab
8. **No Export**: Can't export search results or AI responses
9. **No Voice Input**: Text input only
10. **No Multi-User Collaboration**: Single user queries only (can't share AI conversations)
11. **No Advanced Analytics**: No usage metrics, search trends, or insights
12. **No Cost Optimization**: No caching, no embedding reuse strategies
13. **No Performance SLAs**: As long as it works, speed doesn't matter
14. **No Scalability Concerns**: Built for demo, not production scale

---

## Design Considerations

### UI/UX Patterns

**Conversational Interface:**
- Familiar chat-like design (similar to iMessage, ChatGPT)
- Clear distinction between user and AI messages
- Easy-to-read typography with comfortable line spacing
- Smooth scroll animations

**Source Attribution:**
- Visual separation from main answer (lighter background)
- Clear tap targets (minimum 44pt touch area)
- Iconography: Conversation icon, timestamp icon, relevance indicator

**Loading States:**
- Animated dots: "Searching your conversations..."
- Subtle animation (breathing or pulse)
- Cancel button (optional for MVP)

**Empty States:**
- Welcoming, not intimidating
- Show example queries to guide users
- Large, friendly icon

**Error States:**
- Non-blocking error messages
- Retry button when applicable
- Clear, user-friendly language (no technical jargon)

### Accessibility

**Voice Over:**
- All buttons labeled
- Message roles announced ("You asked", "AI answered")
- Source cards described fully

**Dynamic Type:**
- All text scales with system settings
- Minimum touch target size: 44x44pt

**Color Contrast:**
- WCAG AA compliance for all text
- Dark mode support

---

## Technical Considerations

### OpenAI Integration

**Models:**
- Embeddings: `text-embedding-3-small` (1536 dimensions)
- Chat completion: `gpt-4-turbo` or `gpt-4o`

**Rate Limits:**
- Not a concern for demo/MVP
- Handle gracefully if hit (show retry)

**Cost Estimation (for reference, not a constraint):**
- Embeddings: ~$0.00002 per message
- Chat completion: ~$0.01-0.03 per query
- Demo with 100 queries: ~$3-5 total

### Cloud Functions

**Function 1: `embedNewMessage`**
- Runtime: Node.js 20
- Trigger: Firestore onCreate
- Timeout: 60 seconds
- Memory: 256MB

**Function 2: `ragSearch`**
- Runtime: Node.js 20
- Trigger: HTTPS Callable
- Timeout: 60 seconds
- Memory: 512MB (needs to process vectors)

**Function 3: `ragQuery`**
- Runtime: Node.js 20
- Trigger: HTTPS Callable
- Timeout: 60 seconds
- Memory: 256MB

**Deployment:**
- Firebase CLI for deployment
- Environment variables for OpenAI API key

### Firestore Schema

**Collection: `message_embeddings`**
- Index: `userId` (for filtering)
- Index: `timestamp` (for sorting)
- Size: ~2KB per document (1536 * 8 bytes + metadata)

**Permissions:**
- Users can only read their own embeddings
- Cloud Functions have admin access

### Vector Search Implementation

**Cosine Similarity:**
```javascript
function cosineSimilarity(vecA, vecB) {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magA * magB);
}
```

**Performance:**
- O(n) for n messages (acceptable for demo)
- Future optimization: Use specialized vector DB (Pinecone, Weaviate)

### Message Jump Implementation

**Navigation Flow:**
1. User taps source message card
2. `GlobalAIViewModel` calls `navigateToMessage(messageId, conversationId)`
3. Change tab to Chat tab programmatically
4. `ConversationListViewModel` opens conversation
5. `ChatViewModel` scrolls to message
6. Briefly highlight message (yellow fade animation)

**State Management:**
- Use `@AppStorage` to coordinate tab selection
- Pass navigation parameters via `@EnvironmentObject`
- Use `NotificationCenter` as fallback

---

## Success Criteria

Since we're not tracking metrics for MVP, success is defined as:

1. ✅ Users can ask natural language questions
2. ✅ AI returns relevant answers with sources
3. ✅ Source messages link back to original conversations
4. ✅ Jump to message navigation works smoothly
5. ✅ All 5 core features functional (search, ask anything, decisions, priority, action items)
6. ✅ Conversational interface feels natural and responsive
7. ✅ No critical bugs or crashes
8. ✅ Works with existing features without conflicts

---

## Implementation Plan

**Timeline:** 14-21 days (2-3 weeks)

### Backend Infrastructure
- Set up Cloud Functions project
- Create `embedNewMessage` Cloud Function (auto-embeds new messages)
- Create `ragSearch` Cloud Function (vector similarity search)
- Create `ragQuery` Cloud Function (RAG with GPT-4)
- Test embedding pipeline
- Test vector search with cosine similarity
- Test GPT-4 integration
- Write unit tests for Cloud Functions

### iOS Service Layer
- Create `MessageEmbeddingService`
- Create `RAGService`
- Create data models (RAGQuery, RAGResponse, SourceMessage, ConversationMessage)
- Implement Cloud Function calls
- Add comprehensive error handling
- Test with mock data

### UI & Navigation
- Add third tab to `MainTabView` (Chat | AI Assistant | Profile)
- Create `GlobalAIAssistantView`
- Create `GlobalAIViewModel`
- Create `AIMessageBubbleView` (user + AI bubbles)
- Create `SourceMessageCard` component
- Implement text input bar
- Implement message list with ScrollView
- Implement empty state
- Implement loading states
- Implement error states

### Message Jump Navigation
- Implement tap gesture on source cards
- Implement tab switching logic (AI → Chat)
- Implement conversation opening
- Implement scroll to message
- Implement message highlight animation (yellow fade)
- Test navigation flows

### Feature Implementation
- Implement contextual search (natural language queries)
- Implement ask anything Q&A (general questions about history)
- Implement decision tracking (find decisions made)
- Implement priority detection (flag urgent items)
- Implement action items dashboard queries (tasks across conversations)
- Test each feature thoroughly
- Refine GPT-4 prompts based on testing

### Testing & Polish
- Integration testing (all features together)
- Edge case testing (no results, errors, deleted messages)
- UI polish (animations, spacing, colors)
- Dark mode support
- Accessibility testing (VoiceOver, Dynamic Type)
- Performance check (acceptable latency)
- Fix any bugs found

---

## Open Questions

1. **Backfill Strategy**: Should we embed all existing messages at once, or only new messages going forward?
   - **Recommendation**: Create a one-time backfill script (Cloud Function) to embed existing messages

2. **Conversation Context**: Should AI remember previous queries in the session?
   - **Recommendation**: Yes, maintain conversation context during session (cleared on app close)

3. **Max Context Window**: How many source messages should we retrieve?
   - **Recommendation**: Top 5 messages (balance between context and token cost)

4. **Source Display**: Show all sources or only top N?
   - **Recommendation**: Show all retrieved sources (5 max) with relevance scores

5. **Empty Conversation Handling**: What if user has no messages yet?
   - **Recommendation**: Show friendly message: "Start chatting to use AI search"

6. **Group Chat Attribution**: Show individual sender or just conversation?
   - **Recommendation**: Show both (conversation name + sender name)

7. **Multi-Language**: Should AI support non-English queries?
   - **Recommendation**: Yes, GPT-4 handles multiple languages naturally

8. **Query History**: Should we save past queries for suggestions?
   - **Recommendation**: Not for MVP, but good for Phase 2

---

## Appendix

### Example Queries & Expected Behavior

**Query: "What did we decide about the launch date?"**
- AI searches for messages containing decisions about "launch date"
- Returns: "Based on your conversation with Sarah on Oct 20, you decided to launch on November 15th."
- Shows source message from that conversation

**Query: "What are my urgent tasks?"**
- AI searches for action items with urgency indicators
- Returns: "You have 2 urgent tasks: 1) Finish the design mockups by tomorrow (from Design Team chat), 2) Review John's PR today (from Engineering chat)"
- Shows both source messages

**Query: "Summarize this week's discussions"**
- AI retrieves messages from past 7 days
- Returns: "This week, your team discussed: 1) Q4 planning and roadmap priorities, 2) New feature requirements for mobile app, 3) Bug fixes for the authentication system"
- Shows sources from multiple conversations

**Query: "What has Bob been working on?"**
- AI searches messages from/about Bob
- Returns: "Bob has been working on: 1) API integration for payments, 2) Database migration scripts, 3) Setting up CI/CD pipeline"
- Shows messages where Bob mentioned his work

---

### Glossary

- **RAG**: Retrieval-Augmented Generation - AI technique combining search + generation
- **Vector Embedding**: Numerical representation of text (1536-dimensional vector)
- **Cosine Similarity**: Measure of similarity between two vectors (0.0 to 1.0)
- **Context Window**: The amount of retrieved information provided to the LLM
- **Source Attribution**: Showing which messages an AI answer came from
- **Semantic Search**: Search based on meaning, not exact keywords

---

### References

- OpenAI Embeddings API: https://platform.openai.com/docs/guides/embeddings
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- Vector Search Algorithms: https://www.pinecone.io/learn/vector-similarity/
- RAG Best Practices: https://www.anthropic.com/research/retrieval-augmented-generation

---

**Document Version:** 1.0  
**Created:** October 26, 2025  
**Author:** AI Assistant  
**Status:** Draft - Ready for Review

