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
        // Primary colors
        static let primaryBlue = Color(hex: "#007AFF")
        static let background = Color(hex: "#F2F2F7")
        
        // Message bubble colors
        static let sentMessageBubble = Color(hex: "#007AFF")
        static let sentMessageText = Color.white
        static let receivedMessageBubble = Color(hex: "#E5E5EA")
        static let receivedMessageText = Color.black
        
        // Status indicator colors
        static let onlineGreen = Color(hex: "#34C759")
        static let offlineGray = Color(hex: "#8E8E93")
        static let statusSending = Color.gray
        static let statusSent = Color.gray
        static let statusDelivered = Color.gray
        static let statusRead = Color(hex: "#007AFF")
        static let statusFailed = Color.red
        
        // UI element colors
        static let unreadBadge = Color.red
        static let offlineBanner = Color(hex: "#FFCC00")
        static let divider = Color.gray.opacity(0.3)
    }

    // MARK: - Dimensions
    struct Dimensions {
        // Message bubbles
        static let messageBubbleCornerRadius: CGFloat = 16
        static let messageBubblePaddingVertical: CGFloat = 12
        static let messageBubblePaddingHorizontal: CGFloat = 16
        static let messageBubbleMaxWidth: CGFloat = 0.75 // 75% of screen width
        static let messageBubbleTailSize: CGFloat = 8
        
        // Profile images
        static let profileImageLarge: CGFloat = 100
        static let profileImageMedium: CGFloat = 50
        static let profileImageSmall: CGFloat = 44
        static let profileImageTiny: CGFloat = 30
        
        // Status indicators
        static let onlineStatusDot: CGFloat = 8
        static let onlineStatusBorder: CGFloat = 2
        
        // Input bar
        static let messageInputHeight: CGFloat = 36
        static let sendButtonSize: CGFloat = 36
        static let messageInputMaxLines: Int = 4
        
        // Icons
        static let messageStatusIconSize: CGFloat = 14 // Subtle but visible (was 12, debug was 20)
        static let fabButtonSize: CGFloat = 56
        static let unreadBadgeSize: CGFloat = 20
        
        // Spacing
        static let rowSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        static let screenPadding: CGFloat = 16
        
        // Auto-scroll threshold
        static let autoScrollThreshold: CGFloat = 100
    }
    
    // MARK: - Animation
    struct Animation {
        static let messageSend: Double = 0.2
        static let messageAppear: Double = 0.3
        static let bubbleFade: Double = 0.15
        static let statusUpdate: Double = 0.2
        static let scrollToBottom: Double = 0.3
        static let errorDismiss: TimeInterval = 5.0
        static let typingDots: Double = 0.6
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
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        /// Enable local-first sync framework (SwiftData + Repository pattern)
        /// Set to false to use legacy Firebase direct access
        static let isLocalFirstSyncEnabled = true
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

// MARK: - Notification Name Extensions
extension Notification.Name {
    /// Notification to scroll Chat tab to top or pop navigation if in child view
    static let scrollToTopChatTab = Notification.Name("scrollToTopChatTab")
    
    /// Notification to scroll Profile tab to top
    static let scrollToTopProfileTab = Notification.Name("scrollToTopProfileTab")
    
    /// Notification to scroll Nexus tab to top
    static let scrollToTopAITab = Notification.Name("scrollToTopAITab")
    
    /// Notification to jump to a specific message in a conversation (from Nexus source tap)
    static let jumpToMessage = Notification.Name("jumpToMessage")
    
    /// Notification to scroll to a specific message in ChatView (contains messageId as object)
    static let scrollToMessageInChat = Notification.Name("scrollToMessageInChat")
    
    /// Notification to switch to Chat tab
    static let switchToChatTab = Notification.Name("switchToChatTab")
    
    /// Keyboard notifications
    static let keyboardWillShow = UIResponder.keyboardWillShowNotification
    static let keyboardWillHide = UIResponder.keyboardWillHideNotification
}
