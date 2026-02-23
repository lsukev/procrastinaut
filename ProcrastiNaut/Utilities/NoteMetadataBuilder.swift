import Foundation

/// Composes and parses structured metadata stored in reminder notes fields.
/// Metadata conventions:
/// - Duration: `[duration:30m]` or `[duration:1h30m]`
/// - Location: `[location:Coffee Shop on 5th Ave]`
/// - Source event: `[fromEvent:eventID]`
/// - Tags: `#errand #home #urgent` (on their own line at the end)
enum NoteMetadataBuilder {

    // MARK: - Compose

    /// Build a composite notes string from structured components.
    static func buildNotes(
        durationMinutes: Int,
        location: String?,
        userNotes: String?,
        tags: [String],
        fromEventID: String? = nil
    ) -> String {
        var parts: [String] = []

        // Duration tag
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 {
            parts.append("[duration:\(h)h\(m)m]")
        } else if h > 0 {
            parts.append("[duration:\(h)h]")
        } else {
            parts.append("[duration:\(m)m]")
        }

        // Location tag
        if let location, !location.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("[location:\(location.trimmingCharacters(in: .whitespaces))]")
        }

        // Source event tag
        if let fromEventID, !fromEventID.isEmpty {
            parts.append("[fromEvent:\(fromEventID)]")
        }

        // User notes
        if let userNotes, !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(userNotes.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Tags (last line)
        let cleanTags = tags
            .map { $0.hasPrefix("#") ? $0 : "#\($0)" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 1 }
        if !cleanTags.isEmpty {
            parts.append(cleanTags.joined(separator: " "))
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Parse

    /// Extract `#tag` tokens from notes.
    static func parseTags(from notes: String?) -> [String] {
        guard let notes else { return [] }
        var tags: [String] = []
        let scanner = notes as NSString
        let regex = try? NSRegularExpression(pattern: #"#(\w+)"#)
        let range = NSRange(location: 0, length: scanner.length)
        regex?.enumerateMatches(in: notes, range: range) { match, _, _ in
            guard let match, let tagRange = Range(match.range(at: 1), in: notes) else { return }
            tags.append(String(notes[tagRange]))
        }
        return tags
    }

    /// Extract `[location:...]` value from notes.
    static func parseLocation(from notes: String?) -> String? {
        guard let notes else { return nil }
        guard let range = notes.range(of: #"\[location:(.+?)\]"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(notes[range])
        let value = matched
            .replacingOccurrences(of: "[location:", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Extract `[fromEvent:...]` value from notes.
    static func parseEventID(from notes: String?) -> String? {
        guard let notes else { return nil }
        guard let range = notes.range(of: #"\[fromEvent:(.+?)\]"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(notes[range])
        let value = matched
            .replacingOccurrences(of: "[fromEvent:", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Return user-visible notes with all metadata tokens stripped.
    static func cleanNotes(from notes: String?) -> String? {
        guard var text = notes else { return nil }

        // Remove [duration:...] tags
        text = text.replacingOccurrences(
            of: #"\[duration:\d+[hm]+(?:\d+[m])?\]"#,
            with: "", options: .regularExpression
        )
        // Remove [location:...] tags
        text = text.replacingOccurrences(
            of: #"\[location:.+?\]"#,
            with: "", options: .regularExpression
        )
        // Remove [fromEvent:...] tags
        text = text.replacingOccurrences(
            of: #"\[fromEvent:.+?\]"#,
            with: "", options: .regularExpression
        )
        // Remove #tag tokens
        text = text.replacingOccurrences(
            of: #"#\w+"#,
            with: "", options: .regularExpression
        )

        let cleaned = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return cleaned.isEmpty ? nil : cleaned
    }
}
