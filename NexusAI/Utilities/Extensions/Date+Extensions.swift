import Foundation

extension Date {

    /// Returns a smart formatted timestamp for messages
    /// Examples: "Just now", "5m", "2h", "Yesterday", "Mon", "12/24"
    func smartTimestamp() -> String {
        let calendar = Calendar.current
        let now = Date()
        let timeInterval = -self.timeIntervalSince(now)

        // Less than 1 minute ago
        if timeInterval < 60 {
            return "Just now"
        }

        // Less than 1 hour ago (show minutes)
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        }

        // Less than 24 hours ago (show hours)
        if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        }

        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        // Within the last 7 days (show abbreviated weekday)
        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE" // Abbreviated day name: "Mon", "Tue", etc.
            return formatter.string(from: self)
        }

        // Older messages (show MM/DD format)
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d" // "12/24"
        return formatter.string(from: self)
    }

    /// Returns a full timestamp for message details
    /// Example: "Dec 24, 2023 at 3:45 PM"
    func fullTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Returns relative time for last seen
    /// Examples: "2 minutes ago", "5 hours ago", "Yesterday"
    func relativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
