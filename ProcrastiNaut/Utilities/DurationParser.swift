import Foundation

/// Parses duration hints from reminder notes.
/// Supported formats: [duration:30m], [duration:1h], [duration:1h30m], [duration:90m]
enum DurationParser {
    /// Parses a duration hint from a string, returning seconds or nil
    static func parse(_ text: String?) -> TimeInterval? {
        guard let text else { return nil }

        // Match [duration:Xh], [duration:Xm], or [duration:XhYm]
        guard let range = text.range(of: #"\[duration:(\d+h)?(\d+m)?\]"#, options: .regularExpression) else {
            return nil
        }

        let matched = String(text[range])
        var totalSeconds: TimeInterval = 0

        // Extract hours
        if let hRange = matched.range(of: #"(\d+)h"#, options: .regularExpression) {
            let hStr = matched[hRange].dropLast() // Remove 'h'
            totalSeconds += (Double(hStr) ?? 0) * 3600
        }

        // Extract minutes
        if let mRange = matched.range(of: #"(\d+)m"#, options: .regularExpression) {
            let mStr = matched[mRange].dropLast() // Remove 'm'
            totalSeconds += (Double(mStr) ?? 0) * 60
        }

        return totalSeconds > 0 ? totalSeconds : nil
    }
}
