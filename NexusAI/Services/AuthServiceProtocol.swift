//
//  AuthServiceProtocol.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Protocol for authentication operations - enables testing with mocks
protocol AuthServiceProtocol {
    func signInWithGoogle() async throws -> NexusAI.User
    func signOut() async throws
    func saveUserProfile(_ user: NexusAI.User) async throws
    func getUserProfile(userId: String) async throws -> NexusAI.User
    func updateOnlineStatus(userId: String, isOnline: Bool) async throws
}

// Extend AuthService to conform to protocol
extension AuthService: AuthServiceProtocol {}

