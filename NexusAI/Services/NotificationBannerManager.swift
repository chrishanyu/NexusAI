//
//  NotificationBannerManager.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Service for managing in-app notification banners
/// Listens to new messages and displays banners for messages in other conversations
@MainActor
class NotificationBannerManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently displayed banner (nil if no banner showing)
    @Published var currentBanner: BannerData?
    
    /// Queue of pending banners to show
    @Published var bannerQueue: [BannerData] = []
    
    // MARK: - Properties
    
    /// ID of the currently open conversation (to filter out banners for it)
    var currentConversationId: String?
    
    /// Current user's ID (to filter out own messages)
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    /// Weak reference to NotificationManager for navigation coordination
    weak var notificationManager: NotificationManager?
    
    /// Firestore database reference (use shared instance to avoid settings conflict)
    private var db: Firestore {
        FirebaseService.shared.db
    }
    
    /// Listener registration for managing the Firestore listener lifecycle
    private var messageListener: ListenerRegistration?
    
    /// Track if this is the first snapshot (skip showing banners for existing messages)
    private var isInitialLoad = true
    
    // MARK: - Initialization
    
    /// Initialize with optional NotificationManager reference
    /// - Parameter notificationManager: The notification manager for handling navigation
    init(notificationManager: NotificationManager? = nil) {
        self.notificationManager = notificationManager
        print("ℹ️ NotificationBannerManager: Initialized")
    }
    
    /// Start listening for messages - should be called after app is fully initialized
    func startListening() {
        print("🎬 NotificationBannerManager: startListening() called")
        
        guard messageListener == nil else {
            print("⚠️ NotificationBannerManager: Listener already started")
            return
        }
        
        print("🔄 NotificationBannerManager: About to call listenForMessages()")
        listenForMessages()
        print("✅ NotificationBannerManager: listenForMessages() completed")
    }
    
    /// Clean up listener when deinitializing
    deinit {
        messageListener?.remove()
        print("🧹 NotificationBannerManager: Listener removed")
    }
    
    // MARK: - Firestore Listener Methods
    
    /// Start listening for new messages across all conversations
    func listenForMessages() {
        print("👂 NotificationBannerManager: Starting Firestore listener for messages")
        
        // Use collectionGroup to listen across all conversations
        // Note: Removed ordering to avoid requiring a composite index
        messageListener = db.collectionGroup("messages")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                // Handle errors
                if let error = error {
                    print("❌ NotificationBannerManager: Listener error - \(error.localizedDescription)")
                    return
                }
                
                // Process document changes
                guard let snapshot = snapshot else {
                    print("⚠️ NotificationBannerManager: No snapshot received")
                    return
                }
                
                // Skip initial load to avoid showing banners for existing messages
                if self.isInitialLoad {
                    print("ℹ️ NotificationBannerManager: Initial load - skipping \(snapshot.documents.count) existing messages")
                    self.isInitialLoad = false
                    return
                }
                
                // Only process newly added messages
                print("📬 NotificationBannerManager: Received \(snapshot.documentChanges.count) document changes")
                for change in snapshot.documentChanges where change.type == .added {
                    do {
                        let message = try change.document.data(as: Message.self)
                        print("📨 NotificationBannerManager: New message detected from \(message.senderName)")
                        Task { @MainActor in
                            self.handleNewMessage(message)
                        }
                    } catch {
                        print("⚠️ NotificationBannerManager: Failed to parse message - \(error.localizedDescription)")
                    }
                }
            }
        
        print("✅ NotificationBannerManager: Listener started successfully")
    }
    
    /// Handle a new message and determine if a banner should be shown
    /// - Parameter message: The new message to process
    func handleNewMessage(_ message: Message) {
        print("📨 NotificationBannerManager: Processing new message from \(message.senderName)")
        
        // Filter: Don't show banner for own messages
        guard message.senderId != currentUserId else {
            print("🚫 NotificationBannerManager: Skipping own message")
            return
        }
        
        // Filter: Don't show banner for currently open conversation
        guard message.conversationId != currentConversationId else {
            print("🚫 NotificationBannerManager: Skipping message in current conversation")
            return
        }
        
        // Create banner data and show
        let bannerData = BannerData(from: message)
        print("✅ NotificationBannerManager: Creating banner for message")
        showBanner(bannerData)
    }
    
    // MARK: - Banner Display Methods
    
    /// Show a banner (or add to queue if one is already showing)
    /// - Parameter bannerData: The banner data to display
    func showBanner(_ bannerData: BannerData) {
        print("📢 NotificationBannerManager: Request to show banner for conversation: \(bannerData.conversationId)")
        
        // If no banner is currently showing, display immediately
        if currentBanner == nil {
            currentBanner = bannerData
            print("✅ NotificationBannerManager: Displaying banner immediately")
            
            // Auto-dismiss after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                
                // Only dismiss if this banner is still showing (user hasn't interacted)
                if currentBanner?.id == bannerData.id {
                    dismissBanner()
                }
            }
        } else {
            // Banner already showing, add to queue
            if bannerQueue.count < 3 { // Max queue size of 3
                bannerQueue.append(bannerData)
                print("📋 NotificationBannerManager: Added to queue (queue size: \(bannerQueue.count))")
            } else {
                print("⚠️ NotificationBannerManager: Queue full, dropping oldest banner")
                bannerQueue.removeFirst()
                bannerQueue.append(bannerData)
            }
        }
    }
    
    /// Dismiss the current banner and show next in queue if available
    func dismissBanner() {
        print("❌ NotificationBannerManager: Dismissing banner")
        currentBanner = nil
        
        // Check if there are banners in queue
        if !bannerQueue.isEmpty {
            let nextBanner = bannerQueue.removeFirst()
            print("➡️ NotificationBannerManager: Showing next banner from queue")
            showBanner(nextBanner)
        }
    }
    
    // MARK: - Navigation Methods
    
    /// Handle banner tap - navigate to conversation and dismiss
    func handleBannerTap() {
        guard let banner = currentBanner else { return }
        
        print("👆 NotificationBannerManager: Banner tapped, navigating to: \(banner.conversationId)")
        
        // Trigger navigation via NotificationManager
        notificationManager?.navigateToConversation(conversationId: banner.conversationId)
        
        // Dismiss banner immediately
        dismissBanner()
    }
    
    // MARK: - Conversation Tracking Methods
    
    /// Set the currently open conversation to filter banners
    /// - Parameter conversationId: The ID of the open conversation (nil if none)
    func setCurrentConversation(id: String?) {
        currentConversationId = id
        
        if let id = id {
            print("🔍 NotificationBannerManager: Current conversation set to: \(id)")
            
            // Remove any queued banners for this conversation
            bannerQueue.removeAll { $0.conversationId == id }
            
            // Dismiss current banner if it's for this conversation
            if currentBanner?.conversationId == id {
                dismissBanner()
            }
        } else {
            print("🔍 NotificationBannerManager: No conversation currently open")
        }
    }
}

