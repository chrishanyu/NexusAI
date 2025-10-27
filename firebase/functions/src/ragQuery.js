/**
 * Cloud Function: ragQuery
 * HTTPS Callable - RAG-powered Q&A using GPT-4
 */

const functions = require("firebase-functions");
const { generateChatCompletion } = require("./shared/openai");

/**
 * UNIFIED SYSTEM PROMPT for Nexus
 * Stored as a constant - never changes between queries
 */
const NEXUS_SYSTEM_PROMPT = `You are Nexus, an AI assistant for NexusAI, a team collaboration platform.

Your role is to help users search and understand their conversation history across all their chats.

CAPABILITIES:
- Search conversations semantically (understanding meaning, not just keywords)
- Track decisions made in conversations
- Identify action items and tasks
- Detect urgent or high-priority items
- Summarize discussions
- Answer questions about past conversations
- Support follow-up questions and maintain conversation context

INSTRUCTIONS:
1. Answer questions based ONLY on the provided conversation context
2. Be specific and cite which conversation information came from
3. If context doesn't contain relevant information, say "I couldn't find information about that in your conversations"
4. Keep answers concise (2-3 sentences unless more detail is needed)
5. If asked about decisions, explicitly state what was decided and who participated
6. If asked about action items, list them clearly with assignees
7. If asked about priorities, highlight time-sensitive information
8. Use bullet points for lists to improve readability
9. Be conversational and helpful in tone
10. For follow-up questions like "tell me more" or "what else?", use the conversation history to understand context

Remember: You only have access to the user's conversation history provided in the context. You cannot access external information.`;

/**
 * Format RAG context for the user message
 * @param {Array} relevantMessages - Retrieved messages from RAG search
 * @return {string} - Formatted context string
 */
function formatRAGContext(relevantMessages) {
  if (relevantMessages.length === 0) {
    return "No relevant messages found in the user's conversation history.\n\nNote: The user may be asking about something not discussed in their conversations, or asking a general question outside the scope of their chat history.";
  }
  
  let contextText = "RELEVANT CONVERSATIONS:\n\n";
  
  relevantMessages.forEach((msg, index) => {
    contextText += `[${index + 1}] Conversation: ${msg.conversationName}\n`;
    contextText += `    Date: ${new Date(msg.timestamp._seconds * 1000).toLocaleString()}\n`;
    contextText += `    Sender: ${msg.senderName}\n`;
    contextText += `    Message: ${msg.text}\n\n`;
  });
  
  return contextText;
}

/**
 * Build augmented prompt for GPT-4 with conversation history support
 * @param {string} userQuestion - User's current question
 * @param {Array} relevantMessages - Retrieved messages from RAG search
 * @param {Array} conversationHistory - Previous Q&A pairs (optional)
 * @return {Array} - Array of message objects for GPT-4
 */
function buildAugmentedPrompt(userQuestion, relevantMessages, conversationHistory = []) {
  const messages = [];
  
  // 1. Add unified system prompt (always first, always the same)
  messages.push({
    role: "system",
    content: NEXUS_SYSTEM_PROMPT,
  });
  
  // 2. Add conversation history (previous Q&A pairs)
  // Limit to last 10 messages (5 Q&A pairs) to avoid token limits
  if (conversationHistory && conversationHistory.length > 0) {
    const recentHistory = conversationHistory.slice(-10);
    messages.push(...recentHistory);
  }
  
  // 3. Add current user message with RAG context
  const ragContext = formatRAGContext(relevantMessages);
  const userMessageWithContext = `${ragContext}\n---\nQUESTION: ${userQuestion}`;
  
  messages.push({
    role: "user",
    content: userMessageWithContext,
  });
  
  return messages;
}

/**
 * HTTPS Callable Function: ragQuery
 * Performs RAG-powered Q&A with source attribution
 * 
 * @param {Object} data - Request data
 * @param {string} data.question - User's question
 * @param {string} data.userId - User ID making the request
 * @param {Object} context - Firebase Auth context
 * @return {Promise<Object>} - {answer: string, sources: Array}
 */
exports.ragQuery = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to query"
    );
  }
  
  const { question, userId, conversationHistory } = data;
  
  // Validate input
  if (!question || typeof question !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Question must be a non-empty string"
    );
  }
  
  if (!userId || typeof userId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId must be provided"
    );
  }
  
  // conversationHistory is optional - validate if provided
  const history = conversationHistory || [];
  
  // Verify user is requesting their own data
  if (context.auth.uid !== userId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Users can only query their own conversations"
    );
  }
  
  console.log(`💬 RAG Query from user ${userId}: "${question}"`);
  
  try {
    // Step 1: Perform RAG search to get relevant messages
    console.log("🔍 Calling ragSearch to find relevant messages...");
    
    // Import ragSearch function
    const { ragSearch } = require("./ragSearch");
    
    // Call ragSearch as internal function (bypass HTTPS wrapper)
    const searchResults = await ragSearch.run({
      query: question,
      userId: userId,
      topK: 5,
    }, context);
    
    console.log(`Found ${searchResults.length} relevant messages`);
    
    // Step 2: Build augmented prompt with conversation history
    // Note: We ALWAYS call GPT-4, even with zero results
    // This lets GPT-4 naturally explain what it can/can't do
    console.log("🧠 Building augmented prompt for GPT-4...");
    console.log(`📝 Including ${history.length} previous messages in context`);
    const messages = buildAugmentedPrompt(question, searchResults, history);
    
    // Step 3: Generate answer using GPT-4
    console.log("✨ Generating answer with GPT-4...");
    const answer = await generateChatCompletion(messages, {
      model: "gpt-4-turbo-preview",
      temperature: 0.7,
      max_tokens: 500,
    });
    
    console.log("✅ Answer generated successfully");
    
    // Step 4: Format sources for response
    const sources = searchResults.map((msg) => ({
      id: msg.messageId,
      conversationId: msg.conversationId,
      conversationName: msg.conversationName,
      messageText: msg.text,
      senderName: msg.senderName,
      timestamp: msg.timestamp,
      relevanceScore: msg.relevanceScore,
    }));
    
    return {
      answer: answer,
      sources: sources,
      queryTime: new Date().toISOString(),
    };
  } catch (error) {
    console.error("❌ Error in ragQuery:", error);
    
    // Provide more specific error messages
    if (error.message.includes("API key")) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "OpenAI API key not configured properly"
      );
    }
    
    if (error.message.includes("rate limit")) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many requests. Please wait a moment and try again."
      );
    }
    
    throw new functions.https.HttpsError(
      "internal",
      `Query failed: ${error.message}`
    );
  }
});

