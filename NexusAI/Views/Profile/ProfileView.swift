//
//  ProfileView.swift
//  NexusAI
//
//  Created on October 24, 2025.
//

import SwiftUI
import Combine

/// Profile screen displaying user information and logout functionality
/// Shows profile picture, display name, email, and logout button
@available(iOS 17.0, *)
struct ProfileView: View {
    // MARK: - Properties
    
    /// Auth view model from environment (for logout functionality)
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    /// Profile view model managing state and data
    @State private var viewModel: ProfileViewModel?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if let vm = viewModel {
                        // Extract to separate view that properly observes the ProfileViewModel
                        ProfileContentView(viewModel: vm)
                            .id("top") // Anchor for scroll-to-top
                    } else {
                        // Loading state while viewModel is being created
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarVisibility(.visible, for: .tabBar)
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTopProfileTab)) { _ in
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .onAppear {
                // Initialize viewModel with authViewModel from environment
                print("🔵 ProfileView: onAppear triggered")
                print("🔵 ProfileView: authViewModel.currentUser = \(authViewModel.currentUser?.displayName ?? "nil")")
                print("🔵 ProfileView: authViewModel.isAuthenticated = \(authViewModel.isAuthenticated)")
                
                if viewModel == nil {
                    print("🔵 ProfileView: Creating ProfileViewModel...")
                    viewModel = ProfileViewModel(authViewModel: authViewModel)
                    print("🔵 ProfileView: ProfileViewModel created")
                } else {
                    print("🔵 ProfileView: ProfileViewModel already exists")
                }
            }
        }
    }
}

/// Content view that properly observes ProfileViewModel
@available(iOS 17.0, *)
struct ProfileContentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Profile Picture
            ProfileImageView(
                imageUrl: viewModel.profileImageUrl,
                displayName: viewModel.displayName,
                avatarColorHex: viewModel.avatarColorHex,
                size: 120
            )
            .accessibilityLabel("Profile picture")
            .accessibilityHint("Your profile photo")
        
            // MARK: - User Information
            VStack(spacing: 8) {
                // Display Name
                Text(viewModel.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Display name")
                    .accessibilityValue(viewModel.displayName)
                
                // Email
                Text(viewModel.email)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Email address")
                    .accessibilityValue(viewModel.email)
            }
            
            // MARK: - Spacer for visual balance
            Spacer()
                .frame(height: 40)
            
            // MARK: - Log Out Button
            Button(action: {
                Task {
                    await viewModel.logout()
                }
            }) {
                Text("Log Out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
            .padding(.horizontal, 24)
            .accessibilityLabel("Log out button")
            .accessibilityHint("Sign out of your account")
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

