//
//  TypingIndicatorView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// View that displays typing indicator when someone is typing
/// Full implementation will be done in PR #9 (Typing Indicators)
struct TypingIndicatorView: View {
    // MARK: - Properties
    
    let isTyping: Bool
    let typingUserName: String
    
    // MARK: - Initialization
    
    init(isTyping: Bool = false, typingUserName: String = "") {
        self.isTyping = isTyping
        self.typingUserName = typingUserName
    }
    
    // MARK: - Body
    
    var body: some View {
        if isTyping {
            HStack(spacing: 8) {
                // Animated dots (to be implemented in PR #9)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                }
                
                Text("\(typingUserName) is typing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, Constants.Dimensions.screenPadding)
            .padding(.vertical, 8)
            .transition(.opacity)
        }
    }
}

// MARK: - Preview

#Preview("Hidden State") {
    VStack {
        Spacer()
        
        TypingIndicatorView(isTyping: false, typingUserName: "Alice")
        
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 50)
        
        Text("Typing indicator is hidden")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

#Preview("Visible State") {
    VStack {
        Spacer()
        
        TypingIndicatorView(isTyping: true, typingUserName: "Alice")
        
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 50)
            .overlay(
                Text("Message input bar would be here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }
}

#Preview("In Chat Context") {
    VStack(spacing: 0) {
        // Mock messages
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Hey!")
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    Text("Hi there!")
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        
        Spacer()
        
        // Typing indicator
        TypingIndicatorView(isTyping: true, typingUserName: "Alice")
        
        // Message input bar placeholder
        HStack {
            Text("Message...")
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .padding()
    }
}

#Preview("Multiple Users") {
    VStack(spacing: 12) {
        TypingIndicatorView(isTyping: true, typingUserName: "Alice")
        TypingIndicatorView(isTyping: true, typingUserName: "Bob")
        TypingIndicatorView(isTyping: true, typingUserName: "Charlie")
        
        Divider()
        
        Text("Note: In actual implementation (PR #9),\nonly one typing indicator would show at a time")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }
}

