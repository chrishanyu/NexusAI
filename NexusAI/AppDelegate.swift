//
//  AppDelegate.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import UIKit
import UserNotifications

/// AppDelegate for handling app lifecycle and notification setup
class AppDelegate: NSObject, UIApplicationDelegate {
    
    // MARK: - Properties
    
    /// Notification service for handling notification delegate methods
    var notificationService: NotificationService?
    
    // MARK: - UIApplicationDelegate Methods
    
    /// Called when app finishes launching
    /// - Parameters:
    ///   - application: The application instance
    ///   - launchOptions: Launch options dictionary
    /// - Returns: True if launch was successful
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🚀 AppDelegate: Application did finish launching")
        
        // Notification service will be set up later from NexusApp
        // after NotificationManager is initialized
        
        return true
    }
    
    // MARK: - Notification Setup
    
    /// Set up notification center delegate with the notification service
    /// - Parameter notificationManager: The notification manager to coordinate with
    func setupNotifications(with notificationManager: NotificationManager) {
        print("🔔 AppDelegate: Setting up notification center delegate")
        
        // Create notification service with reference to manager
        notificationService = NotificationService(notificationManager: notificationManager)
        
        // Set as the delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = notificationService
        
        print("✅ AppDelegate: Notification center delegate configured")
    }
}

