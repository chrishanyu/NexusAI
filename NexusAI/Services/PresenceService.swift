//
//  PresenceService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseFirestore

/// Service for managing user presence (online/offline) and typing indicators
class PresenceService {
    
    // MARK: - Properties
    private let db = FirebaseService.shared.db
    private var typingTimers: [String: Timer] = [:]
    
    // MARK: - Presence Management
    
    /// Update user's online status
    func updatePresence(userId: String, isOnline: Bool) async throws {
        try await db.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ])
    }
    
    /// Set user online
    func setUserOnline(userId: String) async throws {
        try await updatePresence(userId: userId, isOnline: true)
    }
    
    /// Set user offline
    func setUserOffline(userId: String) async throws {
        try await updatePresence(userId: userId, isOnline: false)
    }
    
    /// Listen to user presence changes
    func listenToPresence(userId: String, onChange: @escaping (Bool, Date?) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.users)
            .document(userId)
            .addSnapshotListener { document, error in
                guard let document = document, document.exists else {
                    onChange(false, nil)
                    return
                }
                
                let isOnline = document.data()?["isOnline"] as? Bool ?? false
                let lastSeen = (document.data()?["lastSeen"] as? Timestamp)?.dateValue()
                
                onChange(isOnline, lastSeen)
            }
    }
    
    /// Listen to multiple users' presence
    func listenToMultiplePresence(userIds: [String], onChange: @escaping ([String: Bool]) -> Void) -> ListenerRegistration {
        // Limit to 10 users for Firestore 'in' query
        let limitedUserIds = Array(userIds.prefix(10))
        
        return db.collection(Constants.Collections.users)
            .whereField(FieldPath.documentID(), in: limitedUserIds)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange([:])
                    return
                }
                
                var presenceMap: [String: Bool] = [:]
                for document in documents {
                    let userId = document.documentID
                    let isOnline = document.data()["isOnline"] as? Bool ?? false
                    presenceMap[userId] = isOnline
                }
                
                onChange(presenceMap)
            }
    }
    
    // MARK: - Typing Indicators
    
    /// Set typing indicator for a conversation
    func setTyping(conversationId: String, userId: String, userName: String, isTyping: Bool) async throws {
        let typingIndicator = TypingIndicator(
            id: "\(conversationId)_\(userId)",
            conversationId: conversationId,
            userId: userId,
            userName: userName,
            isTyping: isTyping,
            timestamp: Date()
        )
        
        // Use document ID as combination of conversationId and userId for easy querying
        try db.collection(Constants.Collections.typingIndicators)
            .document(typingIndicator.id ?? "")
            .setData(from: typingIndicator)
        
        // If typing, set a timer to auto-expire after 3 seconds
        if isTyping {
            invalidateTypingTimer(for: conversationId, userId: userId)
            
            let timer = Timer.scheduledTimer(withTimeInterval: Constants.Timeouts.typingIndicatorDuration, repeats: false) { [weak self] _ in
                Task {
                    try? await self?.setTyping(conversationId: conversationId, userId: userId, userName: userName, isTyping: false)
                }
            }
            
            typingTimers["\(conversationId)_\(userId)"] = timer
        } else {
            invalidateTypingTimer(for: conversationId, userId: userId)
        }
    }
    
    /// Start typing (helper method)
    func startTyping(conversationId: String, userId: String, userName: String) async throws {
        try await setTyping(conversationId: conversationId, userId: userId, userName: userName, isTyping: true)
    }
    
    /// Stop typing (helper method)
    func stopTyping(conversationId: String, userId: String, userName: String) async throws {
        try await setTyping(conversationId: conversationId, userId: userId, userName: userName, isTyping: false)
    }
    
    /// Listen to typing indicators in a conversation
    func listenToTypingIndicators(conversationId: String, currentUserId: String, onChange: @escaping ([TypingIndicator]) -> Void) -> ListenerRegistration {
        return db.collection(Constants.Collections.typingIndicators)
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("isTyping", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                
                // Filter out current user and expired indicators
                let expirationTime = Date().addingTimeInterval(-Constants.Timeouts.typingIndicatorDuration)
                
                let typingIndicators = documents
                    .compactMap { try? $0.data(as: TypingIndicator.self) }
                    .filter { indicator in
                        indicator.userId != currentUserId &&
                        indicator.timestamp > expirationTime
                    }
                
                onChange(typingIndicators)
            }
    }
    
    /// Clean up expired typing indicators
    func cleanupExpiredTypingIndicators() async throws {
        let expirationTime = Date().addingTimeInterval(-Constants.Timeouts.typingIndicatorDuration)
        
        let snapshot = try await db.collection(Constants.Collections.typingIndicators)
            .whereField("timestamp", isLessThan: expirationTime)
            .getDocuments()
        
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Helper Methods
    
    private func invalidateTypingTimer(for conversationId: String, userId: String) {
        let key = "\(conversationId)_\(userId)"
        typingTimers[key]?.invalidate()
        typingTimers.removeValue(forKey: key)
    }
    
    /// Clean up all typing timers (call on deinit)
    func cleanup() {
        typingTimers.values.forEach { $0.invalidate() }
        typingTimers.removeAll()
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Presence Errors
enum PresenceError: LocalizedError {
    case updateFailed
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .updateFailed:
            return "Failed to update presence"
        case .userNotFound:
            return "User not found"
        }
    }
}

