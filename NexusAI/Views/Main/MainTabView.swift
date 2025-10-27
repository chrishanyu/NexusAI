//
//  MainTabView.swift
//  NexusAI
//
//  Created on October 24, 2025.
//

import SwiftUI

/// Main tab bar container with Chat, Nexus, and Profile tabs
/// Provides bottom navigation for primary app sections
@available(iOS 17.0, *)
struct MainTabView: View {
    // MARK: - Properties
    
    /// Selected tab index (0 = Chat, 1 = Nexus, 2 = Profile)
    /// Defaults to Chat tab on each app launch
    @State private var selectedTab: Int = 0
    
    /// Track keyboard visibility to hide/show tab bar
    @State private var isKeyboardVisible: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                // Detect if same tab was tapped
                if newValue == selectedTab {
                    // Trigger scroll-to-top for the current tab
                    switch newValue {
                    case 0:
                        NotificationCenter.default.post(name: .scrollToTopChatTab, object: nil)
                    case 1:
                        NotificationCenter.default.post(name: .scrollToTopAITab, object: nil)
                    case 2:
                        NotificationCenter.default.post(name: .scrollToTopProfileTab, object: nil)
                    default:
                        break
                    }
                }
                selectedTab = newValue
            }
        )) {
            // MARK: - Chat Tab
            ConversationListView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(0)
                .accessibilityLabel("Chat Tab")
                .accessibilityHint("View your conversations")
            
            // MARK: - Nexus Tab
            GlobalAIAssistantView()
                .tabItem {
                    Label("Nexus", systemImage: "sparkles")
                }
                .tag(1)
                .accessibilityLabel("Nexus Tab")
                .accessibilityHint("Search across all your conversations with AI")
            
            // MARK: - Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
                .accessibilityLabel("Profile Tab")
                .accessibilityHint("View your profile and settings")
        }
        // Use default iOS tab bar styling (translucent background, standard appearance)
        .tint(.blue) // Accent color for selected tab
        .toolbarVisibility(isKeyboardVisible ? .hidden : .visible, for: .tabBar)
        .onReceive(NotificationCenter.default.publisher(for: .keyboardWillShow)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardWillHide)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChatTab)) { _ in
            // Switch to Chat tab when Nexus navigates to a message
            withAnimation {
                selectedTab = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(NotificationManager())
}

