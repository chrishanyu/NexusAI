//
//  MessageService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseFirestore

/// Service for message operations and real-time sync
class MessageService {
    
    // MARK: - Properties
    private let db = FirebaseService.shared.db
    private let conversationService = ConversationService()
    
    // MARK: - Send Messages
    
    /// Send a message with optimistic UI support
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - text: Message text content
    ///   - senderId: ID of the user sending the message
    ///   - senderName: Display name of the sender
    ///   - localId: Local ID for optimistic UI deduplication
    /// - Returns: The Firestore-generated message ID
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String,
        localId: String
    ) async throws -> String {
        // Create message data with server timestamp
        let messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "status": MessageStatus.sent.rawValue,
            "readBy": [senderId],
            "deliveredTo": [],
            "localId": localId
        ]
        
        // Add message to Firestore
        let docRef = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .addDocument(data: messageData)
        
        // Create Message object for updating conversation's lastMessage
        let sentMessage = Message(
            id: docRef.documentID,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(), // Use current time for lastMessage display
            status: .sent,
            readBy: [senderId],
            deliveredTo: [],
            localId: localId
        )
        
        // Update conversation's last message
        try await conversationService.updateLastMessage(conversationId: conversationId, message: sentMessage)
        
        return docRef.documentID
    }
    
    // MARK: - Read Messages
    
    /// Get messages for a conversation with pagination
    func getMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
    }
    
    /// Get older messages before a specific timestamp
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .end(before: [beforeDate])
            .limit(toLast: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
    }
    
    // MARK: - Real-Time Message Sync
    
    /// Listen to real-time message updates for a conversation
    /// - Parameters:
    ///   - conversationId: ID of the conversation to listen to
    ///   - limit: Maximum number of recent messages to fetch (default 50)
    ///   - onChange: Callback when messages change, receives array of messages
    /// - Returns: Listener registration that must be removed when done
    func listenToMessages(
        conversationId: String,
        limit: Int = 50,
        onChange: @escaping ([Message]) -> Void
    ) -> ListenerRegistration {
        let listener = db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to messages: \(error.localizedDescription)")
                    onChange([])
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("Snapshot is nil")
                    onChange([])
                    return
                }
                
                // Map documents to Message models
                let messages = snapshot.documents.compactMap { document -> Message? in
                    try? document.data(as: Message.self)
                }
                
                // Call the onChange callback with updated messages
                onChange(messages)
                
                // Log changes for debugging
                snapshot.documentChanges.forEach { change in
                    switch change.type {
                    case .added:
                        print("Message added: \(change.document.documentID)")
                    case .modified:
                        print("Message modified: \(change.document.documentID)")
                    case .removed:
                        print("Message removed: \(change.document.documentID)")
                    }
                }
            }
        
        return listener
    }
    
    // MARK: - Message Status Updates
    
    /// Mark messages as delivered
    func markMessagesAsDelivered(conversationId: String, messageIds: [String], userId: String) async throws {
        let batch = db.batch()
        
        for messageId in messageIds {
            let messageRef = db.collection(Constants.Collections.conversations)
                .document(conversationId)
                .collection(Constants.Collections.messages)
                .document(messageId)
            
            batch.updateData([
                "deliveredTo": FieldValue.arrayUnion([userId]),
                "status": MessageStatus.delivered.rawValue
            ], forDocument: messageRef)
        }
        
        try await batch.commit()
    }
    
    /// Mark a single message as delivered
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - messageId: ID of the message to mark as delivered
    ///   - userId: ID of the user who received the message
    func markMessageAsDelivered(conversationId: String, messageId: String, userId: String) async throws {
        let messageRef = db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .document(messageId)
        
        try await messageRef.updateData([
            "deliveredTo": FieldValue.arrayUnion([userId]),
            "status": MessageStatus.delivered.rawValue
        ])
    }
    
    /// Mark specific messages as read (efficient batch update)
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - conversationId: ID of the conversation
    ///   - userId: ID of the user marking messages as read
    /// - Note: Uses batch writes for efficiency. Errors are caught silently to avoid blocking UI.
    func markMessagesAsRead(messageIds: [String], conversationId: String, userId: String) async throws {
        guard !messageIds.isEmpty else { return }
        
        let batch = db.batch()
        
        for messageId in messageIds {
            let messageRef = db.collection(Constants.Collections.conversations)
                .document(conversationId)
                .collection(Constants.Collections.messages)
                .document(messageId)
            
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId]),
                "status": MessageStatus.read.rawValue
            ], forDocument: messageRef)
        }
        
        try await batch.commit()
    }
    
    /// Mark all unread messages in a conversation as read (legacy method)
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - userId: ID of the user marking messages as read
    func markAllMessagesAsRead(conversationId: String, userId: String) async throws {
        // Get unread messages for this user
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .whereField("senderId", isNotEqualTo: userId)
            .getDocuments()
        
        let batch = db.batch()
        var hasUpdates = false
        
        for document in snapshot.documents {
            if let message = try? document.data(as: Message.self),
               !message.readBy.contains(userId) {
                batch.updateData([
                    "readBy": FieldValue.arrayUnion([userId]),
                    "status": MessageStatus.read.rawValue
                ], forDocument: document.reference)
                hasUpdates = true
            }
        }
        
        if hasUpdates {
            try await batch.commit()
        }
    }
    
    /// Get unread message count for a conversation
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - userId: ID of the user to check unread messages for
    /// - Returns: Number of unread messages (messages not in user's readBy array)
    func getUnreadCount(conversationId: String, userId: String) async throws -> Int {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .whereField("senderId", isNotEqualTo: userId)
            .getDocuments()
        
        // Filter messages where userId is NOT in readBy array
        let unreadCount = snapshot.documents.filter { document in
            guard let message = try? document.data(as: Message.self) else { return false }
            return !message.readBy.contains(userId)
        }.count
        
        return unreadCount
    }
    
    /// Update message status
    func updateMessageStatus(conversationId: String, messageId: String, status: MessageStatus) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .document(messageId)
            .updateData([
                "status": status.rawValue
            ])
    }
    
    // MARK: - Real-Time Listeners
    
    /// Listen to messages in a conversation
    func listenToMessages(conversationId: String, onChange: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                onChange(messages)
            }
    }
    
    /// Listen to new messages only (after a specific timestamp)
    func listenToNewMessages(conversationId: String, after: Date, onChange: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .whereField("timestamp", isGreaterThan: after)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching new messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                onChange(messages)
            }
    }
    
    // MARK: - Delete Message
    
    /// Delete a message
    func deleteMessage(conversationId: String, messageId: String) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .document(messageId)
            .delete()
    }
}

// MARK: - Message Errors
enum MessageError: LocalizedError {
    case messageNotFound
    case sendFailed
    case unauthorized
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            return "Message not found"
        case .sendFailed:
            return "Failed to send message"
        case .unauthorized:
            return "Not authorized to send messages"
        case .invalidData:
            return "Invalid message data"
        }
    }
}

