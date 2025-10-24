//
//  NetworkMonitoring.swift
//  NexusAI
//
//  Created on 10/23/25.
//

import Foundation
import Combine

/// Protocol for network monitoring, allowing for dependency injection and testing
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

