//
//  FirebaseService.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Singleton service for Firebase initialization and configuration
class FirebaseService {
    
    // MARK: - Singleton
    static let shared = FirebaseService()
    
    // MARK: - Properties
    let db: Firestore
    let auth: Auth
    
    // MARK: - Initialization
    private init() {
        // Firebase is initialized in the App file
        // Here we just configure Firestore settings
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        
        configureFirestore()
    }
    
    // MARK: - Configuration
    private func configureFirestore() {
        let settings = FirestoreSettings()
        
        // Enable offline persistence for local caching
        // Cache size (100 MB)
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
        
        db.settings = settings
    }
    
    // MARK: - Helper Methods
    
    /// Get current user ID
    var currentUserId: String? {
        return auth.currentUser?.uid
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return auth.currentUser != nil
    }
    
    /// Sign out current user
    func signOut() throws {
        try auth.signOut()
    }
}

