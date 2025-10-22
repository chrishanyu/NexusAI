//
//  ConversationListView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI
import FirebaseAuth

/// Main conversation list screen showing all user's conversations
@available(iOS 17.0, *)
struct ConversationListView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewConversation = false
    
    // Current user ID for passing to row views
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                // Main content
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    loadingView
                } else if viewModel.filteredConversations.isEmpty {
                    if viewModel.searchText.isEmpty {
                        emptyStateView
                    } else {
                        noSearchResultsView
                    }
                } else {
                    conversationList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Constants.Colors.primaryBlue)
                    }
                    .accessibilityLabel("New conversation")
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search conversations"
            )
            .refreshable {
                Task { @MainActor in
                    viewModel.refresh()
                }
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView()
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
    
    /// List of conversations
    private var conversationList: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                NavigationLink(value: conversation.id ?? "") {
                    ConversationRowView(
                        conversation: conversation,
                        currentUserId: currentUserId,
                        unreadCount: viewModel.conversationUnreadCounts[conversation.id ?? ""] ?? 0
                    )
                }
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: Constants.Dimensions.screenPadding,
                    bottom: 0,
                    trailing: Constants.Dimensions.screenPadding
                ))
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { conversationId in
            if !conversationId.isEmpty {
                ChatView(conversationId: conversationId)
                    .environmentObject(viewModel)
            } else {
                Text("Invalid conversation")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    /// Empty state view (no conversations)
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to start a new conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// No search results view
    private var noSearchResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No results found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Try searching with different keywords")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("With Conversations") {
    if #available(iOS 17.0, *) {
        ConversationListView()
    }
}

#Preview("Empty State") {
    if #available(iOS 17.0, *) {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("No conversations yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Tap + to start a new conversation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

#Preview("Loading State") {
    if #available(iOS 17.0, *) {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading conversations...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

