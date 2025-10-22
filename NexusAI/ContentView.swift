//
//  ContentView.swift
//  NexusAI
//
//  Created by Hanyu Zhu on 10/20/25.
//

import SwiftUI

/// Main authenticated content - shows ConversationListView with banner overlay
struct ContentView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var bannerManager: NotificationBannerManager
    
    var body: some View {
        ZStack {
            // Main content
            ConversationListView()
                .environmentObject(authViewModel)
                .environmentObject(notificationManager)
                .environmentObject(bannerManager)
            
            // Banner overlay at top
            VStack {
                if let banner = bannerManager.currentBanner {
                    NotificationBannerView(
                        banner: banner,
                        onTap: {
                            bannerManager.handleBannerTap()
                        },
                        onDismiss: {
                            bannerManager.dismissBanner()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bannerManager.currentBanner != nil)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
