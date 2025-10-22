//
//  ConversationRowView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// A row view displaying a single conversation in the list
struct ConversationRowView: View {
    // MARK: - Properties
    
    let conversation: Conversation
    let currentUserId: String
    let unreadCount: Int
    let userPresenceMap: [String: Bool]
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image with online status
            ProfileImageView(
                imageUrl: profileImageUrl,
                displayName: displayName,
                size: Constants.Dimensions.profileImageMedium,
                isGroup: conversation.type == .group
            )
            .onlineStatusIndicator(
                isOnline: isOnline,
                show: conversation.type == .direct && isOnline
            )
            
            // Conversation info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Timestamp
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.timestamp.smartTimestamp())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    // Last message preview
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessagePreview(lastMessage))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    // Unread badge or read receipt
                    if unreadCount > 0 {
                        unreadBadge
                    } else if showReadReceipt {
                        readReceiptIndicator
                    }
                }
            }
        }
        .padding(.vertical, Constants.Dimensions.rowSpacing)
        .contentShape(Rectangle())
    }
    
    // MARK: - Subviews
    
    /// Unread message badge
    private var unreadBadge: some View {
        Text(badgeText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: Constants.Dimensions.unreadBadgeSize, minHeight: Constants.Dimensions.unreadBadgeSize)
            .background(
                Capsule()
                    .fill(Constants.Colors.unreadBadge)
            )
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.2), value: unreadCount)
    }
    
    /// Read receipt indicator (double checkmark)
    private var readReceiptIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(Constants.Colors.statusRead)
    }
    
    // MARK: - Computed Properties
    
    /// Display name for the conversation
    private var displayName: String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else {
            // Direct conversation - get other participant's name
            let otherParticipant = conversation.participants.first { $0.key != currentUserId }
            
            // Check if we have participant info
            if let displayName = otherParticipant?.value.displayName,
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return displayName
            }
            
            // Fallback: Try to get from participantIds if participant info is missing
            // This provides a better UX while participant info is being loaded
            if let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }),
               !otherUserId.isEmpty {
                // Show loading state instead of "Unknown User"
                return "Loading..."
            }
            
            return "Unknown User"
        }
    }
    
    /// Profile image URL
    private var profileImageUrl: String? {
        if conversation.type == .group {
            return conversation.groupImageUrl
        } else {
            // Direct conversation - get other participant's image
            let otherParticipant = conversation.participants.first { $0.key != currentUserId }
            return otherParticipant?.value.profileImageUrl
        }
    }
    
    /// Whether the other participant is online (only for direct chats)
    private var isOnline: Bool {
        // Only check for direct chats
        guard conversation.type == .direct else { return false }
        
        // Get the other participant's ID
        guard let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else {
            return false
        }
        
        // Look up their online status in the presence map
        return userPresenceMap[otherUserId] ?? false
    }
    
    /// Badge text to display (handles "99+" logic)
    private var badgeText: String {
        if unreadCount > 99 {
            return "99+"
        }
        return "\(unreadCount)"
    }
    
    /// Horizontal padding for badge (more padding for multi-digit numbers)
    private var horizontalPadding: CGFloat {
        if unreadCount > 99 {
            return 6  // "99+" needs more padding
        } else if unreadCount > 9 {
            return 5  // Two digits need some padding
        } else {
            return 0  // Single digit uses minimum width (circle shape)
        }
    }
    
    /// Whether to show read receipt indicator
    private var showReadReceipt: Bool {
        guard let lastMessage = conversation.lastMessage else {
            return false
        }
        
        // Show read receipt if current user sent the last message
        return lastMessage.senderId == currentUserId
    }
    
    /// Last message preview text
    private func lastMessagePreview(_ lastMessage: Conversation.LastMessage) -> String {
        // For group chats, always show sender name prefix
        if conversation.type == .group {
            let isFromCurrentUser = lastMessage.senderId.trimmingCharacters(in: .whitespacesAndNewlines) == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix: String
            
            if isFromCurrentUser {
                prefix = "You: "
            } else {
                let senderName = lastMessage.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
                prefix = senderName.isEmpty ? "" : "\(senderName): "
            }
            
            return prefix + lastMessage.text
        } else {
            // For direct chats, don't show any prefix (it's obvious who sent what in 1-on-1 chats)
            return lastMessage.text
        }
    }
}

// MARK: - Preview

#Preview("Direct Conversations") {
    List {
        ConversationRowView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "John Doe",
                        profileImageUrl: nil
                    ),
                    "user2": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "Hey, how are you doing?",
                    senderId: "user1",
                    senderName: "John Doe",
                    timestamp: Date().addingTimeInterval(-300)
                ),
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-300)
            ),
            currentUserId: "user2",
            unreadCount: 3,
            userPresenceMap: ["user1": true] // John Doe is online
        )
        
        ConversationRowView(
            conversation: Conversation(
                id: "2",
                type: .direct,
                participantIds: ["user1", "user3"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "Jane Smith",
                        profileImageUrl: nil
                    ),
                    "user3": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "See you tomorrow!",
                    senderId: "user3",
                    senderName: "Current User",
                    timestamp: Date().addingTimeInterval(-3600)
                ),
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date().addingTimeInterval(-3600)
            ),
            currentUserId: "user3",
            unreadCount: 0,
            userPresenceMap: ["user1": false] // Jane Smith is offline
        )
        
        ConversationRowView(
            conversation: Conversation(
                id: "3",
                type: .direct,
                participantIds: ["user1", "user4"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "Bob Martinez",
                        profileImageUrl: nil
                    ),
                    "user4": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: nil,
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            ),
            currentUserId: "user4",
            unreadCount: 150,
            userPresenceMap: [:] // No presence data
        )
    }
    .listStyle(.plain)
}

#Preview("Group Conversations") {
    List {
        ConversationRowView(
            conversation: Conversation(
                id: "4",
                type: .group,
                participantIds: ["user1", "user2", "user3"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "Alice",
                        profileImageUrl: nil
                    ),
                    "user2": Conversation.ParticipantInfo(
                        displayName: "Bob",
                        profileImageUrl: nil
                    ),
                    "user3": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "Sprint planning meeting at 3pm",
                    senderId: "user1",
                    senderName: "Alice",
                    timestamp: Date().addingTimeInterval(-600)
                ),
                groupName: "Engineering Team",
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date().addingTimeInterval(-600)
            ),
            currentUserId: "user3",
            unreadCount: 12,
            userPresenceMap: [:] // Groups don't show presence
        )
        
        ConversationRowView(
            conversation: Conversation(
                id: "5",
                type: .group,
                participantIds: ["user1", "user2", "user3", "user4"],
                participants: [:],
                lastMessage: Conversation.LastMessage(
                    text: "You: Great idea! Let's do it.",
                    senderId: "user3",
                    senderName: "Current User",
                    timestamp: Date().addingTimeInterval(-7200)
                ),
                groupName: "Project Alpha",
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-259200),
                updatedAt: Date().addingTimeInterval(-7200)
            ),
            currentUserId: "user3",
            unreadCount: 0,
            userPresenceMap: [:] // Groups don't show presence
        )
    }
    .listStyle(.plain)
}

#Preview("Mixed Timestamps") {
    List {
        ConversationRowView(
            conversation: Conversation(
                id: "6",
                type: .direct,
                participantIds: ["user1", "user2"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "Just Now",
                        profileImageUrl: nil
                    ),
                    "user2": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "This was sent just now",
                    senderId: "user1",
                    senderName: "Just Now",
                    timestamp: Date()
                ),
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            currentUserId: "user2",
            unreadCount: 1,
            userPresenceMap: ["user1": true]
        )
        
        ConversationRowView(
            conversation: Conversation(
                id: "7",
                type: .direct,
                participantIds: ["user1", "user2"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "5 Minutes Ago",
                        profileImageUrl: nil
                    ),
                    "user2": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "Sent 5 minutes ago",
                    senderId: "user1",
                    senderName: "5 Minutes Ago",
                    timestamp: Date().addingTimeInterval(-300)
                ),
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-300),
                updatedAt: Date().addingTimeInterval(-300)
            ),
            currentUserId: "user2",
            unreadCount: 42,
            userPresenceMap: ["user1": true]
        )
        
        ConversationRowView(
            conversation: Conversation(
                id: "8",
                type: .direct,
                participantIds: ["user1", "user2"],
                participants: [
                    "user1": Conversation.ParticipantInfo(
                        displayName: "Yesterday",
                        profileImageUrl: nil
                    ),
                    "user2": Conversation.ParticipantInfo(
                        displayName: "Current User",
                        profileImageUrl: nil
                    )
                ],
                lastMessage: Conversation.LastMessage(
                    text: "Message from yesterday",
                    senderId: "user1",
                    senderName: "Yesterday",
                    timestamp: Date().addingTimeInterval(-86400)
                ),
                groupName: nil,
                groupImageUrl: nil,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            ),
            currentUserId: "user2",
            unreadCount: 0,
            userPresenceMap: ["user1": false]
        )
    }
    .listStyle(.plain)
}

