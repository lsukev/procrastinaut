import SwiftUI

struct TodayAgendaSummaryCard: View {
    @Bindable var viewModel: PlannerViewModel

    private var todayEvents: [CalendarEventItem] {
        viewModel.events(for: Date())
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    private var nextUpEvent: CalendarEventItem? {
        let now = Date()
        return todayEvents.first { $0.startDate > now }
    }

    private var currentEvent: CalendarEventItem? {
        let now = Date()
        return todayEvents.first { $0.startDate <= now && $0.endDate > now }
    }

    private var totalScheduledHours: Double {
        let seconds = todayEvents.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return seconds / 3600.0
    }

    private var freeHours: Double {
        let workingHours = 8.0
        return max(0, workingHours - totalScheduledHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(todayLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(dateString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.goToToday()
                } label: {
                    Text("Go to Today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .opacity(Calendar.current.isDateInToday(viewModel.selectedDate) ? 0 : 1)
            }

            // Current / Next up event
            if let current = currentEvent {
                eventRow(event: current, label: "Now", color: .green)
            } else if let next = nextUpEvent {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    eventRow(event: next, label: countdownText(to: next.startDate), color: .blue)
                }
            } else if todayEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("No events today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("All done for today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Stats pills
            HStack(spacing: 6) {
                statPill(
                    icon: "calendar",
                    value: "\(todayEvents.count)",
                    label: "events",
                    color: .blue
                )

                statPill(
                    icon: "clock",
                    value: String(format: "%.1f", freeHours),
                    label: "free hrs",
                    color: .green
                )

                if viewModel.overdueCount > 0 {
                    statPill(
                        icon: "exclamationmark.triangle.fill",
                        value: "\(viewModel.overdueCount)",
                        label: "overdue",
                        color: .red
                    )
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }

    // MARK: - Subviews

    private func eventRow(event: CalendarEventItem, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text(timeRange(event))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12), in: Capsule())
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 10, weight: .semibold))

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    // MARK: - Helpers

    private var todayLabel: String {
        Calendar.current.isDateInToday(Date()) ? "Today" : "Schedule"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private func timeRange(_ event: CalendarEventItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private func countdownText(to date: Date) -> String {
        let minutes = Int(date.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Now" }
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "in \(hours)h" }
        return "in \(hours)h \(remainingMinutes)m"
    }
}
