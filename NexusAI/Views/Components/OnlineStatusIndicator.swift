//
//  OnlineStatusIndicator.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// A small dot indicator that shows online/offline status
struct OnlineStatusIndicator: View {
    // MARK: - Properties
    
    let isOnline: Bool
    let size: CGFloat
    
    // MARK: - Initialization
    
    /// Creates an online status indicator
    /// - Parameters:
    ///   - isOnline: Whether the user is currently online
    ///   - size: Diameter of the status dot in points (default: 8pt)
    init(isOnline: Bool, size: CGFloat = 8) {
        self.isOnline = isOnline
        self.size = size
    }
    
    // MARK: - Body
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: size * 0.2)
            )
    }
    
    // MARK: - Computed Properties
    
    /// Color of the status dot based on online state
    private var statusColor: Color {
        isOnline ? .green : .gray
    }
}

// MARK: - View Extension for Easy Overlay

extension View {
    /// Adds an online status indicator as an overlay in the bottom-right corner
    /// - Parameters:
    ///   - isOnline: Whether the user is online
    ///   - show: Whether to show the indicator (useful for hiding on group conversations)
    /// - Returns: View with status indicator overlay
    func onlineStatusIndicator(isOnline: Bool, show: Bool = true) -> some View {
        self.overlay(
            Group {
                if show {
                    OnlineStatusIndicator(isOnline: isOnline)
                        .offset(x: 2, y: 2)
                }
            },
            alignment: .bottomTrailing
        )
    }
}

// MARK: - Preview

#Preview("Online Status") {
    VStack(spacing: 30) {
        HStack(spacing: 40) {
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: true)
                Text("Online")
                    .font(.caption)
            }
            
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: false)
                Text("Offline")
                    .font(.caption)
            }
        }
        
        Divider()
        
        Text("Various Sizes")
            .font(.headline)
        
        HStack(spacing: 30) {
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: true, size: 6)
                Text("6pt")
                    .font(.caption2)
            }
            
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: true, size: 8)
                Text("8pt")
                    .font(.caption2)
            }
            
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: true, size: 10)
                Text("10pt")
                    .font(.caption2)
            }
            
            VStack(spacing: 8) {
                OnlineStatusIndicator(isOnline: true, size: 12)
                Text("12pt")
                    .font(.caption2)
            }
        }
    }
    .padding()
}

#Preview("With Profile Images") {
    VStack(spacing: 30) {
        Text("Profile Images with Status Indicators")
            .font(.headline)
        
        HStack(spacing: 40) {
            VStack(spacing: 8) {
                ProfileImageView(
                    displayName: "John Doe",
                    size: 80
                )
                .onlineStatusIndicator(isOnline: true)
                
                Text("Online")
                    .font(.caption)
            }
            
            VStack(spacing: 8) {
                ProfileImageView(
                    displayName: "Jane Smith",
                    size: 80
                )
                .onlineStatusIndicator(isOnline: false)
                
                Text("Offline")
                    .font(.caption)
            }
        }
        
        Divider()
        
        Text("Different Sizes")
            .font(.headline)
        
        HStack(spacing: 30) {
            ProfileImageView(displayName: "A", size: 50)
                .onlineStatusIndicator(isOnline: true)
            
            ProfileImageView(displayName: "B", size: 60)
                .onlineStatusIndicator(isOnline: true)
            
            ProfileImageView(displayName: "C", size: 70)
                .onlineStatusIndicator(isOnline: false)
        }
        
        Divider()
        
        Text("Group Conversation (No Status)")
            .font(.headline)
        
        HStack(spacing: 30) {
            ProfileImageView(
                displayName: "Team Alpha",
                size: 60,
                isGroup: true
            )
            .onlineStatusIndicator(isOnline: true, show: false)
            
            ProfileImageView(
                displayName: "Project Beta",
                size: 60,
                isGroup: true
            )
            .onlineStatusIndicator(isOnline: true, show: false)
        }
    }
    .padding()
}

#Preview("Conversation Row Example") {
    List {
        HStack(spacing: 12) {
            ProfileImageView(
                imageUrl: nil,
                displayName: "Alice Johnson",
                size: 50
            )
            .onlineStatusIndicator(isOnline: true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Alice Johnson")
                    .font(.headline)
                Text("Hey, how are you doing?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("2:34 PM")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        
        HStack(spacing: 12) {
            ProfileImageView(
                imageUrl: nil,
                displayName: "Bob Martinez",
                size: 50
            )
            .onlineStatusIndicator(isOnline: false)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Bob Martinez")
                    .font(.headline)
                Text("See you tomorrow!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Yesterday")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        
        HStack(spacing: 12) {
            ProfileImageView(
                displayName: "Engineering Team",
                size: 50,
                isGroup: true
            )
            .onlineStatusIndicator(isOnline: true, show: false)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Engineering Team")
                    .font(.headline)
                Text("Sprint planning meeting at 3pm")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("10:15 AM")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("3")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.vertical, 4)
    }
    .listStyle(.plain)
}

