//
//  ParticipantRow.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import SwiftUI
import FirebaseAuth

/// Row view for displaying a participant in group info
struct ParticipantRow: View {
    let user: User
    let isCurrentUser: Bool
    
    init(user: User) {
        self.user = user
        self.isCurrentUser = user.id == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image with online indicator
            ProfileImageView(
                imageUrl: user.profileImageUrl,
                displayName: user.displayName,
                size: 40
            )
            .onlineStatusIndicator(isOnline: user.isOnline)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(user.email)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityLabel("\(user.displayName)\(isCurrentUser ? ", You" : ""), \(user.isOnline ? "online" : "offline")")
    }
}

// MARK: - Preview

#Preview {
    List {
        ParticipantRow(
            user: User(
                id: Auth.auth().currentUser?.uid ?? "current",
                googleId: "google123",
                email: "you@example.com",
                displayName: "You",
                profileImageUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            )
        )
        
        ParticipantRow(
            user: User(
                id: "user2",
                googleId: "google456",
                email: "alice@example.com",
                displayName: "Alice Johnson",
                profileImageUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            )
        )
        
        ParticipantRow(
            user: User(
                id: "user3",
                googleId: "google789",
                email: "bob@example.com",
                displayName: "Bob Smith",
                profileImageUrl: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600),
                createdAt: Date()
            )
        )
    }
}

