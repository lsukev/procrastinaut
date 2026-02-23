import SwiftUI

struct DayAgendaSidebar: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var expandedEventID: String?

    private let cal = Calendar.current

    private var allDayEvents: [CalendarEventItem] {
        viewModel.events(for: viewModel.selectedDate)
            .filter { $0.isAllDay }
            .sorted { $0.title < $1.title }
    }

    private var timedEvents: [CalendarEventItem] {
        viewModel.events(for: viewModel.selectedDate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    private var dayReminders: [ReminderItem] {
        let dayStart = cal.startOfDay(for: viewModel.selectedDate)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return viewModel.reminders.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due >= dayStart && due < dayEnd
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var hasItems: Bool {
        !allDayEvents.isEmpty || !timedEvents.isEmpty || !dayReminders.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()

            if hasItems {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // All-day events
                        if !allDayEvents.isEmpty {
                            sectionHeader("All Day")
                            ForEach(allDayEvents, id: \.id) { event in
                                allDayRow(event)
                            }
                            Divider().padding(.vertical, 6)
                        }

                        // Timed events
                        if !timedEvents.isEmpty {
                            sectionHeader("Events")
                            ForEach(timedEvents, id: \.id) { event in
                                timedEventRow(event)
                            }
                        }

                        // Reminders
                        if !dayReminders.isEmpty {
                            if !timedEvents.isEmpty {
                                Divider().padding(.vertical, 6)
                            }
                            sectionHeader("Reminders")
                            ForEach(dayReminders, id: \.id) { reminder in
                                reminderRow(reminder)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            } else {
                // Empty state
                emptyState
            }

            Spacer(minLength: 0)

            // Footer
            Divider()
            footer
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayOfWeekString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(dateString)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.bottom, 4)
            .padding(.top, 2)
    }

    // MARK: - Event Rows

    private func allDayRow(_ event: CalendarEventItem) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEventID = expandedEventID == event.id ? nil : event.id
                }
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(cgColor: event.calendarColor))
                        .frame(width: 3, height: 20)

                    Text(event.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("all-day")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    chevron(expanded: expandedEventID == event.id)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedEventID == event.id {
                expandedDetail(event)
            }
        }
    }

    private func timedEventRow(_ event: CalendarEventItem) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEventID = expandedEventID == event.id ? nil : event.id
                }
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(cgColor: event.calendarColor))
                        .frame(width: 3, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text(timeRange(event))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let location = event.location, !location.isEmpty {
                        Image(systemName: "mappin")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    chevron(expanded: expandedEventID == event.id)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedEventID == event.id {
                expandedDetail(event)
            }
        }
    }

    // MARK: - Expanded Detail

    private func expandedDetail(_ event: CalendarEventItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Calendar info
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(cgColor: event.calendarColor))
                    .frame(width: 8, height: 8)
                Text(event.calendarName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Time / Duration
            if !event.isAllDay {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(detailTimeString(event))
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                }
            }

            // Location
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            // Edit button
            Button {
                viewModel.startEditing(event)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                    Text("Edit Event")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }

    // MARK: - Chevron

    private func chevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .animation(.easeInOut(duration: 0.2), value: expanded)
    }

    // MARK: - Reminder Row

    private func reminderRow(_ reminder: ReminderItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(reminder.listColor.map { Color(cgColor: $0) } ?? .gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if let due = reminder.dueDate {
                    Text(shortTime(due))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if reminder.priority == .high {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No Items")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Enjoy your day!")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            let eventCount = allDayEvents.count + timedEvents.count
            let reminderCount = dayReminders.count
            if eventCount + reminderCount > 0 {
                Text("\(eventCount) event\(eventCount == 1 ? "" : "s"), \(reminderCount) reminder\(reminderCount == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("Free Mode")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var dayOfWeekString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: viewModel.selectedDate)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: viewModel.selectedDate)
    }

    private func timeRange(_ event: CalendarEventItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: event.startDate)) \u{2013} \(f.string(from: event.endDate))"
    }

    private func detailTimeString(_ event: CalendarEventItem) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let range = "\(f.string(from: event.startDate)) \u{2013} \(f.string(from: event.endDate))"
        let minutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        if minutes < 60 {
            return "\(range) (\(minutes)m)"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(range) (\(hours)h)"
        }
        return "\(range) (\(hours)h \(remainingMinutes)m)"
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
