//
//  AuthViewModel.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import Combine

/// ViewModel for managing authentication state and user sign-in/sign-out
@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authenticated user
    @Published var currentUser: User?
    
    /// Loading state indicator
    @Published var isLoading = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Computed property - true if user is authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    /// Use the new Realtime Database presence service (singleton)
    private let presenceService = RealtimePresenceService.shared
    
    // MARK: - Local-First Sync Dependencies (if enabled)
    
    private var userRepository: UserRepositoryProtocol?
    
    // MARK: - Initialization
    
    /// Initialize with default AuthService
    init(userRepository: UserRepositoryProtocol? = nil) {
        self.authService = AuthService()
        
        // Set up repository if feature flag enabled
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            self.userRepository = userRepository ?? RepositoryFactory.shared.userRepository
            print("✅ AuthViewModel using local-first sync (UserRepository)")
        } else {
            print("✅ AuthViewModel using legacy Firebase services")
        }
        
        // Set up auth state listener for session persistence
        setupAuthStateListener()
    }
    
    /// Initialize with custom AuthService dependency (for testing)
    /// - Parameters:
    ///   - authService: Service for authentication operations
    ///   - userRepository: Optional user repository for local-first sync
    init(authService: AuthServiceProtocol, userRepository: UserRepositoryProtocol? = nil) {
        self.authService = authService
        
        // Set up repository if feature flag enabled
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            self.userRepository = userRepository ?? RepositoryFactory.shared.userRepository
            print("✅ AuthViewModel using local-first sync (UserRepository)")
        } else {
            print("✅ AuthViewModel using legacy Firebase services")
        }
        
        // Set up auth state listener for session persistence
        setupAuthStateListener()
    }
    
    deinit {
        // Clean up auth state listener
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Public Methods
    
    /// Sign in with Google
    func signIn() async {
        // Clear any previous error messages
        errorMessage = nil
        
        // Set loading state
        isLoading = true
        
        defer {
            // Always turn off loading when done
            isLoading = false
        }
        
        do {
            // Call AuthService to sign in with Google
            let user = try await authService.signInWithGoogle()
            
            // Update current user on success
            currentUser = user
            
            // Immediately save to local database if using repository mode
            if let repository = userRepository {
                print("💾 AuthViewModel: Saving user to local DB immediately after sign-in")
                _ = try? await repository.saveUser(user)
            }
            
            // Initialize presence and set user online
            if let userId = user.id {
                presenceService.initializePresence(for: userId)
                
                do {
                    try await presenceService.setUserOnline(userId: userId)
                    print("👥 User presence set to online (RTDB)")
                } catch {
                    print("⚠️ Failed to set user online: \(error.localizedDescription)")
                }
            }
            
            print("✅ Sign-in successful: \(user.displayName)")
            
        } catch let error as AuthError {
            // Check if this is a Firestore failure after successful Google Sign-In
            if case .firestoreError = error {
                // Sign out the user since profile creation failed
                await handleFirestoreFailure()
            }
            
            // Map AuthError to user-friendly messages
            handleAuthError(error)
            
            // Auto-dismiss error after 5 seconds
            scheduleErrorDismissal()
            
        } catch {
            // Handle unexpected errors
            errorMessage = "An unexpected error occurred. Please try again."
            print("❌ Unexpected sign-in error: \(error.localizedDescription)")
            
            // Auto-dismiss error after 5 seconds
            scheduleErrorDismissal()
        }
    }
    
    // MARK: - Private Methods
    
    /// Map AuthError types to user-friendly error messages
    private func handleAuthError(_ error: AuthError) {
        switch error {
        case .googleSignInCancelled:
            errorMessage = "Sign-in was cancelled. Please try again."
            
        case .googleSignInFailed(let message):
            // Check for specific failure reasons
            if message.contains("network") || message.contains("connection") {
                errorMessage = "Network error. Please check your connection and try again."
            } else if message.contains("permissions") {
                errorMessage = "App permissions were revoked. Please grant permissions to continue."
            } else {
                errorMessage = "Google Sign-In failed. Please try again."
            }
            
        case .networkError:
            errorMessage = "Network error. Please check your connection and try again."
            
        case .firestoreError:
            errorMessage = "Failed to create profile. Please try signing in again."
            
        case .invalidCredentials:
            errorMessage = "Invalid credentials. Please try again."
            
        case .userNotFound:
            errorMessage = "User not found. Please sign up first."
            
        case .invalidUserId:
            errorMessage = "Invalid user ID. Please try again."
        }
        
        print("❌ Auth error: \(error.localizedDescription)")
    }
    
    /// Sign out current user
    func signOut() async {
        // Clear any error messages
        errorMessage = nil
        
        // Set loading state
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // Set user offline before signing out
            if let userId = currentUser?.id {
                do {
                    try await presenceService.setUserOffline(userId: userId, delay: 0)
                    print("👥 User presence set to offline (RTDB)")
                } catch {
                    print("⚠️ Failed to set user offline: \(error.localizedDescription)")
                }
            }
            
            // Call AuthService to sign out
            try await authService.signOut()
            
            // Clear current user state
            currentUser = nil
            
            print("✅ Sign-out successful")
            
        } catch {
            // Handle sign-out errors
            errorMessage = "Failed to sign out. Please try again."
            print("❌ Sign-out error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Auth State Listener
    
    /// Set up Firebase Auth state listener for session persistence
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    // User is signed in - fetch full profile from Firestore
                    await self.loadUserProfile(userId: firebaseUser.uid)
                } else {
                    // User is signed out
                    self.currentUser = nil
                }
            }
        }
    }
    
    /// Load user profile from repository or Firestore
    private func loadUserProfile(userId: String) async {
        print("🟢 AuthViewModel: loadUserProfile called for userId: \(userId)")
        do {
            var user: User?
            
            // Use repository if available, otherwise use auth service
            if let repository = userRepository {
                // Repository mode: fetch from local database (synced from Firestore)
                print("🟢 AuthViewModel: Using repository to load user")
                user = try await repository.getUser(userId: userId)
                
                // Fallback: If not in local DB yet (first login or sync delay), fetch from Firestore
                if user == nil {
                    print("⚠️ AuthViewModel: User not in local DB, fetching from Firestore...")
                    user = try await authService.getUserProfile(userId: userId)
                    
                    // Save to local database for future use
                    if let user = user {
                        print("✅ AuthViewModel: Saving user to local DB from Firestore fallback")
                        _ = try? await repository.saveUser(user)
                    }
                }
                
                print("✅ AuthViewModel: User profile loaded: \(user?.displayName ?? "nil") / \(user?.email ?? "nil")")
            } else {
                // Legacy mode: fetch directly from Firestore
                print("🟢 AuthViewModel: Using auth service to load user (legacy mode)")
                user = try await authService.getUserProfile(userId: userId)
                print("✅ AuthViewModel: User profile loaded from Firestore: \(user?.displayName ?? "nil") / \(user?.email ?? "nil")")
            }
            
            // Update current user
            currentUser = user
            print("✅ AuthViewModel: currentUser updated to: \(currentUser?.displayName ?? "nil")")
            
            // Initialize presence for the authenticated user
            if user != nil {
                presenceService.initializePresence(for: userId)
                
                do {
                    try await presenceService.setUserOnline(userId: userId)
                    print("👥 User presence initialized and set online (auth state listener)")
                } catch {
                    print("⚠️ Failed to set user online: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ AuthViewModel: User is nil after loading")
            }
            
        } catch {
            print("⚠️ AuthViewModel: Failed to load user profile: \(error.localizedDescription)")
            print("⚠️ AuthViewModel: Error type: \(type(of: error))")
            // If we can't load the profile, sign out the user
            currentUser = nil
            print("⚠️ AuthViewModel: currentUser set to nil due to error")
        }
    }
    
    // MARK: - Error Handling Helpers
    
    /// Handle Firestore failure after successful Google Sign-In
    private func handleFirestoreFailure() async {
        print("⚠️ Firestore failure detected - signing out user")
        
        // Sign out from Firebase Auth since profile creation failed
        do {
            try await authService.signOut()
        } catch {
            print("❌ Failed to sign out after Firestore error: \(error.localizedDescription)")
        }
        
        // Clear user state
        currentUser = nil
    }
    
    /// Schedule automatic error message dismissal after 5 seconds
    private func scheduleErrorDismissal() {
        // Capture current error message to compare later
        let currentError = errorMessage
        
        Task {
            // Wait 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            // Only clear if the error message hasn't changed
            // (user might have triggered a new error)
            if errorMessage == currentError {
                errorMessage = nil
            }
        }
    }
}

