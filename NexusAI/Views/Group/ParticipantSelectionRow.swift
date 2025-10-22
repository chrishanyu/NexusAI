//
//  ParticipantSelectionRow.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import SwiftUI

/// Row view for selecting participants with checkbox
struct ParticipantSelectionRow: View {
    let user: User
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Profile image
                ProfileImageView(
                    imageUrl: user.profileImageUrl,
                    displayName: user.displayName,
                    size: 32
                )
                .onlineStatusIndicator(isOnline: user.isOnline)
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(user.email)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(user.displayName) for group")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Tap to deselect" : "Tap to select")
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ParticipantSelectionRow(
            user: User(
                id: "1",
                googleId: "google123",
                email: "alice@example.com",
                displayName: "Alice Johnson",
                profileImageUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            ),
            isSelected: false,
            onToggle: {}
        )
        
        ParticipantSelectionRow(
            user: User(
                id: "2",
                googleId: "google456",
                email: "bob@example.com",
                displayName: "Bob Smith",
                profileImageUrl: nil,
                isOnline: false,
                lastSeen: Date(),
                createdAt: Date()
            ),
            isSelected: true,
            onToggle: {}
        )
    }
    .padding()
}

