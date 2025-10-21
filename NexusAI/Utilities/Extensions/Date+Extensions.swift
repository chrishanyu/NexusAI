import Foundation

extension Date {

    /// Returns a smart formatted timestamp for messages
    /// Examples: "2m", "Yesterday", "Dec 24", "12/24/23"
    func smartTimestamp() -> String {
        let calendar = Calendar.current
        let now = Date()

        // Less than 1 minute ago
        if self.timeIntervalSince(now) > -60 {
            return "Just now"
        }

        // Less than 1 hour ago
        if self.timeIntervalSince(now) > -3600 {
            let minutes = Int(-self.timeIntervalSince(now) / 60)
            return "\(minutes)m"
        }

        // Less than 24 hours ago (today)
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        }

        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        // Within the last week
        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        }

        // Within the current year
        if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // "Dec 24"
            return formatter.string(from: self)
        }

        // Older than current year
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy" // "12/24/23"
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
