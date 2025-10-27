/**
 * Cloud Function: embedNewMessage
 * Firestore Trigger - Automatically embeds new messages
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { generateEmbedding } = require("./shared/openai");

/**
 * Firestore trigger: onCreate for messages
 * Generates embedding and stores in message_embeddings collection
 */
exports.embedNewMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageId = context.params.messageId;
    const conversationId = context.params.conversationId;
    const messageData = snap.data();
    
    console.log(`📥 New message detected: ${messageId} in conversation ${conversationId}`);
    
    try {
      // Extract message text
      const text = messageData.text;
      
      if (!text || text.trim().length === 0) {
        console.log("⚠️  Empty message text, skipping embedding");
        return null;
      }
      
      // Get conversation details for metadata
      const conversationRef = admin.firestore()
        .collection("conversations")
        .doc(conversationId);
      
      const conversationSnap = await conversationRef.get();
      
      if (!conversationSnap.exists) {
        console.error("❌ Conversation not found:", conversationId);
        return null;
      }
      
      const conversationData = conversationSnap.data();
      
      // Determine conversation name
      let conversationName;
      if (conversationData.type === "group") {
        conversationName = conversationData.groupName || "Group Chat";
      } else {
        // For direct messages, use participant names (excluding sender)
        const participants = conversationData.participants || {};
        const participantNames = Object.keys(participants)
          .filter((userId) => userId !== messageData.senderId)
          .map((userId) => participants[userId].displayName)
          .join(", ");
        conversationName = participantNames || "Direct Message";
      }
      
      // Generate embedding
      console.log("🧠 Generating embedding for message...");
      const embedding = await generateEmbedding(text);
      console.log(`✅ Embedding generated (${embedding.length} dimensions)`);
      
      // Prepare embedding document
      const embeddingDoc = {
        messageId: messageId,
        conversationId: conversationId,
        senderId: messageData.senderId,
        senderName: messageData.senderName,
        text: text,
        embedding: embedding,
        timestamp: messageData.timestamp,
        conversationName: conversationName,
        conversationType: conversationData.type,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Store in message_embeddings collection
      await admin.firestore()
        .collection("message_embeddings")
        .doc(messageId)
        .set(embeddingDoc);
      
      console.log(`✨ Embedding stored successfully for message ${messageId}`);
      
      return null;
    } catch (error) {
      console.error("❌ Error in embedNewMessage:", error);
      
      // Log error but don't throw - we don't want to crash the function
      // Future improvement: implement retry logic with exponential backoff
      console.error("Error details:", {
        messageId: messageId,
        conversationId: conversationId,
        error: error.message,
        stack: error.stack,
      });
      
      return null;
    }
  });

