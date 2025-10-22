//
//  GroupInfoView.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import SwiftUI

/// View for displaying group information and participants
struct GroupInfoView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: GroupInfoViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let conversation: Conversation
    
    // MARK: - Initialization
    
    init(conversation: Conversation) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: GroupInfoViewModel(conversation: conversation))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Participants section
                    participantsSection
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Header section with group icon, name, and participant count
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Group icon
            ProfileImageView(
                imageUrl: conversation.groupImageUrl,
                displayName: conversation.groupName ?? "Group",
                size: 80,
                isGroup: true
            )
            
            // Group name
            Text(conversation.groupName ?? "Group Chat")
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Participant count
            Text("\(conversation.participantIds.count) participants")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    /// Participants section
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("PARTICIPANTS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            // Loading or participant list
            if viewModel.isLoading && viewModel.participants.isEmpty {
                loadingView
            } else if viewModel.participants.isEmpty {
                emptyStateView
            } else {
                participantList
            }
        }
    }
    
    /// Participant list
    private var participantList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.participants) { user in
                VStack(spacing: 0) {
                    ParticipantRow(user: user)
                        .padding(.horizontal)
                    
                    if user.id != viewModel.participants.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading participants...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    /// Empty state
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No participants found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    GroupInfoView(
        conversation: Conversation(
            id: "preview-group",
            type: .group,
            participantIds: ["user1", "user2", "user3", "user4"],
            participants: [
                "user1": Conversation.ParticipantInfo(
                    displayName: "Alice Johnson",
                    profileImageUrl: nil
                ),
                "user2": Conversation.ParticipantInfo(
                    displayName: "Bob Smith",
                    profileImageUrl: nil
                ),
                "user3": Conversation.ParticipantInfo(
                    displayName: "Charlie Brown",
                    profileImageUrl: nil
                ),
                "user4": Conversation.ParticipantInfo(
                    displayName: "Diana Prince",
                    profileImageUrl: nil
                )
            ],
            lastMessage: nil,
            groupName: "Engineering Team",
            groupImageUrl: nil,
            createdBy: "user1",
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}

