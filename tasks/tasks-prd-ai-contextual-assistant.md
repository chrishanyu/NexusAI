## Relevant Files

- `NexusAI/Utilities/ConfigManager.swift` - Configuration manager to read from plist (to be created)
- `NexusAI/Config.plist` - OpenAI API key configuration (to be created, gitignored)
- `.gitignore` - Add Config.plist to ignore list
- `NexusAI/Data/Models/LocalAIMessage.swift` - AI message data model (to be created)
- `NexusAI/Data/Models/LocalAIConversation.swift` - AI conversation data model (to be created)
- `NexusAI/Data/Repositories/AIMessageRepository.swift` - Repository for AI messages (to be created)
- `NexusAI/Data/LocalDatabase.swift` - Update to include AI models
- `NexusAI/Services/AIService.swift` - OpenAI API integration service (to be created)
- `NexusAI/ViewModels/AIAssistantViewModel.swift` - ViewModel for AI assistant (to be created)
- `NexusAI/Views/Chat/AIAssistantView.swift` - Update existing view
- `NexusAI/Views/Chat/ChatView.swift` - Pass conversation context to AI assistant
- `NexusAI/ViewModels/ChatViewModel.swift` - May need to expose conversation data

### Notes

- Use existing SwiftData architecture for data persistence
- Follow repository pattern established in the codebase
- Maintain existing gradient styling and AI theme
- OpenAI SDK integration via SPM (Swift Package Manager)

## Tasks

- [x] 1.0 Set Up Configuration and Dependencies
  - [x] 1.1 Add OpenAI Swift SDK via Swift Package Manager (MacPaw/OpenAI)
  - [x] 1.2 Create `ConfigManager.swift` in Utilities folder to read Config.plist
  - [x] 1.3 Create `Config.plist` file with OPENAI_API_KEY entry
  - [x] 1.4 Add `Config.plist` to `.gitignore`
  - [x] 1.5 Test ConfigManager to verify API key is loaded successfully
- [x] 2.0 Implement Data Layer (Models and Storage)
  - [x] 2.1 Create `LocalAIMessage.swift` model with SwiftData (id, text, isFromAI, timestamp, conversationId, sequenceNumber)
  - [x] 2.2 Create `LocalAIConversation.swift` model with SwiftData (id, conversationThreadId, createdAt, updatedAt, messageCount)
  - [x] 2.3 Update `LocalDatabase.swift` to include AI models in the schema
  - [x] 2.4 Create `AIMessageRepository.swift` with CRUD operations (create, read, delete)
  - [x] 2.5 Implement `fetchMessages(for conversationId:)` to retrieve AI chat history
  - [x] 2.6 Implement `saveMessage()` to persist AI messages
  - [x] 2.7 Implement `clearMessages(for conversationId:)` to delete all AI messages for a conversation
  - [x] 2.8 Add AIMessageRepository to `RepositoryFactory.swift`
- [x] 3.0 Create OpenAI Service Integration
  - [x] 3.1 Create `AIService.swift` file in Services directory
  - [x] 3.2 Implement OpenAI API client initialization with API key from ConfigManager
  - [x] 3.3 Create method to build conversation context from messages and participants
  - [x] 3.4 Implement `sendMessage(prompt:, context:)` method for chat completion
  - [x] 3.5 Format context as system prompt + conversation history for GPT-4
  - [x] 3.6 Handle API response parsing and error cases
  - [x] 3.7 Use GPT-4 model ("gpt-4") in API requests
  - [x] 3.8 Add basic error handling for network failures
- [x] 4.0 Build AIAssistantViewModel
  - [x] 4.1 Create `AIAssistantViewModel.swift` file in ViewModels directory
  - [x] 4.2 Add `@Published` properties for messages, loading state, and error state
  - [x] 4.3 Inject AIMessageRepository and AIService dependencies
  - [x] 4.4 Implement `loadChatHistory(for conversationId:)` on initialization
  - [x] 4.5 Implement `sendMessage(text:)` method that calls AIService and saves to storage
  - [x] 4.6 Implement `clearChatHistory()` method with repository deletion
  - [x] 4.7 Add method to build conversation context from ChatViewModel data
  - [x] 4.8 Handle loading states (isLoading flag) during API calls
  - [x] 4.9 Handle and display error messages from API failures
  - [x] 4.10 Pass conversationId to ViewModel and maintain it throughout session
- [x] 5.0 Update UI Components and Views
  - [x] 5.1 Update `AIAssistantView` to accept conversationId parameter
  - [x] 5.2 Replace mock messages with actual messages from AIAssistantViewModel
  - [x] 5.3 Add "Suggested Prompts" section below the header with "Summarize this thread" button
  - [x] 5.4 Style suggested prompt button with gradient (purple/blue) and rounded corners
  - [x] 5.5 Implement tap action on suggested prompt to auto-send "Summarize this thread" message
  - [x] 5.6 Add "Clear Chat" button to navigation toolbar
  - [x] 5.7 Implement confirmation alert before clearing chat history
  - [x] 5.8 Add loading indicator view that displays while waiting for AI response
  - [x] 5.9 Update message list to use real AIMessage models instead of mock data
  - [x] 5.10 Handle empty state: show welcome message when no chat history exists
  - [x] 5.11 Update `ChatView` to pass conversationId and conversation context to AIAssistantView
  - [x] 5.12 Connect AIAssistantView to AIAssistantViewModel with proper initialization
  - [x] 5.13 Test persistence by closing and reopening AI assistant to verify history loads
  - [x] 5.14 Add error display UI for failed API requests

