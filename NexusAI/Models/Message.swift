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
    
    /// Computed display status based on readBy and deliveredTo arrays
    /// This provides real-time status based on recipient interactions
    var displayStatus: MessageStatus {
        // If message is still sending or failed, use stored status
        if status == .sending || status == .failed {
            return status
        }
        
        // Check if message has been read by anyone other than sender
        if readBy.contains(where: { $0 != senderId }) {
            return .read
        }
        
        // Check if message has been delivered to anyone other than sender
        if deliveredTo.contains(where: { $0 != senderId }) {
            return .delivered
        }
        
        // If message has Firestore ID but not delivered yet, it's sent
        if id != nil {
            return .sent
        }
        
        // Fallback to stored status
        return status
    }
}
