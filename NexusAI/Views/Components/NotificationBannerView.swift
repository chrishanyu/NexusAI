//
//  NotificationBannerView.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import SwiftUI

/// In-app notification banner that appears at the top of the screen
struct NotificationBannerView: View {
    
    // MARK: - Properties
    
    /// Banner data to display
    let banner: BannerData
    
    /// Callback for when banner is tapped
    var onTap: () -> Void
    
    /// Callback for when banner is dismissed via swipe
    var onDismiss: () -> Void
    
    // MARK: - State
    
    /// Track drag offset for swipe gesture
    @State private var dragOffset: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture on the left
            ProfileImageView(
                imageUrl: banner.profileImageUrl,
                displayName: banner.senderName,
                size: 40,
                isGroup: false
            )
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                // Sender name
                Text(banner.senderName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Message preview
                Text(banner.displayText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .opacity(0.95)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow upward swipes
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    // Dismiss if swiped up more than 50 points
                    if value.translation.height < -50 {
                        withAnimation(.easeOut(duration: 0.25)) {
                            dragOffset = -200 // Animate off screen
                        }
                        
                        // Call dismiss after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onDismiss()
                        }
                    } else {
                        // Reset to original position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

#Preview("Direct Message Banner") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            NotificationBannerView(
                banner: BannerData(
                    conversationId: "conv_123",
                    senderId: "user_456",
                    senderName: "Alice Johnson",
                    messageText: "Hey! Can you review the document I sent over?",
                    profileImageUrl: nil,
                    timestamp: Date()
                ),
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            
            Spacer()
        }
    }
}

#Preview("Long Message Text") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            NotificationBannerView(
                banner: BannerData(
                    conversationId: "conv_123",
                    senderId: "user_789",
                    senderName: "Bob Smith",
                    messageText: "This is a very long message that should be truncated after about 50 characters to prevent overflow in the banner display area",
                    profileImageUrl: nil,
                    timestamp: Date()
                ),
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            
            Spacer()
        }
    }
}

#Preview("Multiple Banners") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack(spacing: 8) {
            NotificationBannerView(
                banner: BannerData(
                    conversationId: "conv_1",
                    senderId: "user_1",
                    senderName: "Charlie Davis",
                    messageText: "Are you free for a quick call?",
                    profileImageUrl: nil,
                    timestamp: Date()
                ),
                onTap: {},
                onDismiss: {}
            )
            
            NotificationBannerView(
                banner: BannerData(
                    conversationId: "conv_2",
                    senderId: "user_2",
                    senderName: "Diana Martinez",
                    messageText: "Don't forget about the meeting tomorrow!",
                    profileImageUrl: nil,
                    timestamp: Date()
                ),
                onTap: {},
                onDismiss: {}
            )
            
            Spacer()
        }
    }
}

