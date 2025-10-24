//
//  NexusAIApp.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/20/25.
//

import SwiftUI
import FirebaseCore
import UIKit

@main
struct NexusApp: App {
    
    // Integrate AppDelegate for notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // State management at app level
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var bannerManager: NotificationBannerManager
    
    // Scene phase for handling app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Disable verbose Firebase logging
        FirebaseConfiguration.shared.setLoggerLevel(.error)
        
        FirebaseApp.configure()
        
        // Initialize banner manager with notification manager reference
        let notificationMgr = NotificationManager()
        let bannerMgr = NotificationBannerManager(notificationManager: notificationMgr)
        
        _notificationManager = StateObject(wrappedValue: notificationMgr)
        _bannerManager = StateObject(wrappedValue: bannerMgr)
        
        // Initialize local-first sync framework if enabled
        if Constants.FeatureFlags.isLocalFirstSyncEnabled {
            // RepositoryFactory is a singleton - no need to store it
            // It's accessed via RepositoryFactory.shared wherever needed
            
            // Initialize and start sync engine on the main actor
            Task { @MainActor in
                let engine = SyncEngine()
                engine.start()
                print("✅ SyncEngine initialized and started")
            }
        } else {
            print("ℹ️ Local-first sync disabled - using legacy Firebase direct access")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Show LoginView if not authenticated, otherwise show main content
            if authViewModel.isAuthenticated {
                // Authenticated - show main app with banner overlay
                ContentView()
                    .environmentObject(authViewModel)
                    .environmentObject(notificationManager)
                    .environmentObject(bannerManager)
                    .onAppear {
                        print("📱 NexusApp: ContentView appeared - starting setup")
                        
                        // Set up notification delegate
                        appDelegate.setupNotifications(with: notificationManager)
                        
                        // Start banner manager listener
                        print("📱 NexusApp: About to start banner manager listener")
                        bannerManager.startListening()
                        print("📱 NexusApp: Banner manager listener started")
                        
                        // Request notification permissions
                        Task {
                            let granted = await notificationManager.requestPermissions()
                            if granted {
                                print("✅ Notification permissions granted")
                            } else {
                                print("⚠️ Notification permissions denied")
                            }
                        }
                    }
            } else {
                // Not authenticated - show login screen
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // MARK: - Scene Phase Handling
    
    /// Handle app lifecycle changes for presence tracking
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            // Use RealtimePresenceService for robust presence tracking
            let presenceService = RealtimePresenceService.shared
            
            switch newPhase {
            case .active:
                // App became active - initialize presence and set user online
                presenceService.initializePresence(for: userId)
                
                do {
                    try await presenceService.setUserOnline(userId: userId)
                    print("👥 App became active - user set to online (RTDB)")
                } catch {
                    print("⚠️ Failed to set user online: \(error.localizedDescription)")
                }
                
            case .background:
                // App went to background - set user offline IMMEDIATELY (no delay)
                // Request background time to ensure the operation completes
                var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
                backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                    // If we run out of time, end the task
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                    print("⚠️ Background task expired before completing offline status update")
                }
                
                do {
                    try await presenceService.setUserOffline(userId: userId, delay: 0)
                    print("👥 App went to background - user set offline immediately")
                } catch {
                    print("⚠️ Failed to set user offline: \(error.localizedDescription)")
                }
                
                // End the background task
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
                
                // Note: onDisconnect() callback will also handle offline status
                // if the app is force-quit or connection is lost
                
            case .inactive:
                // App is temporarily inactive (e.g., phone call, notification center)
                // Don't change presence status - user is still "using" the app
                break
                
            @unknown default:
                break
            }
        }
    }
}
