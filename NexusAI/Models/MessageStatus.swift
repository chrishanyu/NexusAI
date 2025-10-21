//
//  MessageStatus.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/21/25.
//

import Foundation

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
    
    var description: String {
        switch self {
        case .sending:
            return "Sending..."
        case .sent:
            return "Sent"
        case .delivered:
            return "Delivered"
        case .read:
            return "Read"
        case .failed:
            return "Failed"
        }
    }
}
