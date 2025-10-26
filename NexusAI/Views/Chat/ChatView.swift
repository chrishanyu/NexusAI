//
//  ChatView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI
import Combine

/// Main chat screen for viewing and sending messages
struct ChatView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: ChatViewModel
    @State private var shouldAutoScroll = true
    @State private var scrollAnchorMessageId: String?
    @State private var scrollPosition: String? // For iOS 26+ scroll control
    @State private var isInitialLoad = true // Prevent scroll on initial message load
    @State private var showingGroupInfo = false
    @State private var showingAIAssistant = false
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var conversationListViewModel: ConversationListViewModel
    @EnvironmentObject private var bannerManager: NotificationBannerManager
    
    /// Initialize with conversation ID
    init(conversationId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }
    
    /// Initialize with conversation object
    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversation.id ?? ""))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Offline banner
            if viewModel.isOffline {
                offlineBanner
            }
            
            // Message list
            messageList
            
            // Typing indicator (placeholder for now)
            TypingIndicatorView(isTyping: false, typingUserName: "")
            
            // Message input bar
            MessageInputView(
                messageText: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                }
            )
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if isGroupConversation {
                    Button {
                        showingGroupInfo = true
                    } label: {
                        VStack(spacing: 2) {
                            Text(conversationTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(subtitleText)
                                .font(.caption)
                                .foregroundColor(subtitleColor)
                        }
                    }
                    .accessibilityLabel("View group info")
                    .accessibilityHint("Tap to view group participants and details")
                } else {
                    VStack(spacing: 2) {
                        Text(conversationTitle)
                            .font(.headline)
                        
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundColor(subtitleColor)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAIAssistant = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityLabel("AI Assistant")
                .accessibilityHint("Get AI help with this conversation")
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Mark messages as read when app returns to foreground
            if newPhase == .active && oldPhase == .background {
                viewModel.markVisibleMessagesAsRead()
                // Clear unread count in conversation list
                conversationListViewModel.updateUnreadCount(for: viewModel.conversationId, count: 0)
            }
        }
        .onAppear {
            // Set current conversation in banner manager to filter out banners
            bannerManager.setCurrentConversation(id: viewModel.conversationId)
        }
        .onDisappear {
            // Clear current conversation in banner manager
            bannerManager.setCurrentConversation(id: nil)
            
            // Clean up listeners when view is dismissed
            viewModel.cleanupListeners()
        }
        .sheet(isPresented: $showingGroupInfo) {
            if let conversation = viewModel.conversation {
                GroupInfoView(conversation: conversation)
            }
        }
        .sheet(isPresented: $showingAIAssistant) {
            AIAssistantView(
                isPresented: $showingAIAssistant,
                conversationId: viewModel.conversationId,
                conversation: viewModel.conversation,
                messages: viewModel.allMessages
            )
        }
    }
    
    // MARK: - Subviews
    
    /// Message list with scroll view
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.isLoading && viewModel.allMessages.isEmpty {
                    loadingView
                } else if viewModel.allMessages.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 8) {
                        // Top loading indicator or "no more messages"
                        if viewModel.isLoadingOlderMessages {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading older messages...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else if !viewModel.hasMoreMessages && viewModel.allMessages.count >= 50 {
                            Text("No more messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        
                        // Messages
                        ForEach(viewModel.allMessages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == viewModel.currentUserId,
                                showSenderName: isGroupConversation,
                                conversation: viewModel.conversation,
                                onRetry: { localId in
                                    viewModel.retryMessage(localId: localId)
                                }
                            )
                            .id(message.id ?? message.localId ?? UUID().uuidString)
                        }
                        
                        // Invisible anchor for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .scrollTargetLayout() // iOS 26: Enable precise scroll positioning
                    .padding(.vertical, 8)
                }
            }
            .scrollPosition(id: $scrollPosition, anchor: .bottom) // iOS 26: Modern scroll control
            .refreshable {
                // Save current scroll anchor (first visible message) before loading
                await MainActor.run {
                    // Store the ID of the first message as scroll anchor
                    scrollAnchorMessageId = viewModel.allMessages.first?.id
                    viewModel.loadOlderMessages()
                }
                
                // Wait for messages to load
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Restore scroll position to the anchor message
                await MainActor.run {
                    if let anchorId = scrollAnchorMessageId {
                        proxy.scrollTo(anchorId, anchor: .top)
                        scrollAnchorMessageId = nil // Clear after use
                    }
                }
            }
            .onAppear {
                // Set initial scroll position to bottom (iOS 26)
                if let lastMessage = viewModel.allMessages.last {
                    scrollPosition = lastMessage.id ?? lastMessage.localId
                } else {
                    scrollPosition = "bottom"
                }
                
                // Mark messages as read when chat opens
                viewModel.markVisibleMessagesAsRead()
                
                // Clear unread count in conversation list
                conversationListViewModel.updateUnreadCount(for: viewModel.conversationId, count: 0)
            }
            .onChange(of: viewModel.allMessages.count) { oldCount, newCount in
                // Skip initial load to prevent unwanted scroll animation
                if isInitialLoad {
                    isInitialLoad = false
                    // Set scroll position without animation
                    if let lastMessage = viewModel.allMessages.last {
                        scrollPosition = lastMessage.id ?? lastMessage.localId
                    }
                    return
                }
                
                // Only auto-scroll on new messages (after initial load)
                guard newCount > oldCount else { return }
                
                // Always scroll if it's the user's own message
                if let lastMessage = viewModel.allMessages.last,
                   lastMessage.senderId == viewModel.currentUserId {
                    scrollToBottom(proxy: proxy, animated: true)
                    // Also update scrollPosition for iOS 26
                    scrollPosition = lastMessage.id ?? lastMessage.localId
                    return
                }
                
                // Otherwise, only scroll if user is already at bottom
                if shouldAutoScroll {
                    scrollToBottom(proxy: proxy, animated: true)
                    // Also update scrollPosition for iOS 26
                    if let lastMessage = viewModel.allMessages.last {
                        scrollPosition = lastMessage.id ?? lastMessage.localId
                    }
                }
            }
        }
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading messages...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No messages yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start the conversation by sending a message")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// Offline indicator banner
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text("No internet connection. Messages will send when reconnected.")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Constants.Colors.offlineBanner)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
    }
    
    // MARK: - Computed Properties
    
    /// Conversation title
    private var conversationTitle: String {
        guard let conversation = viewModel.conversation else {
            return "Chat"
        }
        
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else {
            // Direct conversation - get other participant's name
            let otherParticipant = conversation.participants.first { $0.key != viewModel.currentUserId }
            return otherParticipant?.value.displayName ?? "Chat"
        }
    }
    
    /// Subtitle text (online status or last seen)
    private var subtitleText: String {
        guard let conversation = viewModel.conversation else {
            return ""
        }
        
        if conversation.type == .group {
            let participantCount = conversation.participantIds.count
            return "\(participantCount) participants"
        } else {
            // For direct chats, show online/offline status
            if viewModel.isOtherUserOnline {
                return "Online"
            } else if let lastSeen = viewModel.otherUserLastSeen {
                return "Last seen \(lastSeen.smartTimestamp())"
            } else {
                return "Offline"
            }
        }
    }
    
    /// Subtitle color
    private var subtitleColor: Color {
        if isGroupConversation {
            return .secondary
        } else {
            // For direct chats, green if online, secondary if offline
            return viewModel.isOtherUserOnline ? .green : .secondary
        }
    }
    
    /// Whether this is a group conversation
    private var isGroupConversation: Bool {
        viewModel.conversation?.type == .group
    }
    
    // MARK: - Methods
    
    /// Scroll to bottom of message list
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        if animated {
            withAnimation(.easeOut(duration: Constants.Animation.scrollToBottom)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Preview

#Preview("Empty Chat") {
    NavigationStack {
        ChatView(conversationId: "preview-conversation")
    }
}

#Preview("With Messages") {
    struct PreviewWrapper: View {
        var body: some View {
            NavigationStack {
                ChatView(conversationId: "preview-conversation")
            }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Group Chat") {
    NavigationStack {
        ChatView(conversationId: "preview-group")
    }
}

