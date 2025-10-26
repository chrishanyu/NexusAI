import Foundation

extension Date {

    /// Returns a smart formatted timestamp for messages
    /// Examples: "3:45 PM" (today), "Yesterday 3:45 PM", "Mon 3:45 PM", "Dec 24 3:45 PM"
    func smartTimestamp() -> String {
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let time = timeFormatter.string(from: self)
        
        // Today - show time only
        if calendar.isDateInToday(self) {
            return time // "3:45 PM"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday \(time)"
        }
        
        // Within the last 7 days (show abbreviated day name)
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: self), 
                                                 to: calendar.startOfDay(for: now))
        if let days = components.day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE" // Abbreviated day name: "Mon", "Tue", etc.
            return "\(formatter.string(from: self)) \(time)"
        }
        
        // This year - show month and day
        if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // "Dec 24"
            return "\(formatter.string(from: self)) \(time)"
        }
        
        // Older than this year - show month, day, and year
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy" // "Dec 24, 2023"
        return "\(formatter.string(from: self)) \(time)"
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
