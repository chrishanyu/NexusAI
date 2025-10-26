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
    let avatarColorHex: String?
    let size: CGFloat
    let isGroup: Bool
    
    // MARK: - State
    
    @State private var cachedImage: UIImage?
    @State private var isLoadingCache: Bool = true
    
    // MARK: - Initialization
    
    /// Creates a profile image view
    /// - Parameters:
    ///   - imageUrl: Optional URL string for the profile image
    ///   - displayName: User's display name (used for initials fallback)
    ///   - avatarColorHex: Optional stored avatar color (hex string). If nil, generates from displayName
    ///   - size: Diameter of the circular image in points
    ///   - isGroup: Whether this is a group conversation (shows group icon instead of initials)
    init(
        imageUrl: String? = nil,
        displayName: String,
        avatarColorHex: String? = nil,
        size: CGFloat = 50,
        isGroup: Bool = false
    ) {
        self.imageUrl = imageUrl
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.size = size
        self.isGroup = isGroup
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                // Display cached image
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                // Display image from URL (with caching on success)
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading state
                        loadingPlaceholder
                    case .success(let image):
                        // Successfully loaded image - cache it
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                Task {
                                    await cacheDownloadedImage(url: imageUrl, image: image)
                                }
                            }
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
        .task {
            // Check cache on appear
            if let imageUrl = imageUrl {
                await loadFromCache(url: imageUrl)
            }
        }
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
        .accessibilityLabel(isGroup ? "Group: \(displayName)" : "\(displayName), initials \(initials)")
    }
    
    // MARK: - Computed Properties
    
    /// Extracts initials from display name
    /// Algorithm:
    /// - Two+ words: First letter of first word + First letter of second word ("John Doe" → "JD")
    /// - Single word: First letter only ("Alice" → "A", "J" → "J")
    /// - Empty: Return "U" (Unknown)
    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty name
        guard !trimmed.isEmpty else { return "U" }
        
        // Split into words (filter out empty strings from multiple spaces)
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        if words.count >= 2 {
            // Two or more words: First letter of first word + First letter of second word
            let firstLetter = words[0].first.map { String($0) } ?? ""
            let secondLetter = words[1].first.map { String($0) } ?? ""
            return (firstLetter + secondLetter).uppercased()
        } else if let singleWord = words.first, let firstChar = singleWord.first {
            // Single word: First letter only
            return String(firstChar).uppercased()
        }
        
        // Fallback (shouldn't reach here, but just in case)
        return "U"
    }
    
    /// Background color for the fallback view (uses stored color or generates consistent color)
    private var fallbackBackgroundColor: Color {
        if isGroup {
            return Color.blue
        }
        
        // Use stored avatar color if available
        if let colorHex = avatarColorHex, !colorHex.isEmpty {
            return Color(hexString: colorHex)
        }
        
        // Otherwise generate consistent color based on display name
        return Color.avatarColor(for: displayName)
    }
    
    // MARK: - Cache Methods
    
    /// Load image from cache if available
    /// - Parameter url: Image URL
    private func loadFromCache(url: String) async {
        isLoadingCache = true
        
        // Check cache
        if let data = await ImageCacheService.shared.getCachedImage(for: url),
           let image = UIImage(data: data) {
            cachedImage = image
        }
        
        isLoadingCache = false
    }
    
    /// Cache a downloaded image
    /// - Parameters:
    ///   - url: Image URL
    ///   - image: SwiftUI Image to cache
    private func cacheDownloadedImage(url: String, image: Image) async {
        // We need to convert SwiftUI Image to Data
        // Since AsyncImage provides SwiftUI Image, we'll need to re-download for caching
        // This is a limitation of AsyncImage - it doesn't provide raw data
        
        guard let urlObj = URL(string: url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            try await ImageCacheService.shared.cacheImage(data, for: url)
            
            // Update cached image
            if let uiImage = UIImage(data: data) {
                cachedImage = uiImage
            }
        } catch {
            print("⚠️ ProfileImageView: Failed to cache image - \(error.localizedDescription)")
        }
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

