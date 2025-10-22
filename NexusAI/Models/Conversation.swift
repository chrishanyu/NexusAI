//
//  Conversation.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/21/25.
//

import Foundation
import FirebaseFirestore

enum ConversationType: String, Codable {
    case direct
    case group
}

struct Conversation: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let type: ConversationType
    let participantIds: [String]
    var participants: [String: ParticipantInfo] // userId -> info
    var lastMessage: LastMessage?
    var groupName: String?
    var groupImageUrl: String?
    let createdAt: Date
    var updatedAt: Date? // Optional to handle null values from Firestore
    
    // Client-side only - not stored in Firestore
    var unreadCount: Int = 0
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case participantIds
        case participants
        case lastMessage
        case groupName
        case groupImageUrl
        case createdAt
        case updatedAt
        // unreadCount is intentionally excluded - it's client-side only
    }
    
    struct ParticipantInfo: Codable, Hashable {
        let displayName: String
        let profileImageUrl: String?
    }
    
    struct LastMessage: Codable, Hashable {
        let text: String
        let senderId: String
        let senderName: String
        let timestamp: Date
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}
