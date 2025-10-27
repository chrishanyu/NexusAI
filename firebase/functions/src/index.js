/**
 * Firebase Cloud Functions for NexusAI
 * RAG-powered Global AI Assistant
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions");

// Initialize Firebase Admin
admin.initializeApp();

// Export all Cloud Functions
const { embedNewMessage } = require("./embedNewMessage");
const { ragSearch } = require("./ragSearch");
const { ragQuery } = require("./ragQuery");

exports.embedNewMessage = embedNewMessage;
exports.ragSearch = ragSearch;
exports.ragQuery = ragQuery;

