//
//  ContentView.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/20/25.
//

import SwiftUI

/// Temporary authenticated home screen (placeholder for ConversationListView)
struct ContentView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                // Welcome Message
                VStack(spacing: 8) {
                    Text("Welcome!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let user = authViewModel.currentUser {
                        Text("Signed in as \(user.displayName)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status
                Text("✅ Authentication Complete!")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text("This is a placeholder for ConversationListView")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Logout Button (for testing)
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationTitle("NexusAI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
