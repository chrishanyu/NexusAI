//
//  NotificationService.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import UserNotifications

/// Service for handling push notifications and notification delegate methods
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    
    /// Weak reference to NotificationManager for navigation coordination
    weak var notificationManager: NotificationManager?
    
    // MARK: - Initialization
    
    /// Initialize with a reference to NotificationManager
    /// - Parameter notificationManager: The notification manager to coordinate with
    init(notificationManager: NotificationManager?) {
        self.notificationManager = notificationManager
        super.init()
    }
    
    // MARK: - UNUserNotificationCenterDelegate Methods
    
    /// Handle notification when app is in foreground
    /// - Parameters:
    ///   - center: The notification center
    ///   - notification: The notification to present
    /// - Returns: Presentation options (banner, sound, etc.)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("🔔 NotificationService: Will present notification in foreground")
        
        // Show banner and play sound even when app is in foreground
        return [.banner, .sound]
    }
    
    /// Handle notification tap/interaction
    /// - Parameters:
    ///   - center: The notification center
    ///   - response: The user's response to the notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("🔔 NotificationService: Did receive notification response")
        
        // Only handle default action (notification tap)
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            print("⚠️ NotificationService: Ignoring non-default action")
            return
        }
        
        // Parse the notification payload
        let userInfo = response.notification.request.content.userInfo
        let (conversationId, _) = parseNotificationPayload(userInfo)
        
        // Trigger navigation if we have a valid conversationId
        if let conversationId = conversationId {
            print("✅ NotificationService: Triggering navigation to conversation: \(conversationId)")
            
            // Use MainActor to ensure UI updates happen on main thread
            await MainActor.run {
                notificationManager?.navigateToConversation(conversationId: conversationId)
            }
        } else {
            print("❌ NotificationService: No valid conversationId in notification payload")
        }
    }
    
    // MARK: - Payload Parsing
    
    /// Parse notification payload to extract conversation and sender information
    /// - Parameter userInfo: The notification payload dictionary
    /// - Returns: Tuple containing conversationId and senderId (both optional)
    func parseNotificationPayload(_ userInfo: [AnyHashable: Any]) -> (conversationId: String?, senderId: String?) {
        print("📦 NotificationService: Parsing notification payload")
        
        // Extract conversationId
        let conversationId = userInfo["conversationId"] as? String
        
        // Extract senderId
        let senderId = userInfo["senderId"] as? String
        
        // Log results
        if let conversationId = conversationId {
            print("✅ NotificationService: Found conversationId: \(conversationId)")
        } else {
            print("⚠️ NotificationService: Missing conversationId in payload")
        }
        
        if let senderId = senderId {
            print("✅ NotificationService: Found senderId: \(senderId)")
        } else {
            print("⚠️ NotificationService: Missing senderId in payload")
        }
        
        // Log other payload fields for debugging
        if let messageText = userInfo["messageText"] as? String {
            print("📝 NotificationService: Message preview: \(messageText)")
        }
        
        if let senderName = userInfo["senderName"] as? String {
            print("👤 NotificationService: Sender name: \(senderName)")
        }
        
        return (conversationId, senderId)
    }
}

