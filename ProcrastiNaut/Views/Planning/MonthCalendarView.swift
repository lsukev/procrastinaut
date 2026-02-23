import SwiftUI

struct MonthCalendarView: View {
    @Bindable var viewModel: PlannerViewModel

    private let cal = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private let weatherService = WeatherService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Weekday header
            weekdayHeader

            // Month grid — fills all available space
            GeometryReader { geo in
                let days = monthDays
                let rowCount = days.count / 7
                let rowHeight = geo.size.height / CGFloat(rowCount)
                let showWeather = UserSettings.shared.showWeatherInMonthView
                // How many event lines fit: day number ~22px, weather ~14px, padding ~8px, each event ~14px
                let weatherHeight: CGFloat = showWeather ? 14 : 0
                let maxEvents = max(1, Int((rowHeight - 30 - weatherHeight) / 15))

                VStack(spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                let dayIndex = row * 7 + col
                                if dayIndex < days.count {
                                    let day = days[dayIndex]
                                    MonthDayCell(
                                        day: day,
                                        events: viewModel.events(for: day.date),
                                        weather: weatherService.weather(for: day.date),
                                        isToday: cal.isDateInToday(day.date),
                                        isSelected: cal.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                                        isCurrentMonth: day.isCurrentMonth,
                                        maxEventLines: maxEvents
                                    ) {
                                        viewModel.selectedDate = cal.startOfDay(for: day.date)
                                        viewModel.calendarViewMode = .day
                                        Task { await viewModel.loadData() }
                                    }
                                }
                            }
                        }
                        .frame(height: rowHeight)

                        if row < rowCount - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .task {
            await weatherService.fetchWeatherIfNeeded()
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(.regularMaterial)
    }

    // MARK: - Month Days Computation

    private var monthDays: [MonthDay] {
        let startOfMonth = cal.dateInterval(of: .month, for: viewModel.selectedDate)!.start
        let endOfMonth = cal.dateInterval(of: .month, for: viewModel.selectedDate)!.end

        let daysInMonth = cal.range(of: .day, in: .month, for: viewModel.selectedDate)!.count

        let firstWeekday = cal.component(.weekday, from: startOfMonth)
        let leadingEmpty = (firstWeekday - cal.firstWeekday + 7) % 7

        var days: [MonthDay] = []

        // Leading days from previous month
        for i in stride(from: leadingEmpty, through: 1, by: -1) {
            if let date = cal.date(byAdding: .day, value: -i, to: startOfMonth) {
                days.append(MonthDay(date: date, isCurrentMonth: false))
            }
        }

        // Current month days
        for day in 0..<daysInMonth {
            if let date = cal.date(byAdding: .day, value: day, to: startOfMonth) {
                days.append(MonthDay(date: date, isCurrentMonth: true))
            }
        }

        // Trailing days to fill last row
        let remainder = days.count % 7
        if remainder > 0 {
            let trailing = 7 - remainder
            for i in 0..<trailing {
                if let date = cal.date(byAdding: .day, value: i, to: endOfMonth) {
                    days.append(MonthDay(date: date, isCurrentMonth: false))
                }
            }
        }

        return days
    }
}

// MARK: - MonthDay Model

struct MonthDay {
    let date: Date
    let isCurrentMonth: Bool
}

// MARK: - Month Day Cell

struct MonthDayCell: View {
    let day: MonthDay
    let events: [CalendarEventItem]
    let weather: DayWeather?
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let maxEventLines: Int
    let onTap: () -> Void

    private let cal = Calendar.current
    private let theme = AppTheme.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                // Day number + weather
                HStack(spacing: 2) {
                    Text("\(cal.component(.day, from: day.date))")
                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                        .foregroundStyle(dayForeground)
                        .frame(width: 22, height: 22)
                        .background {
                            if isToday {
                                Circle().fill(theme.accentColor)
                            } else if isSelected {
                                Circle().strokeBorder(theme.accentColor, lineWidth: 1.5)
                            }
                        }
                    Spacer()
                    if let weather {
                        weatherLabel(weather)
                    }
                }
                .padding(.leading, 4)
                .padding(.trailing, 3)
                .padding(.top, 2)

                // Event bars
                let visibleEvents = Array(events.prefix(maxEventLines))
                let remaining = events.count - visibleEvents.count

                ForEach(Array(visibleEvents.enumerated()), id: \.offset) { _, event in
                    let eventColor = Color(cgColor: event.calendarColor)
                    HStack(spacing: 3) {
                        if event.isAllDay {
                            Text(event.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        } else {
                            Text(CalendarLayoutHelpers.shortTimeString(event.startDate))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(event.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(eventColor.opacity(event.isAllDay ? 0.75 : 0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.horizontal, 2)
                }

                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 5)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isSelected ? theme.accentColor.opacity(0.06) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 0.5),
                alignment: .trailing
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func weatherLabel(_ weather: DayWeather) -> some View {
        HStack(spacing: 2) {
            Image(systemName: weather.sfSymbolName)
                .font(.system(size: 8))
                .symbolRenderingMode(.multicolor)
            Text("\(weather.highTemp)\u{00B0}/\(weather.lowTemp)\u{00B0}")
                .font(.system(size: 8, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(isCurrentMonth ? .secondary : .quaternary)
        .lineLimit(1)
        .fixedSize()
    }

    private var dayForeground: Color {
        if isToday { return .white }
        if !isCurrentMonth { return .gray.opacity(0.4) }
        return .primary
    }
}

// MARK: - Array Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
