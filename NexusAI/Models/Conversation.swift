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

struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    let type: ConversationType
    let participantIds: [String]
    var participants: [String: ParticipantInfo] // userId -> info
    var lastMessage: LastMessage?
    var groupName: String?
    var groupImageUrl: String?
    let createdAt: Date
    var updatedAt: Date
    
    struct ParticipantInfo: Codable {
        let displayName: String
        let profileImageUrl: String?
    }
    
    struct LastMessage: Codable {
        let text: String
        let senderId: String
        let senderName: String
        let timestamp: Date
    }
}
