import SwiftUI
import SwiftData

/// A GitHub-style contribution heatmap showing productivity over time
struct CalendarHeatmapView: View {
    let dailyData: [Date: Int]  // date -> tasks completed

    private let columns = 18  // ~18 weeks visible
    private let rows = 7      // days of week
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)

                Text("Activity")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("\(totalTasks) tasks")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Day labels + grid
            HStack(alignment: .top, spacing: 2) {
                // Day of week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { day in
                        if day == 1 || day == 3 || day == 5 {
                            Text(dayLabel(day))
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 16, height: cellSize)
                        } else {
                            Color.clear.frame(width: 16, height: cellSize)
                        }
                    }
                }

                // Heatmap grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<columns, id: \.self) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<rows, id: \.self) { day in
                                    let date = dateFor(week: week, day: day)
                                    cellView(date: date)
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 10, height: 10)
                }

                Text("More")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func cellView(date: Date?) -> some View {
        let count = date.flatMap { dailyData[Calendar.current.startOfDay(for: $0)] } ?? 0
        let isFuture = date.map { $0 > Date() } ?? true

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isFuture ? Color.gray.opacity(0.05) : colorForCount(count))
            .frame(width: cellSize, height: cellSize)
            .help(date.map { "\(dateString($0)): \(count) tasks" } ?? "")
    }

    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2...3: return Color.green.opacity(0.5)
        case 4...5: return Color.green.opacity(0.7)
        default: return Color.green.opacity(0.9)
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        default: return Color.green.opacity(0.9)
        }
    }

    private func dateFor(week: Int, day: Int) -> Date? {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today) - 1  // 0=Sun
        let todayOffset = (columns - 1) * 7 + weekday
        let targetOffset = week * 7 + day
        let daysAgo = todayOffset - targetOffset

        guard daysAgo >= 0 else { return nil }
        return cal.date(byAdding: .day, value: -daysAgo, to: today)
    }

    private func dayLabel(_ index: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][index]
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private var totalTasks: Int {
        dailyData.values.reduce(0, +)
    }
}
