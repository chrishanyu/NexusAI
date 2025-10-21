//
//  NewConversationView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// View for creating a new conversation by selecting a user
struct NewConversationView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var availableUsers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCreatingConversation = false
    @State private var selectedConversation: Conversation?
    
    private let db = FirebaseService.shared.db
    private let conversationService = ConversationService()
    
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading && availableUsers.isEmpty {
                    loadingView
                } else if filteredUsers.isEmpty {
                    if searchText.isEmpty {
                        emptyStateView
                    } else {
                        noSearchResultsView
                    }
                } else {
                    userList
                }
                
                // Creating conversation overlay
                if isCreatingConversation {
                    creatingConversationOverlay
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search users")
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
    
    /// List of available users
    private var userList: some View {
        List {
            ForEach(filteredUsers) { user in
                Button {
                    createConversation(with: user)
                } label: {
                    UserRowView(user: user)
                }
                .disabled(isCreatingConversation)
            }
        }
        .listStyle(.plain)
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
    }
    
    /// Empty state
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No users found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("There are no other users in the system yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// No search results
    private var noSearchResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No users found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Try searching with a different name or email")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// Creating conversation overlay
    private var creatingConversationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Creating conversation...")
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
    
    /// Create or navigate to conversation with selected user
    private func createConversation(with user: User) {
        guard let userId = user.id else {
            errorMessage = "Invalid user"
            return
        }
        
        isCreatingConversation = true
        
        Task {
            do {
                // Get or create direct conversation
                let conversation = try await conversationService.getOrCreateDirectConversation(
                    participantIds: [currentUserId, userId]
                )
                
                await MainActor.run {
                    self.isCreatingConversation = false
                    self.selectedConversation = conversation
                    
                    // Dismiss this sheet to return to conversation list
                    // The conversation list will show the new/existing conversation
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isCreatingConversation = false
                    self.errorMessage = "Failed to create conversation: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - User Row View

/// Row view for displaying a user in the list
private struct UserRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            ProfileImageView(
                imageUrl: user.profileImageUrl,
                displayName: user.displayName,
                size: Constants.Dimensions.profileImageSmall
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
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, Constants.Dimensions.rowSpacing)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    NewConversationView()
}

