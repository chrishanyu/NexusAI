//
//  RealtimePresenceService.swift
//  NexusAI
//
//  Created on 10/24/25.
//

import Foundation
import FirebaseDatabase
import FirebaseFirestore
import Combine

/// Advanced presence service using Firebase Realtime Database with offline support
/// Provides reliable online/offline status tracking with server-side disconnect detection
///
/// Features:
/// - Server-side disconnect detection via onDisconnect()
/// - Heartbeat mechanism (30s interval)
/// - Offline queue for failed updates
/// - Stale presence detection (>60s)
/// - 5-second background delay
///
/// Usage:
/// ```swift
/// let service = RealtimePresenceService.shared
/// service.initializePresence(for: userId)
/// try await service.setUserOnline(userId: userId)
/// ```
class RealtimePresenceService {
    
    // MARK: - Singleton
    
    static let shared = RealtimePresenceService()
    
    // MARK: - Private Properties
    
    private let rtdb: DatabaseReference
    private let firestore: Firestore
    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var presenceRef: DatabaseReference?
    private var connectionStateHandle: DatabaseHandle?
    private var isInitialized = false
    
    /// Heartbeat interval in seconds (refresh presence every 30s)
    private let heartbeatInterval: TimeInterval = 30.0
    
    /// Background delay before setting user offline (5 seconds)
    private let backgroundDelay: TimeInterval = 5.0
    
    /// Stale threshold - presence is stale if heartbeat is older than 60s
    private let staleThreshold: TimeInterval = 60.0
    
    /// Presence queue for offline updates
    private let presenceQueue = PresenceQueue()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize Firebase Realtime Database
        self.rtdb = FirebaseService.shared.database
        self.firestore = FirebaseService.shared.db
        
        // Set up network monitoring
        setupNetworkMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Initialize presence tracking for a user
    /// Call this once when the user becomes authenticated
    /// - Parameter userId: The user's Firebase Auth UID
    func initializePresence(for userId: String) {
        guard !isInitialized else {
            return
        }
        
        // Set up presence reference path: presence/{userId}
        presenceRef = rtdb.child("presence").child(userId)
        
        // Set up connection state monitoring
        setupConnectionStateMonitoring(userId: userId)
        
        // Start heartbeat
        startHeartbeat(userId: userId)
        
        isInitialized = true
    }
    
    /// Set user online
    /// - Parameter userId: The user's Firebase Auth UID
    func setUserOnline(userId: String) async throws {
        guard let presenceRef = presenceRef else {
            throw RealtimePresenceError.notInitialized
        }
        
        let timestamp = ServerValue.timestamp()
        let presenceData: [String: Any] = [
            "isOnline": true,
            "lastSeen": timestamp,
            "lastHeartbeat": timestamp
        ]
        
        do {
            // Update RTDB (real-time presence)
            try await presenceRef.setValue(presenceData)
            
            // Also update Firestore (for persistence and queries)
            try await updateFirestorePresence(userId: userId, isOnline: true)
        } catch {
            print("❌ Failed to set user online: \(error.localizedDescription)")
            
            // Queue update if offline
            if !NetworkMonitor.shared.isConnected {
                await presenceQueue.enqueue(userId: userId, isOnline: true)
                print("📦 Queued online status for later")
            }
            
            throw RealtimePresenceError.updateFailed
        }
    }
    
    /// Set user offline with optional delay
    /// - Parameters:
    ///   - userId: The user's Firebase Auth UID
    ///   - delay: Delay in seconds before setting offline (default: 5s)
    func setUserOffline(userId: String, delay: TimeInterval? = nil) async throws {
        let delayTime = delay ?? backgroundDelay
        
        // Wait for delay (allows user to quickly return to app)
        if delayTime > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayTime * 1_000_000_000))
        }
        
        guard let presenceRef = presenceRef else {
            throw RealtimePresenceError.notInitialized
        }
        
        let timestamp = ServerValue.timestamp()
        let presenceData: [String: Any] = [
            "isOnline": false,
            "lastSeen": timestamp,
            "lastHeartbeat": timestamp
        ]
        
        do {
            // Update RTDB
            try await presenceRef.setValue(presenceData)
            
            // Update Firestore
            try await updateFirestorePresence(userId: userId, isOnline: false)
            
            print("✅ User set offline: \(userId)")
        } catch {
            print("❌ Failed to set user offline: \(error.localizedDescription)")
            
            // Queue update if offline
            if !NetworkMonitor.shared.isConnected {
                await presenceQueue.enqueue(userId: userId, isOnline: false)
                print("📦 Queued offline status for later")
            }
            
            throw RealtimePresenceError.updateFailed
        }
    }
    
    /// Listen to a user's presence status
    /// - Parameters:
    ///   - userId: The user's Firebase Auth UID
    ///   - onChange: Callback with (isOnline, lastSeen)
    /// - Returns: Listener handle for cleanup
    func listenToPresence(userId: String, onChange: @escaping (Bool, Date?) -> Void) -> DatabaseHandle {
        let userPresenceRef = rtdb.child("presence").child(userId)
        
        let handle = userPresenceRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            guard let data = snapshot.value as? [String: Any] else {
                onChange(false, nil)
                return
            }
            
            let isOnline = data["isOnline"] as? Bool ?? false
            let lastSeenTimestamp = data["lastSeen"] as? TimeInterval
            let lastSeen = lastSeenTimestamp.map { Date(timeIntervalSince1970: $0 / 1000) }
            
            // Check for stale presence (heartbeat older than 60s = offline)
            if let heartbeatTimestamp = data["lastHeartbeat"] as? TimeInterval {
                let heartbeatDate = Date(timeIntervalSince1970: heartbeatTimestamp / 1000)
                let isStale = Date().timeIntervalSince(heartbeatDate) > self.staleThreshold
                
                if isStale && isOnline {
                    // Presence is stale - consider user offline
                    onChange(false, lastSeen)
                    return
                }
            }
            
            onChange(isOnline, lastSeen)
        }
        
        return handle
    }
    
    /// Listen to multiple users' presence
    /// - Parameters:
    ///   - userIds: Array of user IDs to track
    ///   - onChange: Callback with presence map (userId -> isOnline)
    /// - Returns: Array of listener handles for cleanup
    func listenToMultiplePresence(userIds: [String], onChange: @escaping ([String: Bool]) -> Void) -> [DatabaseHandle] {
        var handles: [DatabaseHandle] = []
        var presenceMap: [String: Bool] = [:]
        
        // Listen to each user individually (RTDB doesn't have 'in' query limitation like Firestore)
        for userId in userIds {
            let handle = listenToPresence(userId: userId) { isOnline, _ in
                presenceMap[userId] = isOnline
                onChange(presenceMap)
            }
            handles.append(handle)
        }
        
        return handles
    }
    
    /// Stop listening to presence
    /// - Parameters:
    ///   - userId: User ID to stop listening to
    ///   - handle: Listener handle from listenToPresence
    func removePresenceListener(userId: String, handle: DatabaseHandle) {
        let userPresenceRef = rtdb.child("presence").child(userId)
        userPresenceRef.removeObserver(withHandle: handle)
    }
    
    /// Clean up all resources
    func cleanup() {
        // Stop and remove heartbeat timer
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        // Remove connection state listener to prevent memory leak
        if let handle = connectionStateHandle {
            Database.database().reference(withPath: ".info/connected")
                .removeObserver(withHandle: handle)
            connectionStateHandle = nil
        }
        
        // Clear other resources
        presenceRef = nil
        cancellables.removeAll()
        isInitialized = false
    }
    
    // MARK: - Private Methods
    
    /// Set up connection state monitoring with onDisconnect() callback
    private func setupConnectionStateMonitoring(userId: String) {
        guard let presenceRef = presenceRef else { return }
        
        // Remove existing listener if any
        if let handle = connectionStateHandle {
            Database.database().reference(withPath: ".info/connected")
                .removeObserver(withHandle: handle)
        }
        
        // Listen to connection state
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        
        connectionStateHandle = connectedRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            guard let connected = snapshot.value as? Bool, connected else {
                print("⚠️ Disconnected from Firebase RTDB")
                return
            }
            
            print("✅ Connected to Firebase RTDB")
            
            // Set up onDisconnect callback (server-side!)
            let disconnectData: [String: Any] = [
                "isOnline": false,
                "lastSeen": ServerValue.timestamp(),
                "lastHeartbeat": ServerValue.timestamp()
            ]
            
            presenceRef.onDisconnectSetValue(disconnectData) { error, _ in
                if let error = error {
                    print("❌ Failed to set onDisconnect: \(error.localizedDescription)")
                } else {
                    print("✅ onDisconnect callback registered")
                }
            }
            
            // Set user online now that we're connected
            Task {
                try? await self.setUserOnline(userId: userId)
            }
        }
    }
    
    /// Start heartbeat timer to keep presence fresh
    private func startHeartbeat(userId: String) {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let presenceRef = self.presenceRef else { return }
            
            // Only send heartbeat if we think we're online
            guard NetworkMonitor.shared.isConnected else { return }
            
            // Update heartbeat timestamp
            presenceRef.child("lastHeartbeat").setValue(ServerValue.timestamp()) { error, _ in
                if let error = error {
                    print("⚠️ Heartbeat failed: \(error.localizedDescription)")
                } else {
                    #if DEBUG
                    print("💓 Heartbeat sent")
                    #endif
                }
            }
        }
        
        // Fire immediately
        heartbeatTimer?.fire()
    }
    
    /// Update Firestore presence (for persistence and queries)
    private func updateFirestorePresence(userId: String, isOnline: Bool) async throws {
        try await firestore.collection(Constants.Collections.users)
            .document(userId)
            .updateData([
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ])
    }
    
    /// Set up network monitoring to handle reconnection
    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected {
                    Task {
                        await self.presenceQueue.flushQueue(using: self)
                    }
                } else {
                    print("📴 Network disconnected")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - RealtimePresenceError

enum RealtimePresenceError: LocalizedError {
    case updateFailed
    case userNotFound
    case notInitialized
    
    var errorDescription: String? {
        switch self {
        case .updateFailed:
            return "Failed to update presence"
        case .userNotFound:
            return "User not found"
        case .notInitialized:
            return "Presence service not initialized"
        }
    }
}

// MARK: - PresenceQueue

/// Actor for queuing presence updates when offline
/// Ensures thread-safe access to the queue and prevents race conditions
actor PresenceQueue {
    
    // MARK: - Private Properties
    
    /// Struct representing a queued presence update
    private struct QueuedPresenceUpdate {
        let userId: String
        let isOnline: Bool
        let timestamp: Date
    }
    
    /// Queue storage - keeps latest update per user
    private var queue: [String: QueuedPresenceUpdate] = [:]
    
    // MARK: - Initialization
    
    init() {
    }
    
    // MARK: - Public Methods
    
    /// Add a presence update to the queue
    /// Automatically deduplicates - only keeps the latest update per user
    /// - Parameters:
    ///   - userId: The user's Firebase Auth UID
    ///   - isOnline: Whether the user should be online or offline
    func enqueue(userId: String, isOnline: Bool) {
        let update = QueuedPresenceUpdate(
            userId: userId,
            isOnline: isOnline,
            timestamp: Date()
        )
        
        // Deduplicate: overwrite any existing update for this user
        queue[userId] = update
    }
    
    /// Flush all queued updates by sending them to the service
    /// - Parameter service: The RealtimePresenceService to use for sending updates
    func flushQueue(using service: RealtimePresenceService) async {
        guard !queue.isEmpty else {
            print("📭 Queue is empty, nothing to flush")
            return
        }
        
        // Get all updates and clear the queue
        let updates = queue.values.sorted { $0.timestamp < $1.timestamp }
        queue.removeAll()
        
        // Send each update
        for update in updates {
            do {
                if update.isOnline {
                    try await service.setUserOnline(userId: update.userId)
                } else {
                    try await service.setUserOffline(userId: update.userId, delay: 0)
                }
            } catch {
                // Re-queue failed update
                queue[update.userId] = update
                print("🔄 Re-queued failed update for \(update.userId)")
            }
        }
        
        if !queue.isEmpty {
            print("⚠️ \(queue.count) updates failed and were re-queued")
        } else {
            print("✅ All queued updates flushed successfully")
        }
    }
    
    /// Get the current size of the queue
    /// Useful for debugging and monitoring
    /// - Returns: Number of queued updates
    func getQueueSize() -> Int {
        return queue.count
    }
}
