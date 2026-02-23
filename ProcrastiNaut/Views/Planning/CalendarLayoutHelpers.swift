import SwiftUI

/// Shared layout helpers for event overlap computation, used by Day and Week views.
enum CalendarLayoutHelpers {
    /// Layout info for a single event: which column it's in and how many columns in its group.
    struct EventLayout {
        let column: Int
        let totalColumns: Int
    }

    /// Compute column assignments for overlapping timed events.
    /// Returns a dictionary mapping event IDs to their layout position.
    static func computeEventLayouts(for events: [CalendarEventItem]) -> [String: EventLayout] {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        guard !sorted.isEmpty else { return [:] }

        // Build overlap groups: events that transitively overlap share a group
        var groups: [[CalendarEventItem]] = []
        var currentGroup: [CalendarEventItem] = []
        var groupEnd: Date = .distantPast

        for event in sorted {
            if event.startDate < groupEnd {
                currentGroup.append(event)
                groupEnd = max(groupEnd, event.endDate)
            } else {
                if !currentGroup.isEmpty { groups.append(currentGroup) }
                currentGroup = [event]
                groupEnd = event.endDate
            }
        }
        if !currentGroup.isEmpty { groups.append(currentGroup) }

        // Assign columns within each group
        var layouts: [String: EventLayout] = [:]
        for group in groups {
            var columnEnds: [Date] = []
            for event in group {
                var placed = false
                for col in 0..<columnEnds.count {
                    if event.startDate >= columnEnds[col] {
                        columnEnds[col] = event.endDate
                        layouts[event.id] = EventLayout(column: col, totalColumns: 0)
                        placed = true
                        break
                    }
                }
                if !placed {
                    layouts[event.id] = EventLayout(column: columnEnds.count, totalColumns: 0)
                    columnEnds.append(event.endDate)
                }
            }
            let total = columnEnds.count
            for event in group {
                if let layout = layouts[event.id] {
                    layouts[event.id] = EventLayout(column: layout.column, totalColumns: total)
                }
            }
        }
        return layouts
    }

    // MARK: - Coordinate Math

    /// Y position for a date within a 24-hour grid.
    static func yPosition(for date: Date, hourHeight: CGFloat, startHour: Int = 0) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let totalMinutes = CGFloat(hour * 60 + minute)
        let startMinutes = CGFloat(startHour * 60)
        return (totalMinutes - startMinutes) / 60 * hourHeight
    }

    /// Height for a duration between two dates.
    static func durationHeight(from start: Date, to end: Date, hourHeight: CGFloat) -> CGFloat {
        let durationMinutes = end.timeIntervalSince(start) / 60
        return CGFloat(durationMinutes) / 60 * hourHeight
    }

    /// Convert a y-position back to a time on a given day.
    static func timeFromYPosition(_ y: CGFloat, hourHeight: CGFloat, startHour: Int = 0, on date: Date) -> Date {
        let startMinutes = CGFloat(startHour * 60)
        let minutesFromStart = (y / hourHeight) * 60
        let totalMinutes = startMinutes + minutesFromStart

        let hours = max(0, min(Int(totalMinutes) / 60, 23))
        let minutes = max(0, min(Int(totalMinutes) % 60, 59))

        return Calendar.current.date(
            bySettingHour: hours,
            minute: minutes,
            second: 0,
            of: date
        ) ?? date
    }

    // MARK: - Formatting

    static func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "Noon" }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    static func formatTimeRange(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: start)) \u{2013} \(f.string(from: end))"
    }

    static func shortTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    /// Compact time range for week view: "9 – 10AM", "9:30 – 10:30AM", "11AM – 1PM"
    static func compactTimeRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let startHour = cal.component(.hour, from: start)
        let startMin = cal.component(.minute, from: start)
        let endHour = cal.component(.hour, from: end)
        let endMin = cal.component(.minute, from: end)

        let sameAMPM = (startHour < 12) == (endHour < 12)

        func compactTime(_ hour: Int, _ minute: Int, showAMPM: Bool) -> String {
            let h = hour % 12 == 0 ? 12 : hour % 12
            let ampm = hour < 12 ? "AM" : "PM"
            let timeStr = minute == 0 ? "\(h)" : "\(h):\(String(format: "%02d", minute))"
            return showAMPM ? "\(timeStr)\(ampm)" : timeStr
        }

        let startStr = compactTime(startHour, startMin, showAMPM: !sameAMPM)
        let endStr = compactTime(endHour, endMin, showAMPM: true)
        return "\(startStr) \u{2013} \(endStr)"
    }
}

// MARK: - Half-Hour Dashed Grid Line

/// A dashed line used at the 30-minute mark between hour rows.
struct HalfHourDashLine: View {
    var opacity: Double = 0.08

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(
                Color.primary.opacity(opacity),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
            )
        }
    }
}
