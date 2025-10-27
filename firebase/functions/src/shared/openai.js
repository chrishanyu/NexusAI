/**
 * OpenAI API Wrapper
 * Handles embedding generation and chat completions
 */

const { OpenAI } = require("openai");
const functions = require("firebase-functions");

// Initialize OpenAI client
// API key should be set via: firebase functions:config:set openai.key="sk-..."
const getOpenAIClient = () => {
  const apiKey = functions.config().openai?.key || process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    throw new Error("OpenAI API key not configured. Run: firebase functions:config:set openai.key=\"sk-...\"");
  }
  
  return new OpenAI({
    apiKey: apiKey,
  });
};

/**
 * Generate text embedding using text-embedding-3-small model
 * @param {string} text - Text to embed
 * @return {Promise<number[]>} - 1536-dimensional embedding vector
 */
async function generateEmbedding(text) {
  try {
    const openai = getOpenAIClient();
    
    const response = await openai.embeddings.create({
      model: "text-embedding-3-small",
      input: text,
      encoding_format: "float",
    });
    
    return response.data[0].embedding;
  } catch (error) {
    console.error("Error generating embedding:", error);
    throw new Error(`Failed to generate embedding: ${error.message}`);
  }
}

/**
 * Generate chat completion using GPT-4
 * @param {Array} messages - Array of message objects with role and content
 * @param {Object} options - Optional parameters (temperature, max_tokens, etc.)
 * @return {Promise<string>} - Generated response text
 */
async function generateChatCompletion(messages, options = {}) {
  try {
    const openai = getOpenAIClient();
    
    const response = await openai.chat.completions.create({
      model: options.model || "gpt-4-turbo-preview",
      messages: messages,
      temperature: options.temperature || 0.7,
      max_tokens: options.max_tokens || 500,
      top_p: options.top_p || 1.0,
      frequency_penalty: options.frequency_penalty || 0.0,
      presence_penalty: options.presence_penalty || 0.0,
    });
    
    // Log token usage for cost monitoring
    console.log("GPT-4 Token Usage:", {
      prompt_tokens: response.usage.prompt_tokens,
      completion_tokens: response.usage.completion_tokens,
      total_tokens: response.usage.total_tokens,
    });
    
    return response.choices[0].message.content;
  } catch (error) {
    console.error("Error generating chat completion:", error);
    throw new Error(`Failed to generate chat completion: ${error.message}`);
  }
}

module.exports = {
  generateEmbedding,
  generateChatCompletion,
};

