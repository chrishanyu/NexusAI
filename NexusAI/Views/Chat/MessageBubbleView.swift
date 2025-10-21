//
//  MessageBubbleView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// View that displays a message bubble with proper styling based on sender
struct MessageBubbleView: View {
    // MARK: - Properties
    
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    var onRetry: ((String) -> Void)? = nil // Callback for retry action
    
    // MARK: - Initialization
    
    init(message: Message, isFromCurrentUser: Bool, showSenderName: Bool = false, onRetry: ((String) -> Void)? = nil) {
        self.message = message
        self.isFromCurrentUser = isFromCurrentUser
        self.showSenderName = showSenderName
        self.onRetry = onRetry
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50) // Limit bubble width to 75% of screen
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (for group chats)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Message bubble
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Constants.Dimensions.messageBubblePaddingHorizontal)
                .padding(.vertical, Constants.Dimensions.messageBubblePaddingVertical)
                .background(bubbleColor)
                .cornerRadius(Constants.Dimensions.messageBubbleCornerRadius)
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(message.timestamp.smartTimestamp())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        if message.status == .failed {
                            // Show retry button for failed messages
                            Button(action: {
                                if let localId = message.localId {
                                    onRetry?(localId)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: Constants.Dimensions.messageStatusIconSize))
                                    Text("Tap to retry")
                                }
                                .foregroundColor(Constants.Colors.statusFailed)
                            }
                        } else {
                            MessageStatusView(status: message.status)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50) // Limit bubble width to 75% of screen
            }
        }
        .padding(.horizontal, Constants.Dimensions.screenPadding)
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    /// Background color based on sender
    private var bubbleColor: Color {
        isFromCurrentUser ? Constants.Colors.sentMessageBubble : Constants.Colors.receivedMessageBubble
    }
    
    /// Text color based on sender
    private var textColor: Color {
        isFromCurrentUser ? Constants.Colors.sentMessageText : Constants.Colors.receivedMessageText
    }
}

// MARK: - Preview

#Preview("Sent Messages") {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Current User",
                text: "Hey, how are you?",
                timestamp: Date().addingTimeInterval(-300),
                status: .read,
                readBy: ["user1", "user2"],
                deliveredTo: ["user1", "user2"],
                localId: nil
            ),
            isFromCurrentUser: true
        )
        
        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Current User",
                text: "This is a much longer message that will wrap to multiple lines to test how the bubble looks with more content. It should maintain proper padding and formatting.",
                timestamp: Date().addingTimeInterval(-200),
                status: .delivered,
                readBy: ["user1"],
                deliveredTo: ["user1", "user2"],
                localId: nil
            ),
            isFromCurrentUser: true
        )
        
        MessageBubbleView(
            message: Message(
                id: "3",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Current User",
                text: "Sending...",
                timestamp: Date(),
                status: .sending,
                readBy: ["user1"],
                deliveredTo: [],
                localId: "temp123"
            ),
            isFromCurrentUser: true
        )
    }
    .padding(.vertical)
    .background(Color.gray.opacity(0.1))
}

#Preview("Received Messages") {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user2",
                senderName: "Alice",
                text: "Hi there!",
                timestamp: Date().addingTimeInterval(-400),
                status: .sent,
                readBy: ["user2"],
                deliveredTo: ["user1", "user2"],
                localId: nil
            ),
            isFromCurrentUser: false
        )
        
        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                senderName: "Alice",
                text: "This is my response with a longer message. It should also wrap properly and look good with the gray background.",
                timestamp: Date().addingTimeInterval(-100),
                status: .sent,
                readBy: ["user2"],
                deliveredTo: ["user1", "user2"],
                localId: nil
            ),
            isFromCurrentUser: false
        )
    }
    .padding(.vertical)
    .background(Color.gray.opacity(0.1))
}

#Preview("Group Chat with Names") {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user2",
                senderName: "Alice",
                text: "Hey everyone!",
                timestamp: Date().addingTimeInterval(-600),
                status: .sent,
                readBy: ["user2"],
                deliveredTo: ["user1", "user2", "user3"],
                localId: nil
            ),
            isFromCurrentUser: false,
            showSenderName: true
        )
        
        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user3",
                senderName: "Bob",
                text: "Hi Alice!",
                timestamp: Date().addingTimeInterval(-500),
                status: .sent,
                readBy: ["user3"],
                deliveredTo: ["user1", "user2", "user3"],
                localId: nil
            ),
            isFromCurrentUser: false,
            showSenderName: true
        )
        
        MessageBubbleView(
            message: Message(
                id: "3",
                conversationId: "conv1",
                senderId: "user1",
                senderName: "Current User",
                text: "Hello team!",
                timestamp: Date().addingTimeInterval(-400),
                status: .read,
                readBy: ["user1", "user2", "user3"],
                deliveredTo: ["user1", "user2", "user3"],
                localId: nil
            ),
            isFromCurrentUser: true,
            showSenderName: false // Own messages don't show name
        )
    }
    .padding(.vertical)
    .background(Color.gray.opacity(0.1))
}

#Preview("Conversation Flow") {
    ScrollView {
        VStack(spacing: 8) {
            MessageBubbleView(
                message: Message(
                    id: "1",
                    conversationId: "conv1",
                    senderId: "user2",
                    senderName: "Alice",
                    text: "Hey, want to grab lunch?",
                    timestamp: Date().addingTimeInterval(-3600),
                    status: .sent,
                    readBy: ["user1", "user2"],
                    deliveredTo: ["user1", "user2"],
                    localId: nil
                ),
                isFromCurrentUser: false
            )
            
            MessageBubbleView(
                message: Message(
                    id: "2",
                    conversationId: "conv1",
                    senderId: "user1",
                    senderName: "Current User",
                    text: "Sure! Where do you want to go?",
                    timestamp: Date().addingTimeInterval(-3500),
                    status: .read,
                    readBy: ["user1", "user2"],
                    deliveredTo: ["user1", "user2"],
                    localId: nil
                ),
                isFromCurrentUser: true
            )
            
            MessageBubbleView(
                message: Message(
                    id: "3",
                    conversationId: "conv1",
                    senderId: "user2",
                    senderName: "Alice",
                    text: "How about that new Italian place downtown?",
                    timestamp: Date().addingTimeInterval(-3400),
                    status: .sent,
                    readBy: ["user1", "user2"],
                    deliveredTo: ["user1", "user2"],
                    localId: nil
                ),
                isFromCurrentUser: false
            )
            
            MessageBubbleView(
                message: Message(
                    id: "4",
                    conversationId: "conv1",
                    senderId: "user1",
                    senderName: "Current User",
                    text: "Perfect! See you at noon 👍",
                    timestamp: Date().addingTimeInterval(-3300),
                    status: .delivered,
                    readBy: ["user1"],
                    deliveredTo: ["user1", "user2"],
                    localId: nil
                ),
                isFromCurrentUser: true
            )
        }
    }
    .background(Color.gray.opacity(0.1))
}

