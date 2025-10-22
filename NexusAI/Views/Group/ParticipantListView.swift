//
//  ParticipantListView.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import SwiftUI

/// Reusable view for displaying a list of group participants
struct ParticipantListView: View {
    let participants: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("PARTICIPANTS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Participant list
            if participants.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(participants) { user in
                            VStack(spacing: 0) {
                                ParticipantRow(user: user)
                                    .padding(.horizontal)
                                
                                if user.id != participants.last?.id {
                                    Divider()
                                        .padding(.leading, 64)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Empty state when no participants loaded
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No participants")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    ParticipantListView(
        participants: [
            User(
                id: "1",
                googleId: "google1",
                email: "alice@example.com",
                displayName: "Alice Johnson",
                profileImageUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            ),
            User(
                id: "2",
                googleId: "google2",
                email: "bob@example.com",
                displayName: "Bob Smith",
                profileImageUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            ),
            User(
                id: "3",
                googleId: "google3",
                email: "charlie@example.com",
                displayName: "Charlie Brown",
                profileImageUrl: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600),
                createdAt: Date()
            )
        ]
    )
}

#Preview("Empty") {
    ParticipantListView(participants: [])
}

