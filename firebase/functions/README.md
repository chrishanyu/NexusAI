# NexusAI Cloud Functions

Firebase Cloud Functions for RAG-powered Global AI Assistant.

## Setup

### 1. Install Dependencies

```bash
cd firebase/functions
npm install
```

### 2. Configure OpenAI API Key

```bash
firebase functions:config:set openai.key="sk-your-api-key-here"
```

Or for local testing, create `.runtimeconfig.json`:

```json
{
  "openai": {
    "key": "sk-your-api-key-here"
  }
}
```

### 3. Deploy Functions

```bash
cd firebase
firebase deploy --only functions
```

Or deploy specific functions:

```bash
firebase deploy --only functions:embedNewMessage
firebase deploy --only functions:ragSearch
firebase deploy --only functions:ragQuery
```

## Cloud Functions

### 1. embedNewMessage (Firestore Trigger)

Automatically generates embeddings for new messages.

- **Trigger:** `onCreate` for `conversations/{conversationId}/messages/{messageId}`
- **Action:** Generates embedding using OpenAI and stores in `message_embeddings` collection
- **Model:** `text-embedding-3-small` (1536 dimensions)

### 2. ragSearch (HTTPS Callable)

Performs vector similarity search across user's messages.

- **Type:** HTTPS Callable Function
- **Input:** `{ query: string, userId: string, topK?: number }`
- **Output:** Array of top K similar messages with metadata
- **Algorithm:** Cosine similarity

### 3. ragQuery (HTTPS Callable)

Performs RAG-powered Q&A using GPT-4.

- **Type:** HTTPS Callable Function
- **Input:** `{ question: string, userId: string }`
- **Output:** `{ answer: string, sources: SourceMessage[] }`
- **Process:**
  1. Calls `ragSearch` to get relevant messages
  2. Builds augmented prompt with context
  3. Calls GPT-4 for answer generation
  4. Returns answer with source attribution

## Firestore Collections

### message_embeddings

```
message_embeddings/{messageId}
{
  messageId: string
  conversationId: string
  senderId: string
  senderName: string
  text: string
  embedding: number[] (1536 elements)
  timestamp: Date
  conversationName: string
  conversationType: "direct" | "group"
  createdAt: Date
}
```

## Development

### Run Emulator

```bash
npm run serve
```

### Lint Code

```bash
npm run lint
npm run lint:fix
```

### View Logs

```bash
npm run logs
```

## Cost Estimation

- **Embeddings:** ~$0.00002 per message
- **Chat Completion:** ~$0.01-0.03 per query
- **Demo with 100 queries:** ~$3-5 total

