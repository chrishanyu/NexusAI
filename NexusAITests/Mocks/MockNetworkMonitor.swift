//
//  MockNetworkMonitor.swift
//  NexusAITests
//
//  Created on 10/23/25.
//

import Foundation
import Combine
import Network
@testable import NexusAI

/// Mock network monitor for testing network-dependent behavior
@MainActor
final class MockNetworkMonitor: ObservableObject, NetworkMonitoring {
    
    // Published property to allow manual control
    @Published var isConnected: Bool = true
    
    // Mock connection type
    @Published var connectionType: NWInterface.InterfaceType? = .wifi
    
    // Store the publisher for protocol conformance (marked nonisolated for safe access)
    nonisolated(unsafe) private let _isConnectedSubject: CurrentValueSubject<Bool, Never>
    
    /// Publisher for isConnected property (for NetworkMonitoring protocol conformance)
    nonisolated var isConnectedPublisher: AnyPublisher<Bool, Never> {
        _isConnectedSubject.eraseToAnyPublisher()
    }
    
    /// Public initializer for testing
    init(isConnected: Bool = true) {
        self._isConnectedSubject = CurrentValueSubject<Bool, Never>(isConnected)
        self.isConnected = isConnected
    }
    
    /// Simulate network connection
    func connect() {
        isConnected = true
        _isConnectedSubject.send(true)
    }
    
    /// Simulate network disconnection
    func disconnect() {
        isConnected = false
        _isConnectedSubject.send(false)
    }
    
    /// Simulate network reconnection (disconnect then connect)
    func reconnect() {
        disconnect()
        // Small delay to simulate real network transition
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            self.connect()
        }
    }
    
    func startMonitoring() {
        // Do nothing - we don't want real network monitoring in tests
    }
    
    func stopMonitoring() {
        // Do nothing
    }
}

