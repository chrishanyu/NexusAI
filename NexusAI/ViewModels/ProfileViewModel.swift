//
//  ProfileViewModel.swift
//  NexusAI
//
//  Created on October 24, 2025.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

/// ViewModel for managing profile screen state and user data
/// Uses UserRepository as single source of truth for user profile data
@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current user's profile data from repository
    @Published var currentUser: User?
    
    /// Loading state indicator
    @Published var isLoading: Bool = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// User's display name (with fallback)
    var displayName: String {
        let name = currentUser?.displayName ?? "Unknown User"
        print("🔍 ProfileViewModel.displayName accessed: returning '\(name)' (currentUser=\(currentUser != nil ? "exists" : "nil"))")
        return name
    }
    
    /// User's email address (with fallback)
    var email: String {
        let emailValue = currentUser?.email ?? "No email"
        print("🔍 ProfileViewModel.email accessed: returning '\(emailValue)' (currentUser=\(currentUser != nil ? "exists" : "nil"))")
        return emailValue
    }
    
    /// User's profile image URL
    var profileImageUrl: String? {
        let url = currentUser?.profileImageUrl
        print("🔍 ProfileViewModel.profileImageUrl accessed: returning '\(url ?? "nil")' (currentUser=\(currentUser != nil ? "exists" : "nil"))")
        return url
    }
    
    // MARK: - Dependencies
    
    private let userRepository: UserRepositoryProtocol
    private let authViewModel: AuthViewModel
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with dependency injection
    /// - Parameters:
    ///   - userRepository: Repository for accessing user data (defaults to shared instance)
    ///   - authViewModel: Auth view model for logout functionality
    init(
        userRepository: UserRepositoryProtocol? = nil,
        authViewModel: AuthViewModel
    ) {
        self.userRepository = userRepository ?? RepositoryFactory.shared.userRepository
        self.authViewModel = authViewModel
        
        print("✅ ProfileViewModel: Initialized with repository")
        print("✅ ProfileViewModel: authViewModel.currentUser at init = \(authViewModel.currentUser?.displayName ?? "nil")")
        print("✅ ProfileViewModel: Firebase Auth user = \(Auth.auth().currentUser?.uid ?? "nil")")
        
        // Load user data on initialization
        print("✅ ProfileViewModel: Creating Task to load user data...")
        Task { @MainActor in
            print("🚀 ProfileViewModel: Task started, about to call loadCurrentUser()")
            await loadCurrentUser()
            print("🚀 ProfileViewModel: Task completed loadCurrentUser()")
        }
        print("✅ ProfileViewModel: Task created")
    }
    
    // MARK: - Public Methods
    
    /// Load current user's profile data from repository
    func loadCurrentUser() async {
        print("📱 ProfileViewModel: Loading current user profile")
        
        // Get current user ID from Firebase Auth
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ ProfileViewModel: No authenticated user found in Firebase Auth")
            print("❌ ProfileViewModel: Auth.auth().currentUser = nil")
            errorMessage = "Not authenticated"
            return
        }
        
        print("📱 ProfileViewModel: Firebase Auth userId = \(userId)")
        isLoading = true
        errorMessage = nil
        
        do {
            print("📱 ProfileViewModel: Calling userRepository.getUser(userId: \(userId))")
            // Fetch user from repository
            if let user = try await userRepository.getUser(userId: userId) {
                self.currentUser = user
                print("✅ ProfileViewModel: Loaded user from repository - \(user.displayName) (\(user.email))")
                print("✅ ProfileViewModel: currentUser set to: displayName=\(user.displayName), email=\(user.email)")
            } else {
                // User not found in local database
                print("⚠️ ProfileViewModel: userRepository.getUser() returned nil - User not found in local database")
                print("⚠️ ProfileViewModel: Checking AuthViewModel fallback...")
                print("⚠️ ProfileViewModel: authViewModel.currentUser = \(authViewModel.currentUser?.displayName ?? "nil")")
                errorMessage = "Profile data not available"
                
                // Try to use data from AuthViewModel as fallback
                if let authUser = authViewModel.currentUser {
                    print("💡 ProfileViewModel: Using data from AuthViewModel as fallback")
                    print("💡 ProfileViewModel: Fallback user: displayName=\(authUser.displayName), email=\(authUser.email)")
                    currentUser = authUser
                    print("💡 ProfileViewModel: currentUser set from fallback")
                } else {
                    print("❌ ProfileViewModel: authViewModel.currentUser is also nil - no fallback available")
                }
            }
        } catch {
            print("❌ ProfileViewModel: userRepository.getUser() threw error: \(error.localizedDescription)")
            print("❌ ProfileViewModel: Error type: \(type(of: error))")
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            
            print("❌ ProfileViewModel: Checking AuthViewModel fallback after error...")
            print("❌ ProfileViewModel: authViewModel.currentUser = \(authViewModel.currentUser?.displayName ?? "nil")")
            
            // Try to use data from AuthViewModel as fallback
            if let authUser = authViewModel.currentUser {
                print("💡 ProfileViewModel: Using data from AuthViewModel as fallback (after error)")
                print("💡 ProfileViewModel: Fallback user: displayName=\(authUser.displayName), email=\(authUser.email)")
                currentUser = authUser
                print("💡 ProfileViewModel: currentUser set from fallback")
            } else {
                print("❌ ProfileViewModel: authViewModel.currentUser is also nil - no fallback available")
            }
        }
        
        isLoading = false
        print("📱 ProfileViewModel: loadCurrentUser completed")
        print("📱 ProfileViewModel: Final currentUser state: \(currentUser?.displayName ?? "nil") / \(currentUser?.email ?? "nil")")
    }
    
    /// Log out current user
    /// Calls AuthViewModel.signOut() which handles Firebase sign-out and presence cleanup
    func logout() async {
        print("🔓 ProfileViewModel: Logout initiated")
        
        isLoading = true
        errorMessage = nil
        
        // Call AuthViewModel's signOut method
        await authViewModel.signOut()
        
        // Clear current user data
        currentUser = nil
        
        isLoading = false
        
        print("✅ ProfileViewModel: Logout complete")
    }
    
    /// Refresh user profile data
    func refresh() async {
        print("🔄 ProfileViewModel: Refreshing user profile")
        await loadCurrentUser()
    }
}

