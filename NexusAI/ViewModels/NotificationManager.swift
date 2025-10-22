//
//  NotificationManager.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

/// ViewModel for managing notification permissions and navigation from notifications
@MainActor
class NotificationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current notification authorization status
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    /// Conversation ID to navigate to when notification is tapped
    @Published var pendingConversationId: String?
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Methods
    
    /// Request notification permissions from the user
    /// - Returns: True if permissions were granted, false otherwise
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ NotificationManager: Failed to request permissions - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Check the current notification authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        
        print("ℹ️ NotificationManager: Authorization status - \(authorizationStatus.description)")
    }
    
    // MARK: - Navigation Methods
    
    /// Trigger navigation to a specific conversation
    /// - Parameter conversationId: The ID of the conversation to navigate to
    func navigateToConversation(conversationId: String) {
        print("📱 NotificationManager: Navigating to conversation - \(conversationId)")
        pendingConversationId = conversationId
    }
    
    /// Clear pending navigation after it's been handled
    func clearPendingNavigation() {
        pendingConversationId = nil
    }
}

// MARK: - UNAuthorizationStatus Extension

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
}

