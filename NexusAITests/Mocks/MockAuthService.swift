//
//  MockAuthService.swift
//  NexusAITests
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseAuth
@testable import NexusAI

/// Mock AuthService for testing
class MockAuthService: AuthServiceProtocol {
    
    // MARK: - Mock State
    var shouldSucceed = true
    var shouldThrowError: Error?
    var mockUser: NexusAI.User?
    var signInCallCount = 0
    var signOutCallCount = 0
    var saveUserCallCount = 0
    var getUserCallCount = 0
    var updateOnlineStatusCallCount = 0
    
    // MARK: - Mock Delays (simulate network)
    var signInDelay: TimeInterval = 0
    var firestoreDelay: TimeInterval = 0
    
    // MARK: - Captured Arguments
    var lastSavedUser: NexusAI.User?
    var lastUserIdQueried: String?
    var lastOnlineStatus: (userId: String, isOnline: Bool)?
    
    // MARK: - Protocol Implementation
    
    func signInWithGoogle() async throws -> NexusAI.User {
        signInCallCount += 1
        
        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard shouldSucceed else {
            throw AuthError.googleSignInFailed("Mock sign-in failed")
        }
        
        // Return mock user or create default one
        let user = mockUser ?? NexusAI.User(
            id: "mock-user-123",
            googleId: "mock-google-id",
            email: "test@example.com",
            displayName: "Test User",
            profileImageUrl: "https://example.com/photo.jpg",
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        mockUser = user
        return user
    }
    
    func signOut() async throws {
        signOutCallCount += 1
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockUser = nil
    }
    
    func saveUserProfile(_ user: NexusAI.User) async throws {
        saveUserCallCount += 1
        lastSavedUser = user
        
        if firestoreDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestoreDelay * 1_000_000_000))
        }
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockUser = user
    }
    
    func getUserProfile(userId: String) async throws -> NexusAI.User {
        getUserCallCount += 1
        lastUserIdQueried = userId
        
        if firestoreDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestoreDelay * 1_000_000_000))
        }
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard let user = mockUser else {
            throw AuthError.userNotFound
        }
        
        return user
    }
    
    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        updateOnlineStatusCallCount += 1
        lastOnlineStatus = (userId, isOnline)
        
        if let error = shouldThrowError {
            throw error
        }
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        shouldSucceed = true
        shouldThrowError = nil
        mockUser = nil
        signInCallCount = 0
        signOutCallCount = 0
        saveUserCallCount = 0
        getUserCallCount = 0
        updateOnlineStatusCallCount = 0
        signInDelay = 0
        firestoreDelay = 0
        lastSavedUser = nil
        lastUserIdQueried = nil
        lastOnlineStatus = nil
    }
}

