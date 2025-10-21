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
    
    /// Send a message in a conversation
    func sendMessage(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String
    ) async throws -> String {
        let message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            status: .sent,
            readBy: [senderId], // Sender has read their own message
            deliveredTo: [],
            localId: nil
        )
        
        // Add message to Firestore
        let docRef = try db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .addDocument(from: message)
        
        // Update conversation's last message
        var savedMessage = message
        savedMessage.id = docRef.documentID
        try await conversationService.updateLastMessage(conversationId: conversationId, message: savedMessage)
        
        return docRef.documentID
    }
    
    /// Send a message with optimistic UI (returns temporary ID)
    func sendMessageOptimistic(
        conversationId: String,
        text: String,
        senderId: String,
        senderName: String,
        localId: String
    ) async throws -> String {
        let message = Message(
            id: nil,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            status: .sending,
            readBy: [senderId],
            deliveredTo: [],
            localId: localId
        )
        
        // Add message to Firestore
        let docRef = try db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .addDocument(from: message)
        
        // Update message status to sent
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .document(docRef.documentID)
            .updateData([
                "status": MessageStatus.sent.rawValue
            ])
        
        // Update conversation's last message
        var sentMessage = message
        sentMessage.id = docRef.documentID
        sentMessage.status = .sent
        try await conversationService.updateLastMessage(conversationId: conversationId, message: sentMessage)
        
        return docRef.documentID
    }
    
    // MARK: - Read Messages
    
    /// Get messages for a conversation with pagination
    func getMessages(conversationId: String, limit: Int = Constants.Pagination.messagesPerPage) async throws -> [Message] {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
    }
    
    /// Get older messages before a specific timestamp
    func getMessagesBefore(conversationId: String, beforeDate: Date, limit: Int = Constants.Pagination.messagesPerPage) async throws -> [Message] {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .end(before: [beforeDate])
            .limit(toLast: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
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
    
    /// Mark messages as read
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
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

