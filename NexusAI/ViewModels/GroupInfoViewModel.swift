//
//  GroupInfoViewModel.swift
//  NexusAI
//
//  Created on October 22, 2025.
//

import Foundation
import Combine
import FirebaseAuth

/// ViewModel for managing group info screen
@MainActor
class GroupInfoViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All participants in the group
    @Published var participants: [User] = []
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let conversation: Conversation
    
    /// Current user ID
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Local-First Sync Dependencies (if enabled)
    
    private var userRepository: UserRepositoryProtocol?
    
    // MARK: - Legacy Dependencies (if local-first disabled)
    
    private var authService: AuthService?
    
    // MARK: - Initialization
    
    init(conversation: Conversation, userRepository: UserRepositoryProtocol? = nil) {
        self.conversation = conversation
        
        // Set up dependencies based on feature flag
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            self.userRepository = userRepository ?? RepositoryFactory.shared.userRepository
            print("✅ GroupInfoViewModel using local-first sync (UserRepository)")
        } else {
            self.authService = AuthService()
            print("✅ GroupInfoViewModel using legacy Firebase services")
        }
        
        Task {
            await loadParticipants()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all participant details from repository or Firestore
    func loadParticipants() async {
        isLoading = true
        errorMessage = nil
        
        var loadedUsers: [User] = []
        
        // Fetch user details for each participant
        for participantId in conversation.participantIds {
            do {
                let user: User?
                
                // Use repository if available, otherwise use auth service
                if let repository = userRepository {
                    // Repository mode: fetch from local database
                    user = try await repository.getUser(userId: participantId)
                } else if let service = authService {
                    // Legacy mode: fetch from Firestore
                    user = try await service.getUserProfile(userId: participantId)
                } else {
                    print("⚠️ No user data source available")
                    continue
                }
                
                // Add user if successfully loaded
                if let user = user {
                    loadedUsers.append(user)
                }
                
            } catch {
                print("Failed to load user \(participantId): \(error.localizedDescription)")
                // Continue loading other users even if one fails
            }
        }
        
        // Sort participants
        let sortedUsers = sortParticipants(loadedUsers)
        
        await MainActor.run {
            self.participants = sortedUsers
            self.isLoading = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Sort participants: current user first, then online users, then offline, then alphabetically
    private func sortParticipants(_ users: [User]) -> [User] {
        return users.sorted { user1, user2 in
            // Current user always first
            if user1.id == currentUserId {
                return true
            }
            if user2.id == currentUserId {
                return false
            }
            
            // Then by online status (treat nil as false)
            let user1Online = user1.isOnline ?? false
            let user2Online = user2.isOnline ?? false
            if user1Online != user2Online {
                return user1Online
            }
            
            // Then alphabetically by display name
            return user1.displayName.lowercased() < user2.displayName.lowercased()
        }
    }
}

