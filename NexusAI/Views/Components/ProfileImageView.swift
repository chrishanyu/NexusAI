//
//  ProfileImageView.swift
//  NexusAI
//
//  Created on October 21, 2025.
//

import SwiftUI

/// A reusable component that displays user profile images with fallback to initials
struct ProfileImageView: View {
    // MARK: - Properties
    
    let imageUrl: String?
    let displayName: String
    let size: CGFloat
    let isGroup: Bool
    
    // MARK: - Initialization
    
    /// Creates a profile image view
    /// - Parameters:
    ///   - imageUrl: Optional URL string for the profile image
    ///   - displayName: User's display name (used for initials fallback)
    ///   - size: Diameter of the circular image in points
    ///   - isGroup: Whether this is a group conversation (shows group icon instead of initials)
    init(
        imageUrl: String? = nil,
        displayName: String,
        size: CGFloat = 50,
        isGroup: Bool = false
    ) {
        self.imageUrl = imageUrl
        self.displayName = displayName
        self.size = size
        self.isGroup = isGroup
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                // Display image from URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading state
                        loadingPlaceholder
                    case .success(let image):
                        // Successfully loaded image
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        // Failed to load, show fallback
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                // No URL provided, show fallback
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    // MARK: - Subviews
    
    /// Loading placeholder shown while image is downloading
    private var loadingPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
            ProgressView()
                .scaleEffect(0.8)
        }
    }
    
    /// Fallback view shown when no image URL or loading fails
    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(fallbackBackgroundColor)
            
            if isGroup {
                // Group icon
                Image(systemName: "person.3.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .padding(size * 0.25)
            } else {
                // Initials
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Extracts the first letter of the display name for initials
    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        
        // Get first letter of first word
        let words = trimmed.components(separatedBy: " ")
        if let firstWord = words.first, let firstChar = firstWord.first {
            return String(firstChar).uppercased()
        }
        
        return String(trimmed.prefix(1)).uppercased()
    }
    
    /// Background color for the fallback view (consistent color based on name)
    private var fallbackBackgroundColor: Color {
        if isGroup {
            return Color.blue
        }
        
        // Generate consistent color based on display name
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .indigo, .teal
        ]
        
        let hash = abs(displayName.hashValue)
        let index = hash % colors.count
        return colors[index]
    }
}

// MARK: - Preview

#Preview("Single User with Image") {
    VStack(spacing: 20) {
        ProfileImageView(
            imageUrl: "https://i.pravatar.cc/300?img=1",
            displayName: "John Doe",
            size: 100
        )
        
        ProfileImageView(
            imageUrl: "https://i.pravatar.cc/300?img=2",
            displayName: "Jane Smith",
            size: 80
        )
        
        ProfileImageView(
            imageUrl: "https://i.pravatar.cc/300?img=3",
            displayName: "Alex Johnson",
            size: 60
        )
    }
    .padding()
}

#Preview("Initials Fallback") {
    VStack(spacing: 20) {
        ProfileImageView(
            displayName: "John Doe",
            size: 100
        )
        
        ProfileImageView(
            displayName: "Jane Smith",
            size: 80
        )
        
        ProfileImageView(
            displayName: "Alex Johnson",
            size: 60
        )
        
        ProfileImageView(
            displayName: "Maria Garcia",
            size: 50
        )
        
        ProfileImageView(
            displayName: "Chen Wei",
            size: 44
        )
    }
    .padding()
}

#Preview("Group Conversations") {
    VStack(spacing: 20) {
        ProfileImageView(
            displayName: "Team Alpha",
            size: 100,
            isGroup: true
        )
        
        ProfileImageView(
            displayName: "Project Beta",
            size: 80,
            isGroup: true
        )
        
        ProfileImageView(
            displayName: "Engineering",
            size: 60,
            isGroup: true
        )
    }
    .padding()
}

#Preview("Various Sizes") {
    HStack(spacing: 15) {
        ProfileImageView(displayName: "A", size: 30)
        ProfileImageView(displayName: "B", size: 40)
        ProfileImageView(displayName: "C", size: 50)
        ProfileImageView(displayName: "D", size: 60)
        ProfileImageView(displayName: "E", size: 70)
        ProfileImageView(displayName: "F", size: 80)
    }
    .padding()
}

#Preview("Failed Image Load") {
    VStack(spacing: 20) {
        ProfileImageView(
            imageUrl: "https://invalid-url-that-will-fail.com/image.jpg",
            displayName: "Failed User",
            size: 100
        )
        
        Text("Should show initials fallback when image fails to load")
            .font(.caption)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding()
    }
    .padding()
}

