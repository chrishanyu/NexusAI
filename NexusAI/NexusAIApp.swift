//
//  NexusAIApp.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/20/25.
//

import SwiftUI
import FirebaseCore

@main
struct NexusApp: App {
    
    // Integrate AppDelegate for notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // State management at app level
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var bannerManager: NotificationBannerManager
    
    init() {
        FirebaseApp.configure()
        
        // Initialize banner manager with notification manager reference
        let notificationMgr = NotificationManager()
        let bannerMgr = NotificationBannerManager(notificationManager: notificationMgr)
        
        _notificationManager = StateObject(wrappedValue: notificationMgr)
        _bannerManager = StateObject(wrappedValue: bannerMgr)
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
    }
}
