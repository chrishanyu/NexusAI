//
//  MessageStatusView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// View that displays message delivery status with icons
struct MessageStatusView: View {
    // MARK: - Properties
    
    let status: MessageStatus
    let size: CGFloat
    
    // MARK: - Initialization
    
    init(status: MessageStatus, size: CGFloat = Constants.Dimensions.messageStatusIconSize) {
        self.status = status
        self.size = size
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if status == .delivered || status == .read {
                // Double checkmark for delivered and read
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: size))
                    Image(systemName: "checkmark")
                        .font(.system(size: size))
                }
                .foregroundColor(iconColor)
                .opacity(iconOpacity)
            } else {
                // Single icon for other states
                Image(systemName: iconName)
                    .font(.system(size: size))
                    .foregroundColor(iconColor)
                    .opacity(iconOpacity)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Icon name based on message status
    private var iconName: String {
        switch status {
        case .sending:
            return "clock.fill"
        case .sent:
            return "checkmark"
        case .delivered, .read:
            return "checkmark" // Will be doubled in body
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }
    
    /// Icon color based on message status
    private var iconColor: Color {
        switch status {
        case .sending:
            return Constants.Colors.statusSending
        case .sent:
            return Constants.Colors.statusSent
        case .delivered:
            return Constants.Colors.statusDelivered
        case .read:
            return Constants.Colors.statusRead // Blue for read
        case .failed:
            return Constants.Colors.statusFailed
        }
    }
    
    /// Icon opacity based on message status
    private var iconOpacity: Double {
        switch status {
        case .sending, .sent, .delivered:
            return 0.7 // Subtle gray states
        case .read:
            return 1.0 // Full opacity for blue read state
        case .failed:
            return 1.0 // Full opacity for failed state
        }
    }
}

// MARK: - Preview

#Preview("All Status Types") {
    VStack(spacing: 30) {
        VStack(spacing: 12) {
            Text("Status Indicators")
                .font(.headline)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    MessageStatusView(status: .sending, size: 16)
                    Text("Sending")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    MessageStatusView(status: .sent, size: 16)
                    Text("Sent")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    MessageStatusView(status: .delivered, size: 16)
                    Text("Delivered")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    MessageStatusView(status: .read, size: 16)
                    Text("Read")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    MessageStatusView(status: .failed, size: 16)
                    Text("Failed")
                        .font(.caption)
                }
            }
        }
        
        Divider()
        
        VStack(spacing: 12) {
            Text("Different Sizes")
                .font(.headline)
            
            HStack(spacing: 30) {
                MessageStatusView(status: .read, size: 10)
                MessageStatusView(status: .read, size: 12)
                MessageStatusView(status: .read, size: 14)
                MessageStatusView(status: .read, size: 16)
                MessageStatusView(status: .read, size: 18)
                MessageStatusView(status: .read, size: 20)
            }
        }
    }
    .padding()
}

#Preview("In Message Context") {
    VStack(spacing: 16) {
        // Sent message bubble
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Hey, how are you?")
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text("2:34 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    MessageStatusView(status: .read)
                }
            }
        }
        .padding(.horizontal)
        
        // Another sent message
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("This message was just delivered")
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text("2:35 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    MessageStatusView(status: .delivered)
                }
            }
        }
        .padding(.horizontal)
        
        // Sending message
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("This is still sending...")
                    .padding(12)
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text("2:36 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    MessageStatusView(status: .sending)
                }
            }
        }
        .padding(.horizontal)
    }
    .padding(.vertical)
}

#Preview("Status Progression") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Message Status Progression")
                .font(.title2)
                .fontWeight(.bold)
            
            // Step 1
            HStack {
                VStack(alignment: .leading) {
                    Text("1. Sending")
                        .font(.headline)
                    Text("Message queued locally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                MessageStatusView(status: .sending, size: 20)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Image(systemName: "arrow.down")
                .foregroundColor(.secondary)
            
            // Step 2
            HStack {
                VStack(alignment: .leading) {
                    Text("2. Sent")
                        .font(.headline)
                    Text("Confirmed by server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                MessageStatusView(status: .sent, size: 20)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Image(systemName: "arrow.down")
                .foregroundColor(.secondary)
            
            // Step 3
            HStack {
                VStack(alignment: .leading) {
                    Text("3. Delivered")
                        .font(.headline)
                    Text("Received by recipient")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                MessageStatusView(status: .delivered, size: 20)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Image(systemName: "arrow.down")
                .foregroundColor(.secondary)
            
            // Step 4
            HStack {
                VStack(alignment: .leading) {
                    Text("4. Read")
                        .font(.headline)
                    Text("Opened by recipient")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                MessageStatusView(status: .read, size: 20)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
}

