//
//  AuthService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import UIKit

/// Service for user authentication and profile management
class AuthService {
    
    // MARK: - Properties
    private let db = FirebaseService.shared.db
    private let auth = FirebaseService.shared.auth
    
    // MARK: - Authentication
    
    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        // Create Firebase Auth user
        let authResult = try await auth.createUser(withEmail: email, password: password)
        
        // Create user profile in Firestore
        let user = User(
            id: authResult.user.uid,
            googleId: nil, // No Google ID for email/password auth
            email: email,
            displayName: displayName,
            profileImageUrl: nil,
            isOnline: false, // Will be set online via updateOnlineStatus after creation
            lastSeen: Date(),
            createdAt: Date()
        )
        
        try await saveUserProfile(user)
        
        return user
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User {
        // Authenticate with Firebase
        let authResult = try await auth.signIn(withEmail: email, password: password)
        
        // Fetch user profile from Firestore
        let user = try await getUserProfile(userId: authResult.user.uid)
        
        // Update online status
        try await updateOnlineStatus(userId: authResult.user.uid, isOnline: true)
        
        return user
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws -> User {
        // Get the client ID from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.googleSignInFailed("Unable to retrieve Google Client ID")
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller for presenting the sign-in UI
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.googleSignInFailed("Unable to find root view controller")
        }
        
        // Initiate Google Sign-In flow
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = signInResult.user
        
        // Get ID token and access token
        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.googleSignInFailed("Unable to retrieve ID token")
        }
        let accessToken = user.accessToken.tokenString
        
        // Create Firebase credential from Google tokens
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        // Sign in to Firebase with Google credential
        let authResult = try await auth.signIn(with: credential)
        
        // Create or update user profile in Firestore
        let nexusUser = try await createOrUpdateUserInFirestore(firebaseUser: authResult.user)
        
        // Update online status
        try await updateOnlineStatus(userId: nexusUser.id!, isOnline: true)
        
        return nexusUser
    }
    
    /// Sign out current user
    func signOut() async throws {
        guard let userId = auth.currentUser?.uid else { return }
        
        // Update online status before signing out
        try await updateOnlineStatus(userId: userId, isOnline: false)
        
        // Sign out from Firebase Auth
        try auth.signOut()
        
        // Sign out from Google Sign-In
        GIDSignIn.sharedInstance.signOut()
    }
    
    /// Send password reset email
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // MARK: - User Profile Management
    
    /// Create or update user in Firestore from Firebase User
    private func createOrUpdateUserInFirestore(firebaseUser: FirebaseAuth.User) async throws -> User {
        // Extract user data from Firebase User
        let userId = firebaseUser.uid
        let email = firebaseUser.email ?? ""
        let displayName = firebaseUser.displayName ?? email.components(separatedBy: "@").first ?? "User"
        let profileImageUrl = firebaseUser.photoURL?.absoluteString
        
        // Retry logic for Firestore operations
        var lastError: Error?
        for attempt in 1...2 {
            do {
                // Check if user already exists
                let userDoc = db.collection(Constants.Collections.users).document(userId)
                let document = try await userDoc.getDocument()
                
                if document.exists {
                    // Update existing user with latest Google data
                    // Note: Don't update isOnline here - it's managed separately via updateOnlineStatus
                    try await userDoc.updateData([
                        "email": email,
                        "displayName": displayName,
                        "profileImageUrl": profileImageUrl as Any,
                        "lastSeen": FieldValue.serverTimestamp()
                    ])
                    
                    // Fetch and return updated user
                    return try await getUserProfile(userId: userId)
                } else {
                    // Create new user with offline status (will be set online via updateOnlineStatus after creation)
                    let user = User(
                        id: userId,
                        googleId: firebaseUser.uid, // For Google Sign-In, googleId is same as uid
                        email: email,
                        displayName: displayName,
                        profileImageUrl: profileImageUrl,
                        isOnline: false,
                        lastSeen: Date(),
                        createdAt: Date()
                    )
                    
                    try await saveUserProfile(user)
                    return user
                }
            } catch {
                lastError = error
                if attempt == 1 {
                    // Wait 1 second before retry
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        // If both attempts failed, throw the last error
        throw lastError ?? AuthError.firestoreError
    }
    
    /// Save or update user profile in Firestore
    func saveUserProfile(_ user: User) async throws {
        guard let userId = user.id else {
            throw AuthError.invalidUserId
        }
        
        try db.collection(Constants.Collections.users)
            .document(userId)
            .setData(from: user)
    }
    
    /// Get user profile from Firestore
    func getUserProfile(userId: String) async throws -> User {
        let document = try await db.collection(Constants.Collections.users)
            .document(userId)
            .getDocument()
        
        guard document.exists else {
            throw AuthError.userNotFound
        }
        
        return try document.data(as: User.self)
    }
    
    /// Update user display name
    func updateDisplayName(userId: String, displayName: String) async throws {
        try await db.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "displayName": displayName
            ])
    }
    
    /// Update profile image URL
    func updateProfileImage(userId: String, imageUrl: String) async throws {
        try await db.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "profileImageUrl": imageUrl
            ])
    }
    
    /// Update online status
    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await db.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ])
    }
    
    /// Update FCM token for push notifications
    func updateFCMToken(userId: String, token: String) async throws {
        try await db.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "fcmToken": token
            ])
    }
    
    /// Get multiple user profiles by IDs
    func getUserProfiles(userIds: [String]) async throws -> [User] {
        var users: [User] = []
        
        // Firestore 'in' query supports up to 10 items
        let chunks = userIds.chunked(into: 10)
        
        for chunk in chunks {
            let snapshot = try await db.collection(Constants.Collections.users)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            let chunkUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
            users.append(contentsOf: chunkUsers)
        }
        
        return users
    }
    
    // MARK: - Auth State Listener
    
    /// Add auth state change listener
    func addAuthStateListener(_ listener: @escaping (Auth, FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener(listener)
    }
    
    /// Remove auth state change listener
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidUserId
    case userNotFound
    case invalidCredentials
    case networkError
    case googleSignInFailed(String)
    case googleSignInCancelled
    case firestoreError
    
    var errorDescription: String? {
        switch self {
        case .invalidUserId:
            return "Invalid user ID"
        case .userNotFound:
            return "User profile not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .googleSignInCancelled:
            return "Sign-in was cancelled. Please try again."
        case .firestoreError:
            return "Failed to create profile. Please try signing in again."
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

