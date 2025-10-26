//
//  Priority.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import SwiftUI

/// Priority level for action items
enum Priority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    /// Color representation for the priority
    var color: Color {
        switch self {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }
    
    /// SF Symbol icon name for the priority
    var icon: String {
        switch self {
        case .high:
            return "exclamationmark.circle.fill"
        case .medium:
            return "circle.fill"
        case .low:
            return "circle"
        }
    }
    
    /// Display name for the priority
    var displayName: String {
        switch self {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
}

