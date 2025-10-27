//
//  CreateGroupView.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// View for creating a new group conversation
struct CreateGroupView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var searchText = ""
    @State private var availableUsers: [User] = []
    @State private var selectedUserIds = Set<String>()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCreatingGroup = false
    
    /// Callback to navigate to a group after creation
    let onGroupCreated: (String) -> Void
    
    private let db = FirebaseService.shared.db
    private let conversationService = ConversationService()
    private let authService = AuthService()
    
    // Current user ID
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // Filtered users based on search
    private var filteredUsers: [User] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return availableUsers
        }
        
        let lowercasedSearch = searchText.lowercased()
        return availableUsers.filter { user in
            user.displayName.lowercased().contains(lowercasedSearch) ||
            user.email.lowercased().contains(lowercasedSearch)
        }
    }
    
    // Validation
    private var isValidGroupName: Bool {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    private var canCreateGroup: Bool {
        isValidGroupName && selectedUserIds.count >= 2 && !isCreatingGroup
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Group name section
                    groupNameSection
                    
                    Divider()
                    
                    // Participants section
                    participantsSection
                }
                
                // Creating group overlay
                if isCreatingGroup {
                    creatingGroupOverlay
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                fetchAvailableUsers()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Group name section
    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GROUP NAME")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextField("Group Name", text: $groupName)
                .font(.system(size: 20))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .accessibilityLabel("Group name")
                .accessibilityHint("Enter a name for your group, 1 to 50 characters")
            
            if !groupName.isEmpty && groupName.count > 50 {
                Text("Group name must be 50 characters or less")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    /// Participants section
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with count
            HStack {
                Text("ADD PARTICIPANTS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !selectedUserIds.isEmpty {
                    Text("\(selectedUserIds.count) selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            
            Divider()
            
            // User list
            if isLoading && availableUsers.isEmpty {
                loadingView
            } else if filteredUsers.isEmpty {
                emptyStateView
            } else {
                userList
            }
            
            // Create button
            createButton
        }
    }
    
    /// List of available users
    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    if let userId = user.id {
                        VStack(spacing: 0) {
                            ParticipantSelectionRow(
                                user: user,
                                isSelected: selectedUserIds.contains(userId),
                                onToggle: {
                                    toggleUserSelection(userId: userId)
                                }
                            )
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
    
    /// Create button
    private var createButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                createGroup()
            } label: {
                Text("Create Group")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canCreateGroup ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canCreateGroup)
            .padding()
            .background(Color(UIColor.systemBackground))
        }
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading users...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Empty state
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "person.2" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(searchText.isEmpty ? "No users found" : "No matching users")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Creating group overlay
    private var creatingGroupOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Creating group...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Methods
    
    /// Fetch available users from Firestore
    private func fetchAvailableUsers() {
        guard !currentUserId.isEmpty else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let snapshot = try await db.collection(Constants.Collections.users)
                    .getDocuments()
                
                let users = snapshot.documents.compactMap { document -> User? in
                    try? document.data(as: User.self)
                }
                
                // Filter out current user
                let filteredUsers = users.filter { $0.id != currentUserId }
                
                await MainActor.run {
                    self.availableUsers = filteredUsers
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load users: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Toggle user selection
    private func toggleUserSelection(userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }
    
    /// Create the group
    private func createGroup() {
        guard canCreateGroup else { return }
        
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupName.isEmpty else {
            errorMessage = "Please enter a group name"
            return
        }
        
        guard selectedUserIds.count >= 2 else {
            errorMessage = "Please select at least 2 participants"
            return
        }
        
        isCreatingGroup = true
        
        Task {
            do {
                // Build participants info map
                var participantsInfo: [String: Conversation.ParticipantInfo] = [:]
                
                // Add current user
                let currentUser = try await authService.getUserProfile(userId: currentUserId)
                participantsInfo[currentUserId] = Conversation.ParticipantInfo(
                    displayName: currentUser.displayName,
                    profileImageUrl: currentUser.profileImageUrl
                )
                
                // Add selected users
                for userId in selectedUserIds {
                    if let user = availableUsers.first(where: { $0.id == userId }) {
                        participantsInfo[userId] = Conversation.ParticipantInfo(
                            displayName: user.displayName,
                            profileImageUrl: user.profileImageUrl
                        )
                    }
                }
                
                // Create group conversation
                let conversation = try await conversationService.createGroupConversation(
                    creatorId: currentUserId,
                    participantIds: Array(selectedUserIds),
                    participantsInfo: participantsInfo,
                    groupName: trimmedGroupName
                )
                
                await MainActor.run {
                    self.isCreatingGroup = false
                    
                    // Dismiss this sheet first
                    dismiss()
                    
                    // Navigate to the group
                    if let conversationId = conversation.id {
                        // Delay slightly to allow sheet dismissal to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onGroupCreated(conversationId)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCreatingGroup = false
                    self.errorMessage = "Failed to create group: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateGroupView { conversationId in
        print("Navigate to group: \(conversationId)")
    }
}

