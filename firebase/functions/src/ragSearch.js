/**
 * Cloud Function: ragSearch
 * HTTPS Callable - Vector similarity search across user's messages
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { generateEmbedding } = require("./shared/openai");
const { findTopKSimilar } = require("./shared/vectorSearch");

/**
 * HTTPS Callable Function: ragSearch
 * Performs semantic search across user's message history
 * 
 * @param {Object} data - Request data
 * @param {string} data.query - Search query
 * @param {string} data.userId - User ID making the request
 * @param {number} [data.topK=5] - Number of results to return
 * @param {Object} context - Firebase Auth context
 * @return {Promise<Array>} - Array of search results
 */
exports.ragSearch = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to perform search"
    );
  }
  
  const { query, userId, topK = 5 } = data;
  
  // Validate input
  if (!query || typeof query !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Query must be a non-empty string"
    );
  }
  
  if (!userId || typeof userId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId must be provided"
    );
  }
  
  // Verify user is requesting their own data
  if (context.auth.uid !== userId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Users can only search their own messages"
    );
  }
  
  console.log(`🔍 RAG Search request from user ${userId}: "${query}"`);
  
  try {
    // Step 1: Generate embedding for query
    console.log("🧠 Generating query embedding...");
    const queryEmbedding = await generateEmbedding(query);
    console.log(`✅ Query embedding generated (${queryEmbedding.length} dimensions)`);
    
    // Step 2: Get all conversations where user is a participant
    console.log("📚 Fetching user conversations...");
    const conversationsSnapshot = await admin.firestore()
      .collection("conversations")
      .where("participantIds", "array-contains", userId)
      .get();
    
    const conversationIds = conversationsSnapshot.docs.map((doc) => doc.id);
    console.log(`Found ${conversationIds.length} conversations for user`);
    
    if (conversationIds.length === 0) {
      console.log("⚠️  No conversations found for user");
      return [];
    }
    
    // Step 3: Fetch all message embeddings from user's conversations
    // Firestore has a limit of 10 items per "in" query, so we need to batch
    console.log("📥 Fetching message embeddings...");
    const embeddingsData = [];
    
    // Process in batches of 10
    for (let i = 0; i < conversationIds.length; i += 10) {
      const batch = conversationIds.slice(i, i + 10);
      const embeddingsSnapshot = await admin.firestore()
        .collection("message_embeddings")
        .where("conversationId", "in", batch)
        .get();
      
      embeddingsSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        embeddingsData.push({
          id: doc.id,
          embedding: data.embedding,
          metadata: {
            messageId: data.messageId,
            conversationId: data.conversationId,
            conversationName: data.conversationName,
            conversationType: data.conversationType,
            senderId: data.senderId,
            senderName: data.senderName,
            text: data.text,
            timestamp: data.timestamp,
          },
        });
      });
    }
    
    console.log(`Found ${embeddingsData.length} message embeddings`);
    
    if (embeddingsData.length === 0) {
      console.log("⚠️  No message embeddings found");
      return [];
    }
    
    // Step 4: Calculate cosine similarity and get top K results
    console.log(`🧮 Calculating similarity scores for ${embeddingsData.length} messages...`);
    const results = findTopKSimilar(queryEmbedding, embeddingsData, topK);
    
    // Format results
    const formattedResults = results.map((result) => ({
      messageId: result.metadata.messageId,
      conversationId: result.metadata.conversationId,
      conversationName: result.metadata.conversationName,
      conversationType: result.metadata.conversationType,
      senderId: result.metadata.senderId,
      senderName: result.metadata.senderName,
      text: result.metadata.text,
      timestamp: result.metadata.timestamp,
      relevanceScore: result.similarity,
    }));
    
    console.log(`✨ Returning ${formattedResults.length} results`);
    console.log("Top result similarity:", formattedResults[0]?.relevanceScore);
    
    return formattedResults;
  } catch (error) {
    console.error("❌ Error in ragSearch:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Search failed: ${error.message}`
    );
  }
});

