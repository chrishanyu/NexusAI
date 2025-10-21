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
    
    // Auth state management at app level
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            // Show LoginView if not authenticated, otherwise show main content
            if authViewModel.isAuthenticated {
                // Authenticated - show main app (placeholder for now)
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                // Not authenticated - show login screen
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
