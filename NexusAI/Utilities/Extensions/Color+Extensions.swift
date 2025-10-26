//
//  Color+Extensions.swift
//  NexusAI
//
//  Created on 10/26/25.
//

import SwiftUI

extension Color {
    
    // MARK: - Hex Conversion
    
    /// Initialize Color from hex string
    /// - Parameter hexString: Hex color string (with or without # prefix)
    init(hexString: String) {
        let cleanHex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    /// - Returns: Hex string representation (e.g., "#007AFF")
    func toHex() -> String? {
        guard let components = self.cgColor?.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
    
    // MARK: - Avatar Color Palette
    
    /// 8-color palette for avatar backgrounds
    static let avatarColors: [Color] = [
        Color(hexString: "#007AFF"), // Blue
        Color(hexString: "#34C759"), // Green
        Color(hexString: "#FF9500"), // Orange
        Color(hexString: "#AF52DE"), // Purple
        Color(hexString: "#FF2D55"), // Pink
        Color(hexString: "#FF3B30"), // Red
        Color(hexString: "#5856D6"), // Indigo
        Color(hexString: "#30B0C7")  // Teal
    ]
    
    // MARK: - Avatar Color Generation
    
    /// Generate consistent avatar color based on name
    /// - Parameter name: User's display name
    /// - Returns: Color from avatar palette
    static func avatarColor(for name: String) -> Color {
        let hash = abs(name.hashValue)
        let index = hash % avatarColors.count
        return avatarColors[index]
    }
    
    /// Generate consistent avatar color hex based on name
    /// - Parameter name: User's display name
    /// - Returns: Hex string of the avatar color
    static func avatarColorHex(for name: String) -> String {
        let color = avatarColor(for: name)
        return color.toHex() ?? "#007AFF" // Fallback to blue
    }
}

