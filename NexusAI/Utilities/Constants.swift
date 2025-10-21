import SwiftUI

struct Constants {

    // MARK: - Firestore Collections
    struct Collections {
        static let users = "users"
        static let conversations = "conversations"
        static let messages = "messages"
        static let typingIndicators = "typingIndicators"
    }

    // MARK: - Colors
    struct Colors {
        static let primaryBlue = Color(hex: "#007AFF")
        static let sentMessageBubble = Color(hex: "#007AFF")
        static let receivedMessageBubble = Color(hex: "#E5E5EA")
        static let background = Color(hex: "#F2F2F7")
        static let onlineGreen = Color(hex: "#34C759")
        static let offlineGray = Color(hex: "#8E8E93")
    }

    // MARK: - Notification Keys
    struct NotificationKeys {
        static let conversationId = "conversationId"
        static let senderId = "senderId"
        static let messageType = "type"
    }

    // MARK: - Timeouts
    struct Timeouts {
        static let typingIndicatorDuration: TimeInterval = 3.0
        static let typingDebounceInterval: TimeInterval = 0.5
        static let presenceGracePeriod: TimeInterval = 5.0
    }

    // MARK: - Pagination
    struct Pagination {
        static let messagesPerPage = 50
        static let conversationsPerPage = 20
    }

    // MARK: - App Info
    struct App {
        static let name = "Nexus"
        static let version = "1.0.0"
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
