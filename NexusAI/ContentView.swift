//
//  ContentView.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/20/25.
//

import SwiftUI

/// Main authenticated content - shows ConversationListView
struct ContentView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        ConversationListView()
            .environmentObject(authViewModel)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
