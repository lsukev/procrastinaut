import Foundation

/// Parses natural language task input into structured metadata.
///
/// Supports patterns like:
/// - "Call dentist tomorrow at 2pm for 30 min !high"
/// - "Write report next monday morning 1h #Work"
/// - "Review PR today afternoon 45m !low @low"
/// - "Submit expenses by friday 20m !high @high https://expenses.com"
struct NaturalLanguageParser {

    struct ParsedTask: Sendable {
        var title: String
        var duration: Int                   // minutes
        var targetDate: Date?
        var specificTime: DateComponents?    // hour/minute if "at 2pm" etc.
        var timeOfDay: TimeOfDay?
        var priority: TaskPriority?
        var energy: EnergyLevel?
        var listName: String?
        var url: URL?
        var notes: String?

        /// Build duration tag for reminder notes
        var durationTag: String {
            let h = duration / 60
            let m = duration % 60
            if h > 0 && m > 0 { return "[duration:\(h)h\(m)m]" }
            if h > 0 { return "[duration:\(h)h]" }
            return "[duration:\(m)m]"
        }
    }

    enum TimeOfDay: String, Sendable {
        case morning, afternoon, evening
    }

    @MainActor
    static func parse(_ input: String) -> ParsedTask {
        var text = input.trimmingCharacters(in: .whitespaces)
        var duration: Int?
        var targetDate: Date?
        var specificTime: DateComponents?
        var timeOfDay: TimeOfDay?
        var priority: TaskPriority?
        var energy: EnergyLevel?
        var listName: String?
        var url: URL?

        // ── 1. Extract URL ──────────────────────────────────────────
        if let match = text.range(of: #"https?://\S+"#, options: .regularExpression) {
            let urlStr = String(text[match])
            url = URL(string: urlStr)
            text = text.replacingCharacters(in: match, with: "")
        }

        // ── 2. Extract priority flags ───────────────────────────────
        // !high, !med, !low, !none, !!!,  !!, !
        let priorityPatterns: [(String, TaskPriority)] = [
            (#"!{3}"#, .high),
            (#"!{2}"#, .medium),
            (#"!{1}(?![a-zA-Z!])"#, .low),
            (#"!high"#, .high),
            (#"!hi"#, .high),
            (#"!med(?:ium)?"#, .medium),
            (#"!low"#, .low),
            (#"!none"#, .none),
        ]
        for (pattern, p) in priorityPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                priority = p
                text = text.replacingCharacters(in: match, with: "")
                break
            }
        }

        // ── 3. Extract energy level ─────────────────────────────────
        // @high, @med, @low, @focus
        let energyPatterns: [(String, EnergyLevel)] = [
            (#"@(?:high|focus)"#, .highFocus),
            (#"@med(?:ium)?"#, .medium),
            (#"@low"#, .low),
        ]
        for (pattern, e) in energyPatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                energy = e
                text = text.replacingCharacters(in: match, with: "")
                break
            }
        }

        // ── 4. Extract list name (#ListName) ────────────────────────
        if let match = text.range(of: #"#(\w[\w\s]*?)(?=\s+[!@#]|\s+\d|\s+(?:for|at|tomorrow|today|next|morning|afternoon|evening)|$)"#, options: .regularExpression) {
            let raw = String(text[match]).dropFirst() // drop #
            listName = raw.trimmingCharacters(in: .whitespaces)
            text = text.replacingCharacters(in: match, with: "")
        }

        // ── 5. Extract duration ─────────────────────────────────────
        // "for 1h30m", "for 2 hours", "for 30 min", "1h", "45m", "1.5h"
        // Compound: "1h30m", "1h 30m"
        if let match = text.range(of: #"(?:for\s+)?(\d+)\s*h(?:ours?)?\s*(\d+)\s*m(?:in(?:utes?)?)?"#, options: [.regularExpression, .caseInsensitive]) {
            let matchStr = String(text[match])
            let nums = matchStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if nums.count >= 2, let h = Int(nums[0]), let m = Int(nums[1]) {
                duration = h * 60 + m
                text = text.replacingCharacters(in: match, with: "")
            }
        }

        if duration == nil {
            let durationPatterns: [(String, (String) -> Int?)] = [
                (#"(?:for\s+)?(\d+\.?\d*)\s*h(?:ours?)?"#, { m in Double(m).map { Int($0 * 60) } }),
                (#"(?:for\s+)?(\d+)\s*m(?:in(?:utes?)?)?"#, { m in Int(m) }),
            ]
            for (pattern, extractor) in durationPatterns {
                if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let matchStr = String(text[match])
                    let nums = matchStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                    if let first = nums.first, let extracted = extractor(first) {
                        duration = extracted
                        text = text.replacingCharacters(in: match, with: "")
                        break
                    }
                }
            }
        }

        // ── 6. Extract specific time ("at 2pm", "at 14:30", "at 2:30 pm") ──
        let timePatterns: [(String, (String) -> DateComponents?)] = [
            (#"(?:at|@)\s*(\d{1,2}):(\d{2})\s*(am|pm)?"#, { matchStr in
                parseTimeMatch(matchStr)
            }),
            (#"(?:at|@)\s*(\d{1,2})\s*(am|pm)"#, { matchStr in
                parseTimeMatch(matchStr)
            }),
        ]
        for (pattern, extractor) in timePatterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchStr = String(text[match])
                if let components = extractor(matchStr) {
                    specificTime = components
                    text = text.replacingCharacters(in: match, with: "")
                    break
                }
            }
        }

        // ── 7. Extract date references ──────────────────────────────
        let lowerText = text.lowercased()
        let cal = Calendar.current

        // Day of week: "next monday", "this friday", "on wednesday"
        let dayNames: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7),
            ("sun", 1), ("mon", 2), ("tue", 3), ("wed", 4),
            ("thu", 5), ("fri", 6), ("sat", 7),
        ]

        var foundDateKeyword = false

        // "next <day>"
        for (name, weekday) in dayNames {
            if let match = text.range(of: #"next\s+\#(name)"#, options: [.regularExpression, .caseInsensitive]) {
                targetDate = nextWeekday(weekday, afterNext: true)
                text = text.replacingCharacters(in: match, with: "")
                foundDateKeyword = true
                break
            }
        }

        if !foundDateKeyword {
            // "this <day>" or "on <day>" or bare "<day>"
            for (name, weekday) in dayNames {
                let patterns = [
                    #"(?:this|on)\s+\#(name)"#,
                    #"\b\#(name)\b"#,
                ]
                for pattern in patterns {
                    if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                        targetDate = nextWeekday(weekday, afterNext: false)
                        text = text.replacingCharacters(in: match, with: "")
                        foundDateKeyword = true
                        break
                    }
                }
                if foundDateKeyword { break }
            }
        }

        if !foundDateKeyword {
            if lowerText.contains("tomorrow") {
                targetDate = cal.date(byAdding: .day, value: 1, to: Date())
                text = text.replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
            } else if lowerText.contains("today") {
                targetDate = Date()
                text = text.replacingOccurrences(of: "today", with: "", options: .caseInsensitive)
            } else if let match = text.range(of: #"next\s+week"#, options: [.regularExpression, .caseInsensitive]) {
                targetDate = cal.date(byAdding: .weekOfYear, value: 1, to: Date())
                text = text.replacingCharacters(in: match, with: "")
            } else if let match = text.range(of: #"in\s+(\d+)\s+days?"#, options: [.regularExpression, .caseInsensitive]) {
                let matchStr = String(text[match])
                let nums = matchStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let first = nums.first, let days = Int(first) {
                    targetDate = cal.date(byAdding: .day, value: days, to: Date())
                }
                text = text.replacingCharacters(in: match, with: "")
            }
        }

        // ── 8. Extract time of day ──────────────────────────────────
        if specificTime == nil {
            if let match = text.range(of: #"\bmorning\b"#, options: [.regularExpression, .caseInsensitive]) {
                timeOfDay = .morning
                text = text.replacingCharacters(in: match, with: "")
            } else if let match = text.range(of: #"\bafternoon\b"#, options: [.regularExpression, .caseInsensitive]) {
                timeOfDay = .afternoon
                text = text.replacingCharacters(in: match, with: "")
            } else if let match = text.range(of: #"\bevening\b"#, options: [.regularExpression, .caseInsensitive]) {
                timeOfDay = .evening
                text = text.replacingCharacters(in: match, with: "")
            }
        }

        // ── 9. Extract "by <date>" deadline ─────────────────────────
        if targetDate == nil {
            if let match = text.range(of: #"by\s+(tomorrow|today|next\s+week)"#, options: [.regularExpression, .caseInsensitive]) {
                let keyword = String(text[match]).replacingOccurrences(of: "by ", with: "").lowercased().trimmingCharacters(in: .whitespaces)
                switch keyword {
                case "tomorrow": targetDate = cal.date(byAdding: .day, value: 1, to: Date())
                case "today": targetDate = Date()
                case "next week": targetDate = cal.date(byAdding: .weekOfYear, value: 1, to: Date())
                default: break
                }
                text = text.replacingCharacters(in: match, with: "")
            }

            // "by <day>"
            if targetDate == nil {
                for (name, weekday) in dayNames {
                    if let match = text.range(of: #"by\s+\#(name)"#, options: [.regularExpression, .caseInsensitive]) {
                        targetDate = nextWeekday(weekday, afterNext: false)
                        text = text.replacingCharacters(in: match, with: "")
                        break
                    }
                }
            }
        }

        // ── 10. Clean up title ──────────────────────────────────────
        let title = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "- ,;"))

        return ParsedTask(
            title: title.isEmpty ? input : title,
            duration: duration ?? UserSettings.shared.defaultTaskDuration,
            targetDate: targetDate,
            specificTime: specificTime,
            timeOfDay: timeOfDay,
            priority: priority,
            energy: energy,
            listName: listName,
            url: url,
            notes: nil
        )
    }

    // MARK: - Helpers

    private static func parseTimeMatch(_ matchStr: String) -> DateComponents? {
        let cleaned = matchStr
            .replacingOccurrences(of: #"(?:at|@)\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let isPM = cleaned.lowercased().contains("pm")
        let isAM = cleaned.lowercased().contains("am")
        let numPart = cleaned.replacingOccurrences(of: #"[aApPmM\s]+"#, with: "", options: .regularExpression)

        var hour: Int
        var minute = 0

        if numPart.contains(":") {
            let parts = numPart.split(separator: ":")
            guard let h = Int(parts[0]) else { return nil }
            hour = h
            if parts.count > 1 { minute = Int(parts[1]) ?? 0 }
        } else {
            guard let h = Int(numPart) else { return nil }
            hour = h
        }

        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }

        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    private static func nextWeekday(_ weekday: Int, afterNext: Bool) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayWeekday = cal.component(.weekday, from: today)

        var daysAhead = weekday - todayWeekday
        if daysAhead <= 0 { daysAhead += 7 }
        if afterNext && daysAhead <= 7 { daysAhead += 7 }

        return cal.date(byAdding: .day, value: daysAhead, to: today) ?? today
    }
}
