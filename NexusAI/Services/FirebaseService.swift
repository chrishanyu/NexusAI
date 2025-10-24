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
import FirebaseDatabase

/// Singleton service for Firebase initialization and configuration
class FirebaseService {
    
    // MARK: - Singleton
    static let shared = FirebaseService()
    
    // MARK: - Properties
    let db: Firestore
    let auth: Auth
    let database: DatabaseReference
    
    // MARK: - Initialization
    private init() {
        // Firebase is initialized in the App file
        // Get Firestore instance
        let firestoreInstance = Firestore.firestore()
        
        // Configure settings IMMEDIATELY after getting instance, before any use
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
        firestoreInstance.settings = settings
        
        // Assign to properties
        self.db = firestoreInstance
        self.auth = Auth.auth()
        self.database = Database.database().reference()
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

