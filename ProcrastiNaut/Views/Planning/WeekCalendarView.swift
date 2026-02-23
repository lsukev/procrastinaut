import SwiftUI
import UniformTypeIdentifiers

struct WeekCalendarView: View {
    @Bindable var viewModel: PlannerViewModel
    private let theme = AppTheme.shared

    private var hourHeight: CGFloat { theme.hourRowHeightWeek }
    private let timeGutterWidth: CGFloat = 52
    private let dayHeaderHeight: CGFloat = 48

    @State private var now = Date()
    @State private var computedColumnWidth: CGFloat = 100
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var settings: UserSettings { UserSettings.shared }
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Day header row (fixed, doesn't scroll)
            dayHeaderRow

            // All-day events bar (compact, fixed)
            weekAllDayBar
            Divider()

            // Scrollable hour grid
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    weekGrid
                        .id("weekGrid")
                }
                .onAppear {
                    scrollToWorkStart(proxy: proxy)
                }
                .onChange(of: viewModel.selectedDate) {
                    scrollToWorkStart(proxy: proxy)
                }
            }
        }
        .onReceive(timer) { _ in now = Date() }
    }

    // MARK: - Day Header Row

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            // Time gutter spacer
            Spacer()
                .frame(width: timeGutterWidth)

            ForEach(Array(viewModel.weekDates.enumerated()), id: \.offset) { _, date in
                let isToday = cal.isDateInToday(date)
                let isSelected = cal.isDate(date, inSameDayAs: viewModel.selectedDate)

                Button {
                    viewModel.selectedDate = cal.startOfDay(for: date)
                    viewModel.calendarViewMode = .day
                    Task { await viewModel.loadData() }
                } label: {
                    VStack(spacing: 2) {
                        Text(dayAbbrev(date))
                            .font(theme.scaledFont(size: 10, weight: .medium))
                            .foregroundStyle(isToday ? theme.accentColor : .secondary)

                        Text("\(cal.component(.day, from: date))")
                            .font(theme.scaledFont(size: 16, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : (isSelected ? theme.accentColor : .primary))
                            .frame(width: 28, height: 28)
                            .background {
                                if isToday {
                                    Circle().fill(theme.accentColor)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .background(.regularMaterial)
    }

    // MARK: - All-Day Events

    private var weekAllDayBar: some View {
        HStack(spacing: 0) {
            Text("all-day")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: timeGutterWidth, alignment: .trailing)
                .padding(.trailing, 4)

            ForEach(viewModel.weekDates, id: \.self) { date in
                let events = viewModel.allDayEvents(for: date)

                if events.isEmpty {
                    Color.clear.frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 1) {
                        ForEach(events.prefix(2)) { event in
                            let eventColor = Color(cgColor: event.calendarColor)
                            let isSelected = viewModel.editingEvent?.id == event.id
                            Text(event.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(eventColor.opacity(isSelected ? 1.0 : 0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(.white.opacity(0.6), lineWidth: 1.5)
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isSelected {
                                            viewModel.cancelEdit()
                                        } else {
                                            viewModel.startEditing(event)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        viewModel.startEditing(event)
                                    } label: {
                                        Label("Edit Event", systemImage: "pencil")
                                    }

                                    Button {
                                        viewModel.createReminderFromEvent = event
                                        viewModel.showCreateReminder = true
                                    } label: {
                                        Label("Create Reminder", systemImage: "plus.circle")
                                    }

                                    let linkedReminders = viewModel.remindersFromEvent(event.id)
                                    if !linkedReminders.isEmpty {
                                        Menu {
                                            ForEach(linkedReminders) { reminder in
                                                Button {
                                                    viewModel.editingReminder = reminder
                                                } label: {
                                                    Text(reminder.title)
                                                }
                                            }
                                        } label: {
                                            Label("Linked Reminders (\(linkedReminders.count))", systemImage: "checklist")
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        viewModel.startEditing(event)
                                        viewModel.deleteEvent(id: event.id)
                                    } label: {
                                        Label("Delete Event", systemImage: "trash")
                                    }
                                }
                        }
                        if events.count > 2 {
                            Text("+\(events.count - 2) more")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Week Grid

    private var weekGrid: some View {
        ZStack(alignment: .topLeading) {
            // Hour rows
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    weekHourRow(hour)
                        .id("hour-\(hour)")
                }
            }

            // Event blocks and ghost blocks for each day column
            GeometryReader { geo in
                let columnWidth = (geo.size.width - timeGutterWidth - 12) / 7

                Color.clear.onAppear { computedColumnWidth = columnWidth }
                    .frame(width: 0, height: 0)

                ForEach(Array(viewModel.weekDates.enumerated()), id: \.offset) { dayIndex, date in
                    let dayTimedEvents = viewModel.timedEvents(for: date)
                    let dayGhostEvents = viewModel.ghostEvents(for: date)
                    let layouts = CalendarLayoutHelpers.computeEventLayouts(for: dayTimedEvents)
                    let dayXOffset = timeGutterWidth + 8 + columnWidth * CGFloat(dayIndex)

                    // Ghost events
                    ForEach(dayGhostEvents) { ghost in
                        weekGhostBlock(
                            ghost,
                            dayXOffset: dayXOffset,
                            columnWidth: columnWidth
                        )
                    }

                    // Real events
                    ForEach(dayTimedEvents) { event in
                        let layout = layouts[event.id] ?? CalendarLayoutHelpers.EventLayout(column: 0, totalColumns: 1)
                        weekEventBlock(
                            event,
                            layout: layout,
                            dayXOffset: dayXOffset,
                            columnWidth: columnWidth
                        )
                    }

                    // Current time indicator for today
                    if cal.isDateInToday(date) {
                        weekCurrentTimeIndicator(
                            dayXOffset: dayXOffset,
                            columnWidth: columnWidth
                        )
                        .id("currentTime")
                    }

                    // Drag ghost preview for this day column only
                    if let ghostTime = viewModel.dragGhostTime,
                       cal.isDate(ghostTime, inSameDayAs: date) {
                        WeekDragGhostOverlay(
                            viewModel: viewModel,
                            hourHeight: hourHeight,
                            timeGutterWidth: timeGutterWidth,
                            columnWidth: columnWidth,
                            dayIndex: dayIndex
                        )
                    }
                }
            }
        }
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .onDrop(of: [.plainText], delegate: WeekCalendarDropDelegate(
            viewModel: viewModel,
            hourHeight: hourHeight,
            timeGutterWidth: timeGutterWidth,
            computedColumnWidth: computedColumnWidth
        ))
        .onTapGesture {
            if viewModel.editingEvent != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.cancelEdit()
                }
            }
        }
        .gesture(
            SpatialTapGesture(count: 2)
                .onEnded { value in
                    let dates = viewModel.weekDates
                    guard !dates.isEmpty else { return }

                    let adjustedX = value.location.x - timeGutterWidth - 8
                    let dayIndex = min(6, max(0, Int(adjustedX / computedColumnWidth)))
                    let date = dates[dayIndex]

                    let rawTime = CalendarLayoutHelpers.timeFromYPosition(
                        value.location.y, hourHeight: hourHeight, on: date
                    )
                    let snapped = viewModel.snapToGrid(rawTime)
                    viewModel.createEventPrefilledStart = snapped
                    viewModel.showCreateEvent = true
                }
        )
    }

    // MARK: - Hour Row

    private func weekHourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(CalendarLayoutHelpers.hourLabel(hour))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(isWorkingHour(hour) ? .secondary : .quaternary)
                .frame(width: timeGutterWidth, alignment: .trailing)
                .offset(y: -6)

            // Vertical separators + hour line + half-hour dashed line for 7 columns
            GeometryReader { geo in
                let colWidth = geo.size.width / 7

                // Hour line across all columns
                Rectangle()
                    .fill(Color.primary.opacity(isWorkingHour(hour) ? 0.35 : 0.15))
                    .frame(height: 0.5)

                // Half-hour dashed line
                HalfHourDashLine(opacity: isWorkingHour(hour) ? 0.2 : 0.1)
                    .frame(height: 0.5)
                    .offset(y: geo.size.height / 2)

                // Vertical separators
                ForEach(0..<7, id: \.self) { col in
                    if col > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 0.5)
                            .offset(x: colWidth * CGFloat(col))
                    }
                }
            }
            .padding(.leading, 4)
        }
        .frame(height: hourHeight)
    }

    // MARK: - Event Block

    private func weekEventBlock(
        _ event: CalendarEventItem,
        layout: CalendarLayoutHelpers.EventLayout,
        dayXOffset: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        let y = CalendarLayoutHelpers.yPosition(for: event.startDate, hourHeight: hourHeight)
        let baseHeight = max(20, CalendarLayoutHelpers.durationHeight(from: event.startDate, to: event.endDate, hourHeight: hourHeight))
        let isResizing = viewModel.resizingEventID == event.id
        let resizeDelta = isResizing ? viewModel.resizeDeltaY : 0
        let minHeight = 15.0 / 60.0 * hourHeight
        let height = max(minHeight, baseHeight + resizeDelta)
        let isSelected = viewModel.editingEvent?.id == event.id
        let eventColor = Color(cgColor: event.calendarColor)

        let subColWidth = (columnWidth - 4) / CGFloat(layout.totalColumns)
        let xPos = dayXOffset + subColWidth * CGFloat(layout.column) + (subColWidth - 2) / 2

        // Compute preview end time during resize
        let resizeEndTime: Date = {
            let deltaMinutes = Double(resizeDelta) / Double(hourHeight) * 60
            let newDuration = event.endDate.timeIntervalSince(event.startDate) + (deltaMinutes * 60)
            let clampedDuration = max(15 * 60, newDuration)
            return event.startDate.addingTimeInterval(clampedDuration)
        }()

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(eventColor.opacity(isSelected ? 0.8 : 0.65))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(eventColor)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(theme.scaledFont(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(height > 40 ? 2 : 1)

                            if height > 24 {
                                Text(CalendarLayoutHelpers.compactTimeRange(
                                    start: isResizing ? event.startDate : event.startDate,
                                    end: isResizing ? resizeEndTime : event.endDate))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.75))
                            }

                            if height > 40, let loc = event.location, !loc.isEmpty {
                                Text(loc)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.vertical, 3)

                        Spacer(minLength: 0)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            isSelected || isResizing ? .white.opacity(0.6) : Color.clear,
                            lineWidth: isSelected || isResizing ? 2 : 0
                        )
                )

            // Resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(height: 6)
                .contentShape(Rectangle())
                .overlay(alignment: .center) {
                    if isResizing {
                        Capsule()
                            .fill(.white.opacity(0.7))
                            .frame(width: 16, height: 2)
                    }
                }
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else if !isResizing {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            viewModel.resizingEventID = event.id
                            viewModel.resizeDeltaY = value.translation.height
                        }
                        .onEnded { _ in
                            let newEnd = viewModel.snapToGrid(resizeEndTime)
                            viewModel.resizingEventID = nil
                            viewModel.resizeDeltaY = 0
                            viewModel.resizeEvent(event, newEndDate: newEnd)
                            NSCursor.pop()
                        }
                )
        }
        .frame(width: subColWidth - 2, height: height)
        .position(x: xPos, y: y + height / 2)
        .onDrag {
            NSItemProvider(object: "event:\(event.id):\(event.startDate.timeIntervalSince1970)" as NSString)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    viewModel.cancelEdit()
                } else {
                    viewModel.startEditing(event)
                }
            }
        }
            .contextMenu {
                Button {
                    viewModel.startEditing(event)
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                }

                Button {
                    viewModel.startFocusTimer(for: event)
                } label: {
                    Label("Start Focus Timer", systemImage: "timer")
                }

                Button {
                    viewModel.createReminderFromEvent = event
                    viewModel.showCreateReminder = true
                } label: {
                    Label("Create Reminder", systemImage: "plus.circle")
                }

                let linkedReminders = viewModel.remindersFromEvent(event.id)
                if !linkedReminders.isEmpty {
                    Menu {
                        ForEach(linkedReminders) { reminder in
                            Button {
                                viewModel.editingReminder = reminder
                            } label: {
                                Text(reminder.title)
                            }
                        }
                    } label: {
                        Label("Linked Reminders (\(linkedReminders.count))", systemImage: "checklist")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.startEditing(event)
                    viewModel.deleteEvent(id: event.id)
                } label: {
                    Label("Delete Event", systemImage: "trash")
                }
            }
    }

    // MARK: - Ghost Block

    private func weekGhostBlock(
        _ event: CalendarEventItem,
        dayXOffset: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        let y = CalendarLayoutHelpers.yPosition(for: event.startDate, hourHeight: hourHeight)
        let height = max(20, CalendarLayoutHelpers.durationHeight(from: event.startDate, to: event.endDate, hourHeight: hourHeight))
        let ghostPurple = Color(red: 0.545, green: 0.361, blue: 0.965)
        let blockWidth = columnWidth - 4
        let xPos = dayXOffset + blockWidth / 2

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(ghostPurple.opacity(0.12))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ghostPurple.opacity(0.5))
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 7))
                                .foregroundStyle(ghostPurple.opacity(0.7))

                            Text(event.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(ghostPurple.opacity(0.9))
                                .lineLimit(1)
                        }

                        if height > 28 {
                            Text(CalendarLayoutHelpers.shortTimeString(event.startDate))
                                .font(.system(size: 7))
                                .foregroundStyle(ghostPurple.opacity(0.5))
                        }
                    }
                    .padding(.leading, 3)
                    .padding(.vertical, 2)

                    Spacer(minLength: 0)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(ghostPurple.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
            )
            .frame(width: blockWidth, height: height)
            .position(x: xPos, y: y + height / 2)
            .onTapGesture {
                if let suggestion = viewModel.aiService.suggestions.first(where: {
                    "ghost-\($0.id.uuidString)" == event.id
                }) {
                    withAnimation { viewModel.acceptAISuggestion(suggestion) }
                }
            }
    }

    // MARK: - Current Time Indicator

    private func weekCurrentTimeIndicator(dayXOffset: CGFloat, columnWidth: CGFloat) -> some View {
        let y = CalendarLayoutHelpers.yPosition(for: now, hourHeight: hourHeight)

        return ZStack(alignment: .leading) {
            Circle()
                .fill(theme.nowLineColor)
                .frame(width: 8, height: 8)
                .offset(x: dayXOffset - 4, y: y - 4)

            Rectangle()
                .fill(theme.nowLineColor)
                .frame(width: columnWidth - 2, height: 1.5)
                .offset(x: dayXOffset, y: y - 0.75)
        }
    }

    // MARK: - Helpers

    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func isWorkingHour(_ hour: Int) -> Bool {
        let workStart = Int(settings.workingHoursStart / 3600)
        let workEnd = Int(settings.workingHoursEnd / 3600)
        return hour >= workStart && hour < workEnd
    }

    private func scrollToWorkStart(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let weekDates = viewModel.weekDates
            let hasToday = weekDates.contains { Calendar.current.isDateInToday($0) }
            if hasToday {
                // Scroll so the current hour is near the top with some context
                let currentHour = max(0, cal.component(.hour, from: Date()) - 1)
                proxy.scrollTo("hour-\(currentHour)", anchor: .top)
            } else {
                let workStart = Int(settings.workingHoursStart / 3600)
                proxy.scrollTo("hour-\(workStart)", anchor: .top)
            }
        }
    }

    /// Determine which day a drop occurred on based on x position.
    private func dayFromXPosition(_ x: CGFloat) -> Date? {
        let dates = viewModel.weekDates
        guard !dates.isEmpty else { return nil }
        let adjustedX = x - timeGutterWidth - 8
        guard adjustedX >= 0 else { return dates.first }
        let dayIndex = min(6, max(0, Int(adjustedX / computedColumnWidth)))
        return dates[dayIndex]
    }
}
