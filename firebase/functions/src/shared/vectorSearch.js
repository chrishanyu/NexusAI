/**
 * Vector Search Utilities
 * Cosine similarity and vector operations
 */

/**
 * Calculate cosine similarity between two vectors
 * @param {number[]} vecA - First vector
 * @param {number[]} vecB - Second vector
 * @return {number} - Similarity score between 0.0 and 1.0
 */
function cosineSimilarity(vecA, vecB) {
  if (vecA.length !== vecB.length) {
    throw new Error("Vectors must have the same length");
  }
  
  let dotProduct = 0;
  let magA = 0;
  let magB = 0;
  
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    magA += vecA[i] * vecA[i];
    magB += vecB[i] * vecB[i];
  }
  
  magA = Math.sqrt(magA);
  magB = Math.sqrt(magB);
  
  if (magA === 0 || magB === 0) {
    return 0;
  }
  
  return dotProduct / (magA * magB);
}

/**
 * Find top K most similar vectors using cosine similarity
 * @param {number[]} queryVector - Query embedding
 * @param {Array<{id: string, embedding: number[], metadata: Object}>} documents - Documents with embeddings
 * @param {number} topK - Number of results to return
 * @return {Array<{id: string, similarity: number, metadata: Object}>} - Top K results sorted by similarity
 */
function findTopKSimilar(queryVector, documents, topK = 5) {
  // Calculate similarity for all documents
  const results = documents.map((doc) => {
    const similarity = cosineSimilarity(queryVector, doc.embedding);
    return {
      id: doc.id,
      similarity: similarity,
      metadata: doc.metadata,
    };
  });
  
  // Sort by similarity (descending) and take top K
  results.sort((a, b) => b.similarity - a.similarity);
  
  return results.slice(0, topK);
}

module.exports = {
  cosineSimilarity,
  findTopKSimilar,
};

