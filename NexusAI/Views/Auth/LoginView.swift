//
//  LoginView.swift
//  NexusAI
//
//  Created on 10/21/25.
//

import SwiftUI

/// Sign-in screen with Google Sign-In button
struct LoginView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo / Title Section
            VStack(spacing: 16) {
                // App Icon/Logo (placeholder for now)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // App Name
                Text("NexusAI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Tagline
                Text("AI-Powered Team Messaging")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign-In Button
            Button(action: {
                // Clear error message when retrying
                authViewModel.errorMessage = nil
                
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                Task {
                    await authViewModel.signIn()
                }
            }) {
                HStack(spacing: 12) {
                    // Show loading indicator or Google icon
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        // Google logo placeholder
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                    }
                    
                    Text(authViewModel.isLoading ? "Signing in..." : "Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(authViewModel.isLoading ? Color.gray.opacity(0.3) : Color.white)
                .foregroundColor(authViewModel.isLoading ? .gray : .black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(authViewModel.isLoading)
            .padding(.horizontal, 32)
            .accessibilityLabel(authViewModel.isLoading ? "Signing in, please wait" : "Sign in with Google")
            .accessibilityHint("Double tap to sign in with your Google account")
            
            // Error Message Display
            if let errorMessage = authViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
                .transition(.opacity)
                .accessibilityLabel("Error: \(errorMessage)")
                .accessibilityHint("This error will automatically dismiss in a few seconds, or tap the sign-in button to retry")
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

