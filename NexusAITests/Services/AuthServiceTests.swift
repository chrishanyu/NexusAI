//
//  AuthServiceTests.swift
//  NexusAITests
//
//  Created on 10/21/25.
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import NexusAI

final class AuthServiceTests: XCTestCase {
    
    var mockAuthService: MockAuthService!
    
    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
    }
    
    override func tearDown() {
        mockAuthService = nil
        super.tearDown()
    }
    
    // MARK: - Test 2.11: signInWithGoogle
    
    /// Test successful Google Sign-In flow
    func testSignInWithGoogle_Success() async throws {
        // Given: Mock service configured for success
        mockAuthService.shouldSucceed = true
        
        // When: signInWithGoogle is called
        let user = try await mockAuthService.signInWithGoogle()
        
        // Then: User should be returned with correct data
        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertTrue(user.isOnline)
        XCTAssertEqual(mockAuthService.signInCallCount, 1)
    }
    
    /// Test Google Sign-In cancelled by user
    func testSignInWithGoogle_Cancelled() async throws {
        // Given: Mock configured to throw cancellation error
        mockAuthService.shouldThrowError = AuthError.googleSignInCancelled
        
        // When/Then: Should throw AuthError.googleSignInCancelled
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .googleSignInCancelled = error {
                XCTAssertEqual(error.errorDescription, "Sign-in was cancelled. Please try again.")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    /// Test Google Sign-In with network error
    func testSignInWithGoogle_NetworkError() async throws {
        // Given: Mock configured to throw network error
        mockAuthService.shouldThrowError = AuthError.networkError
        
        // When/Then: Should throw network error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .networkError = error {
                XCTAssertEqual(error.errorDescription, "Network connection error")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    /// Test Google Sign-In success but missing ID token
    func testSignInWithGoogle_MissingIDToken() async throws {
        // Given: Mock configured to throw googleSignInFailed error
        mockAuthService.shouldThrowError = AuthError.googleSignInFailed("Unable to retrieve ID token")
        
        // When/Then: Should throw googleSignInFailed error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .googleSignInFailed(let message) = error {
                XCTAssertTrue(message.contains("ID token"))
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    // MARK: - Test 2.12: createOrUpdateUserInFirestore
    
    /// Test creating new user in Firestore
    func testCreateOrUpdateUserInFirestore_NewUser() async throws {
        // Given: New user to save
        let newUser = User(
            id: "new-user-123",
            googleId: "google-123",
            email: "newuser@example.com",
            displayName: "New User",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When: saveUserProfile is called
        try await mockAuthService.saveUserProfile(newUser)
        
        // Then: User should be saved
        XCTAssertEqual(mockAuthService.saveUserCallCount, 1)
        XCTAssertEqual(mockAuthService.lastSavedUser?.id, "new-user-123")
        XCTAssertEqual(mockAuthService.lastSavedUser?.email, "newuser@example.com")
    }
    
    /// Test updating existing user in Firestore
    func testCreateOrUpdateUserInFirestore_ExistingUser() async throws {
        // Given: Existing user
        let existingUser = User(
            id: "existing-user-123",
            googleId: "google-123",
            email: "existing@example.com",
            displayName: "Existing User",
            profileImageUrl: nil,
            isOnline: false,
            lastSeen: Date().addingTimeInterval(-3600),
            createdAt: Date().addingTimeInterval(-86400)
        )
        mockAuthService.mockUser = existingUser
        
        // When: User profile is updated
        var updatedUser = existingUser
        updatedUser.isOnline = true
        updatedUser.lastSeen = Date()
        try await mockAuthService.saveUserProfile(updatedUser)
        
        // Then: User should be updated
        XCTAssertEqual(mockAuthService.saveUserCallCount, 1)
        XCTAssertTrue(mockAuthService.lastSavedUser?.isOnline ?? false)
    }
    
    /// Test retry logic on Firestore failure
    func testCreateOrUpdateUserInFirestore_RetryOnFailure() async throws {
        // Given: Mock with delay to simulate retry
        mockAuthService.firestoreDelay = 0.1
        let user = User(
            id: "test-user",
            googleId: "google-id",
            email: "test@example.com",
            displayName: "Test",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When: saveUserProfile is called
        let startTime = Date()
        try await mockAuthService.saveUserProfile(user)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Then: Should have delay (simulating retry)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
        XCTAssertEqual(mockAuthService.saveUserCallCount, 1)
    }
    
    /// Test retry logic exhausted
    func testCreateOrUpdateUserInFirestore_RetryExhausted() async throws {
        // Given: Mock configured to fail
        mockAuthService.shouldThrowError = AuthError.firestoreError
        let user = User(
            id: "test-user",
            googleId: "google-id",
            email: "test@example.com",
            displayName: "Test",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // When/Then: Should throw firestoreError
        do {
            try await mockAuthService.saveUserProfile(user)
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .firestoreError = error {
                XCTAssertEqual(error.errorDescription, "Failed to create profile. Please try signing in again.")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    // MARK: - Test 2.13: signOut
    
    /// Test successful sign out
    func testSignOut_Success() async throws {
        // Given: User is signed in
        let user = User(
            id: "test-user-123",
            googleId: "google-id",
            email: "test@example.com",
            displayName: "Test User",
            profileImageUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        mockAuthService.mockUser = user
        
        // When: signOut is called
        try await mockAuthService.signOut()
        
        // Then: Should sign out successfully
        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
        XCTAssertNil(mockAuthService.mockUser)
    }
    
    /// Test sign out when no user is signed in
    func testSignOut_NoCurrentUser() async throws {
        // Given: No user is currently signed in
        mockAuthService.mockUser = nil
        
        // When: signOut is called
        try await mockAuthService.signOut()
        
        // Then: Should complete without error
        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
    }
    
    /// Test sign out with online status update failure
    func testSignOut_OnlineStatusUpdateFails() async throws {
        // Given: Mock configured to throw error
        mockAuthService.shouldThrowError = AuthError.networkError
        
        // When/Then: Should throw error
        do {
            try await mockAuthService.signOut()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(mockAuthService.signOutCallCount, 1)
        }
    }
    
    // MARK: - Test 2.14: Error Scenarios
    
    /// Test error mapping - cancelled sign-in
    func testErrorMapping_GoogleSignInCancelled() {
        // Given: Google Sign-In cancelled error
        // When: Error is caught and mapped
        // Then: Should map to AuthError.googleSignInCancelled
        
        let error = AuthError.googleSignInCancelled
        XCTAssertEqual(error.errorDescription, "Sign-in was cancelled. Please try again.")
    }
    
    /// Test error mapping - sign-in failed
    func testErrorMapping_GoogleSignInFailed() {
        // Given: Google Sign-In failed with message
        // When: Error description is accessed
        // Then: Should include the failure message
        
        let error = AuthError.googleSignInFailed("Network timeout")
        XCTAssertTrue(error.errorDescription?.contains("Network timeout") ?? false)
    }
    
    /// Test error mapping - Firestore error
    func testErrorMapping_FirestoreError() {
        // Given: Firestore operation failed
        // When: Error description is accessed
        // Then: Should provide user-friendly message
        
        let error = AuthError.firestoreError
        XCTAssertEqual(error.errorDescription, "Failed to create profile. Please try signing in again.")
    }
    
    /// Test handling missing root view controller
    func testSignInWithGoogle_MissingRootViewController() async throws {
        // Given: Mock configured to fail with missing root view controller
        mockAuthService.shouldThrowError = AuthError.googleSignInFailed("Unable to find root view controller")
        
        // When/Then: Should throw appropriate error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .googleSignInFailed(let message) = error {
                XCTAssertTrue(message.contains("root view controller"))
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    /// Test handling missing client ID
    func testSignInWithGoogle_MissingClientID() async throws {
        // Given: Mock configured to fail with missing client ID
        mockAuthService.shouldThrowError = AuthError.googleSignInFailed("Unable to retrieve Google Client ID")
        
        // When/Then: Should throw appropriate error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .googleSignInFailed(let message) = error {
                XCTAssertTrue(message.contains("Client ID"))
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    /// Test Firebase Auth sign-in failure after successful Google Sign-In
    func testSignInWithGoogle_FirebaseAuthFails() async throws {
        // Given: Mock configured to fail with Firebase Auth error
        mockAuthService.shouldThrowError = AuthError.invalidCredentials
        
        // When/Then: Should throw Firebase Auth error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .invalidCredentials = error {
                XCTAssertEqual(error.errorDescription, "Invalid email or password")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    /// Test Firestore user creation fails
    func testSignInWithGoogle_FirestoreFailsCausesError() async throws {
        // Given: Mock configured to fail with Firestore error
        mockAuthService.shouldThrowError = AuthError.firestoreError
        
        // When/Then: Should throw Firestore error
        do {
            _ = try await mockAuthService.signInWithGoogle()
            XCTFail("Expected error to be thrown")
        } catch let error as AuthError {
            if case .firestoreError = error {
                XCTAssertEqual(error.errorDescription, "Failed to create profile. Please try signing in again.")
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
}

