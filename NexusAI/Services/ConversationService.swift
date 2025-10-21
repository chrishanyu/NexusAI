//
//  ConversationService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseFirestore

/// Service for conversation CRUD operations and real-time listeners
class ConversationService {
    
    // MARK: - Properties
    private let db = FirebaseService.shared.db
    
    // MARK: - Create Conversations
    
    /// Create a direct conversation between two users
    func createDirectConversation(userId: String, otherUserId: String, otherUserInfo: Conversation.ParticipantInfo) async throws -> Conversation {
        // Check if conversation already exists
        if let existingConversation = try await findExistingDirectConversation(userId: userId, otherUserId: otherUserId) {
            return existingConversation
        }
        
        // Get current user info
        let authService = AuthService()
        let currentUser = try await authService.getUserProfile(userId: userId)
        
        let currentUserInfo = Conversation.ParticipantInfo(
            displayName: currentUser.displayName,
            profileImageUrl: currentUser.profileImageUrl
        )
        
        // Create new conversation
        let conversation = Conversation(
            id: nil,
            type: .direct,
            participantIds: [userId, otherUserId],
            participants: [
                userId: currentUserInfo,
                otherUserId: otherUserInfo
            ],
            lastMessage: nil,
            groupName: nil,
            groupImageUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let docRef = try db.collection(Constants.Collections.conversations)
            .addDocument(from: conversation)
        
        var createdConversation = conversation
        createdConversation.id = docRef.documentID
        
        return createdConversation
    }
    
    /// Create a group conversation
    func createGroupConversation(
        creatorId: String,
        participantIds: [String],
        participantsInfo: [String: Conversation.ParticipantInfo],
        groupName: String?
    ) async throws -> Conversation {
        // Ensure creator is included
        var allParticipantIds = Set(participantIds)
        allParticipantIds.insert(creatorId)
        
        let conversation = Conversation(
            id: nil,
            type: .group,
            participantIds: Array(allParticipantIds),
            participants: participantsInfo,
            lastMessage: nil,
            groupName: groupName,
            groupImageUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let docRef = try db.collection(Constants.Collections.conversations)
            .addDocument(from: conversation)
        
        var createdConversation = conversation
        createdConversation.id = docRef.documentID
        
        return createdConversation
    }
    
    // MARK: - Helper Methods
    
    /// Get existing direct conversation or create a new one
    /// This is a convenience method that combines find and create logic
    func getOrCreateDirectConversation(participantIds: [String]) async throws -> Conversation {
        guard participantIds.count == 2 else {
            throw ConversationError.insufficientParticipants
        }
        
        let userId = participantIds[0]
        let otherUserId = participantIds[1]
        
        // Check if conversation already exists
        if let existingConversation = try await findExistingDirectConversation(userId: userId, otherUserId: otherUserId) {
            return existingConversation
        }
        
        // Get user info for other participant
        let authService = AuthService()
        let otherUser = try await authService.getUserProfile(userId: otherUserId)
        
        let otherUserInfo = Conversation.ParticipantInfo(
            displayName: otherUser.displayName,
            profileImageUrl: otherUser.profileImageUrl
        )
        
        // Create new conversation (createDirectConversation will fetch current user info)
        return try await createDirectConversation(
            userId: userId,
            otherUserId: otherUserId,
            otherUserInfo: otherUserInfo
        )
    }
    
    // MARK: - Read Conversations
    
    /// Get conversations for a specific user
    func getConversations(userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Conversation.self) }
    }
    
    /// Get a specific conversation by ID
    func getConversation(conversationId: String) async throws -> Conversation {
        let document = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .getDocument()
        
        guard document.exists else {
            throw ConversationError.conversationNotFound
        }
        
        return try document.data(as: Conversation.self)
    }
    
    /// Find existing direct conversation between two users
    private func findExistingDirectConversation(userId: String, otherUserId: String) async throws -> Conversation? {
        let snapshot = try await db.collection(Constants.Collections.conversations)
            .whereField("type", isEqualTo: ConversationType.direct.rawValue)
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        
        // Filter to find conversation with both users
        let conversation = snapshot.documents
            .compactMap { try? $0.data(as: Conversation.self) }
            .first { conversation in
                conversation.participantIds.contains(userId) &&
                conversation.participantIds.contains(otherUserId) &&
                conversation.participantIds.count == 2
            }
        
        return conversation
    }
    
    // MARK: - Update Conversations
    
    /// Update conversation's last message
    func updateLastMessage(conversationId: String, message: Message) async throws {
        let lastMessage = Conversation.LastMessage(
            text: message.text,
            senderId: message.senderId,
            senderName: message.senderName,
            timestamp: message.timestamp
        )
        
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .updateData([
                "lastMessage": try Firestore.Encoder().encode(lastMessage),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    /// Update group name
    func updateGroupName(conversationId: String, groupName: String) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .updateData([
                "groupName": groupName,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    /// Update group image
    func updateGroupImage(conversationId: String, imageUrl: String) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .updateData([
                "groupImageUrl": imageUrl,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    /// Add participant to group conversation
    func addParticipant(conversationId: String, userId: String, userInfo: Conversation.ParticipantInfo) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .updateData([
                "participantIds": FieldValue.arrayUnion([userId]),
                "participants.\(userId)": try Firestore.Encoder().encode(userInfo),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    /// Remove participant from group conversation
    func removeParticipant(conversationId: String, userId: String) async throws {
        try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .updateData([
                "participantIds": FieldValue.arrayRemove([userId]),
                "participants.\(userId)": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    // MARK: - Real-Time Listeners
    
    /// Listen to conversations for a specific user
    func listenToConversations(userId: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching conversations: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let conversations = documents.compactMap { try? $0.data(as: Conversation.self) }
                onChange(conversations)
            }
    }
    
    /// Listen to a specific conversation
    func listenToConversation(conversationId: String, onChange: @escaping (Conversation?) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .addSnapshotListener { document, error in
                guard let document = document, document.exists else {
                    onChange(nil)
                    return
                }
                
                let conversation = try? document.data(as: Conversation.self)
                onChange(conversation)
            }
    }
    
    // MARK: - Delete Conversation
    
    /// Delete a conversation (soft delete - remove user from participants)
    func leaveConversation(conversationId: String, userId: String) async throws {
        let conversation = try await getConversation(conversationId: conversationId)
        
        if conversation.type == .direct {
            // For direct chats, mark as deleted for this user (could use a separate field)
            // For MVP, we'll just leave it as is
            return
        } else {
            // For groups, remove the participant
            try await removeParticipant(conversationId: conversationId, userId: userId)
        }
    }
}

// MARK: - Conversation Errors
enum ConversationError: LocalizedError {
    case conversationNotFound
    case invalidConversationType
    case insufficientParticipants
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return "Conversation not found"
        case .invalidConversationType:
            return "Invalid conversation type"
        case .insufficientParticipants:
            return "Not enough participants for conversation"
        case .unauthorized:
            return "Not authorized to access this conversation"
        }
    }
}

