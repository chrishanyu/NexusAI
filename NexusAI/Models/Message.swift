//
//  Message.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/21/25.
//

import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    let conversationId: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
    var status: MessageStatus
    var readBy: [String]
    var deliveredTo: [String]
    var localId: String? // For optimistic UI updates
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case senderName
        case text
        case timestamp
        case status
        case readBy
        case deliveredTo
        case localId
    }
}
