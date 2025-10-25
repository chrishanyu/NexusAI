//
//  MessageInputView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// Input bar for composing and sending messages
struct MessageInputView: View {
    // MARK: - Properties
    
    @Binding var messageText: String
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Text input field
            textInputField
            
            // Send button
            sendButton
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
    
    // MARK: - Subviews
    
    /// Text input field with expanding behavior
    private var textInputField: some View {
        TextField("Message...", text: $messageText, axis: .vertical)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .lineLimit(1...4)
    }
    
    /// Send button
    private var sendButton: some View {
        Button(action: handleSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(sendButtonColor)
        }
        .disabled(!canSend)
        .opacity(canSend ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: canSend)
    }
    
    // MARK: - Computed Properties
    
    /// Whether message can be sent
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Send button color based on state
    private var sendButtonColor: Color {
        canSend ? Constants.Colors.primaryBlue : Color.gray
    }
    
    // MARK: - Methods
    
    /// Handle send button tap
    private func handleSend() {
        guard canSend else { return }
        
        onSend()
        
        // Clear text field after sending
        messageText = ""
        
        // Keep keyboard open
        isFocused = true
    }
}

// MARK: - Preview

#Preview("Empty State") {
    VStack {
        Spacer()
        
        MessageInputView(
            messageText: .constant(""),
            onSend: {
                print("Send tapped")
            }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("With Text") {
    VStack {
        Spacer()
        
        MessageInputView(
            messageText: .constant("Hello, this is a test message!"),
            onSend: {
                print("Send tapped")
            }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Multi-line Text") {
    VStack {
        Spacer()
        
        MessageInputView(
            messageText: .constant("This is a longer message that spans multiple lines to test the expanding behavior of the text input field."),
            onSend: {
                print("Send tapped")
            }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var message = ""
        @State private var sentMessages: [String] = []
        
        var body: some View {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sentMessages, id: \.self) { msg in
                            HStack {
                                Spacer()
                                Text(msg)
                                    .padding(12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                MessageInputView(
                    messageText: $message,
                    onSend: {
                        sentMessages.append(message)
                    }
                )
            }
            .background(Color.gray.opacity(0.1))
        }
    }
    
    return InteractivePreview()
}

#Preview("In Chat Context") {
    VStack(spacing: 0) {
        // Mock chat header
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            
            VStack(alignment: .leading) {
                Text("Alice")
                    .font(.headline)
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        
        Divider()
        
        // Mock messages
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Hey, how's it going?")
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    Text("Pretty good! How about you?")
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        
        // Message input
        MessageInputView(
            messageText: .constant(""),
            onSend: {
                print("Send tapped")
            }
        )
    }
}

