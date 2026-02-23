import SwiftUI

struct YearCalendarView: View {
    @Bindable var viewModel: PlannerViewModel

    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                spacing: 20
            ) {
                ForEach(0..<12, id: \.self) { monthOffset in
                    if let monthDate = monthDateFor(offset: monthOffset) {
                        MiniMonthView(
                            date: monthDate,
                            events: viewModel.calendarEvents,
                            selectedDate: viewModel.selectedDate,
                            onTapMonth: {
                                viewModel.selectedDate = cal.startOfDay(for: monthDate)
                                viewModel.calendarViewMode = .month
                                Task { await viewModel.loadData() }
                            },
                            onTapDay: { day in
                                viewModel.selectedDate = cal.startOfDay(for: day)
                                viewModel.calendarViewMode = .day
                                Task { await viewModel.loadData() }
                            }
                        )
                    }
                }
            }
            .padding(20)
        }
    }

    private func monthDateFor(offset: Int) -> Date? {
        let year = cal.component(.year, from: viewModel.selectedDate)
        return cal.date(from: DateComponents(year: year, month: offset + 1, day: 1))
    }
}

// MARK: - Mini Month View

struct MiniMonthView: View {
    let date: Date
    let events: [CalendarEventItem]
    let selectedDate: Date
    let onTapMonth: () -> Void
    let onTapDay: (Date) -> Void

    private let cal = Calendar.current
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
    private let theme = AppTheme.shared

    var body: some View {
        VStack(spacing: 4) {
            // Month name button
            Button(action: onTapMonth) {
                Text(monthName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? theme.accentColor : .primary)
            }
            .buttonStyle(.plain)

            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = miniMonthDays
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 1
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        miniDayButton(day)
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 16)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isCurrentMonth ? theme.accentColor.opacity(0.3) : Color.primary.opacity(0.06),
                    lineWidth: isCurrentMonth ? 1.5 : 0.5
                )
        )
    }

    private func miniDayButton(_ day: Date) -> some View {
        let dayNum = cal.component(.day, from: day)
        let isToday = cal.isDateInToday(day)
        let hasEvents = events.contains { event in
            let dayStart = cal.startOfDay(for: day)
            guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return false }
            return event.startDate < dayEnd && event.endDate > dayStart
        }

        return Button {
            onTapDay(day)
        } label: {
            VStack(spacing: 0) {
                Text("\(dayNum)")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 18, height: 18)
                    .background {
                        if isToday {
                            Circle().fill(theme.accentColor)
                        }
                    }

                if hasEvents {
                    Circle()
                        .fill(theme.accentColor.opacity(0.5))
                        .frame(width: 3, height: 3)
                } else {
                    Spacer().frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    private var isCurrentMonth: Bool {
        cal.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    /// Returns array of optional dates: nil for empty grid cells, Date for real days
    private var miniMonthDays: [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return [] }
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30

        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingEmpty = (firstWeekday - cal.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in 0..<daysInMonth {
            if let d = cal.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(d)
            }
        }

        // Pad to fill last row
        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return days
    }
}
