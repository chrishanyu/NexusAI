//
//  User.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/21/25.
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let googleId: String
    let email: String
    var displayName: String
    var profileImageUrl: String?
    var isOnline: Bool
    var lastSeen: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case googleId
        case email
        case displayName
        case profileImageUrl
        case isOnline
        case lastSeen
        case createdAt
    }
}
