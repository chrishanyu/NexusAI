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
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showingNewConversation = false
    @State private var showingNewGroup = false
    @State private var navigationPath = NavigationPath()
    
    // Current user ID for passing to row views
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .toolbarVisibility(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingNewConversation = true
                        } label: {
                            Label("New Conversation", systemImage: "person")
                        }
                        
                        Button {
                            showingNewGroup = true
                        } label: {
                            Label("New Group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Constants.Colors.primaryBlue)
                    }
                    .accessibilityLabel("New message")
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
            .sheet(isPresented: $showingNewGroup) {
                CreateGroupView()
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
            .onChange(of: notificationManager.pendingConversationId) { oldValue, newValue in
                // Handle notification navigation
                if let conversationId = newValue, !conversationId.isEmpty {
                    print("📱 ConversationListView: Navigating to conversation from notification: \(conversationId)")
                    
                    // Add the conversation to the navigation path
                    navigationPath.append(conversationId)
                    
                    // Clear the pending navigation
                    notificationManager.clearPendingNavigation()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// List of conversations
    private var conversationList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.filteredConversations) { conversation in
                    NavigationLink(value: conversation.id ?? "") {
                        ConversationRowView(
                            conversation: conversation,
                            currentUserId: currentUserId,
                            unreadCount: viewModel.conversationUnreadCounts[conversation.id ?? ""] ?? 0,
                            userPresenceMap: viewModel.userPresenceMap
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
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopChatTab)) { _ in
                // If we're in a child view (navigationPath not empty), pop back
                if !navigationPath.isEmpty {
                    navigationPath.removeLast()
                } else {
                    // Otherwise, scroll to top
                    withAnimation {
                        if let firstId = viewModel.filteredConversations.first?.id {
                            proxy.scrollTo(firstId, anchor: .top)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .jumpToMessage)) { notification in
                // Handle jump to message from Nexus
                guard let source = notification.object as? SourceMessage else { return }
                
                // Navigate to the conversation
                navigationPath.append(source.conversationId)
                
                // Post notification with messageId for ChatView to scroll to
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: .scrollToMessageInChat,
                        object: source.id
                    )
                }
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

