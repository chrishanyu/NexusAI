//
//  NetworkMonitor.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status using NWPathMonitor
class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for global network monitoring
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    /// Current network connection status
    @Published var isConnected: Bool = true
    
    /// Current network path status (for debugging)
    @Published var connectionType: NWInterface.InterfaceType?
    
    // MARK: - Private Properties
    
    /// Network path monitor instance
    private let monitor = NWPathMonitor()
    
    /// Background queue for network monitoring
    private let monitorQueue = DispatchQueue(label: "com.nexusai.networkmonitor", qos: .background)
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let isConnected = path.status == .satisfied
            let connectionType: NWInterface.InterfaceType? = {
                if path.usesInterfaceType(.wifi) {
                    return .wifi
                } else if path.usesInterfaceType(.cellular) {
                    return .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    return .wiredEthernet
                } else {
                    return nil
                }
            }()
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Update connection status on main thread
                self.isConnected = isConnected
                self.connectionType = connectionType
                
                // Log status changes
                print("Network status changed: \(isConnected ? "Connected" : "Disconnected")")
                if let type = connectionType {
                    print("Connection type: \(type)")
                }
            }
        }
        
        // Start monitoring on background queue
        monitor.start(queue: monitorQueue)
    }
    
    /// Stop monitoring network status
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - Deinitializer
    
    deinit {
        stopMonitoring()
    }
}

