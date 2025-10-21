//
//  AuthService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

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
            googleId: "", // Empty for email/password auth
            email: email,
            displayName: displayName,
            profileImageUrl: nil,
            isOnline: true,
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
    
    /// Sign out current user
    func signOut() async throws {
        guard let userId = auth.currentUser?.uid else { return }
        
        // Update online status before signing out
        try await updateOnlineStatus(userId: userId, isOnline: false)
        
        // Sign out from Firebase Auth
        try auth.signOut()
    }
    
    /// Send password reset email
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // MARK: - User Profile Management
    
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

