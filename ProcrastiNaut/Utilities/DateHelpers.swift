import Foundation

extension Date {
    /// Returns the start of this day (midnight)
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of this day (23:59:59)
    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }

    /// Returns this date's time as seconds from midnight
    var secondsFromMidnight: TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: self)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    /// Creates a date on the same day as `self` at the given seconds from midnight
    func atTimeOfDay(_ secondsFromMidnight: TimeInterval) -> Date {
        let hours = Int(secondsFromMidnight) / 3600
        let minutes = (Int(secondsFromMidnight) % 3600) / 60
        return Calendar.current.date(bySettingHour: hours, minute: minutes, second: 0, of: self) ?? self
    }

    /// Whether this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Whether this date is in the past
    var isPast: Bool {
        self < Date()
    }

    /// Weekday as 0=Sun, 1=Mon, ..., 6=Sat
    var weekdayIndex: Int {
        Calendar.current.component(.weekday, from: self) - 1
    }
}

/// Formats seconds from midnight into a readable time string
func formatTimeOfDay(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    let date = Calendar.current.date(bySettingHour: hours, minute: minutes, second: 0, of: Date()) ?? Date()
    return formatter.string(from: date)
}

/// Formats a duration in seconds into a human-readable string
func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    if minutes < 60 {
        return "\(minutes)m"
    }
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if remainingMinutes == 0 {
        return "\(hours)h"
    }
    return "\(hours)h \(remainingMinutes)m"
}

/// Formats a time range
func formatTimeRange(start: Date, end: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
}
