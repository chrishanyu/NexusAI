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
    
    // MARK: - Initialization
    
    /// Initialize with default AuthService
    init() {
        self.authService = AuthService()
        
        // Set up auth state listener for session persistence
        setupAuthStateListener()
    }
    
    /// Initialize with custom AuthService dependency (for testing)
    /// - Parameter authService: Service for authentication operations
    init(authService: AuthServiceProtocol) {
        self.authService = authService
        
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
    
    /// Load user profile from Firestore
    private func loadUserProfile(userId: String) async {
        do {
            let user = try await authService.getUserProfile(userId: userId)
            currentUser = user
            print("✅ User profile loaded: \(user.displayName)")
        } catch {
            print("⚠️ Failed to load user profile: \(error.localizedDescription)")
            // If we can't load the profile, sign out the user
            currentUser = nil
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

