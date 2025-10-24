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
/// Listens to LocalDatabase changes and displays banners for new messages in other conversations
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
    
    /// Local database for observing message changes
    private let database: LocalDatabase
    
    /// Combine cancellables for observation
    private var cancellables = Set<AnyCancellable>()
    
    /// Track processed message IDs to avoid duplicate banners
    private var processedMessageIds = Set<String>()
    
    /// Track if this is the first snapshot (skip showing banners for existing messages)
    private var isInitialLoad = true
    
    // MARK: - Initialization
    
    /// Initialize with optional NotificationManager reference and database
    /// - Parameters:
    ///   - notificationManager: The notification manager for handling navigation
    ///   - database: The local database instance
    init(
        notificationManager: NotificationManager? = nil,
        database: LocalDatabase? = nil
    ) {
        self.notificationManager = notificationManager
        self.database = database ?? LocalDatabase.shared
        print("ℹ️ NotificationBannerManager: Initialized (local-first architecture)")
    }
    
    /// Start listening for messages - observes LocalDatabase changes
    func startListening() {
        print("🎬 NotificationBannerManager: startListening() called")
        print("🔄 NotificationBannerManager: Setting up LocalDatabase observer")
        observeLocalDatabaseChanges()
        print("✅ NotificationBannerManager: LocalDatabase observer started")
    }
    
    /// Clean up observers when deinitializing
    deinit {
        cancellables.removeAll()
        print("🧹 NotificationBannerManager: Observers removed")
    }
    
    // MARK: - LocalDatabase Observer Methods
    
    /// Observe LocalDatabase changes for new messages
    private func observeLocalDatabaseChanges() {
        print("👂 NotificationBannerManager: Observing LocalDatabase for new messages")
        
        // Observe database change notifications
        NotificationCenter.default
            .publisher(for: .localDatabaseDidChange)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.checkForNewMessages()
                }
            }
            .store(in: &cancellables)
        
        // Perform initial check after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.isInitialLoad = false
            print("✅ NotificationBannerManager: Initial load complete, now monitoring for new messages")
        }
    }
    
    /// Check for new messages in LocalDatabase
    private func checkForNewMessages() async {
        // Skip if still in initial load
        guard !isInitialLoad else { return }
        
        do {
            // Query for recent messages (last 5 minutes)
            let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
            
            let predicate = #Predicate<LocalMessage> { message in
                message.timestamp > fiveMinutesAgo
            }
            
            let recentMessages = try database.fetch(LocalMessage.self, where: predicate)
            
            // Process messages that haven't been processed yet
            for localMessage in recentMessages {
                let messageId = localMessage.id
                
                // Skip if already processed
                guard !processedMessageIds.contains(messageId) else {
                    continue
                }
                
                // Convert to Message and handle
                let message = localMessage.toMessage()
                handleNewMessage(message)
                processedMessageIds.insert(messageId)
            }
            
            // Clean up old processed IDs (keep last 100)
            if processedMessageIds.count > 100 {
                let oldestToRemove = processedMessageIds.count - 100
                processedMessageIds = Set(processedMessageIds.dropFirst(oldestToRemove))
            }
            
        } catch {
            print("⚠️ NotificationBannerManager: Error querying messages - \(error.localizedDescription)")
        }
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

