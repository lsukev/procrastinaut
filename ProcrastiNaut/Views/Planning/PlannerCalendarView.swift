import SwiftUI
import UniformTypeIdentifiers

struct PlannerCalendarView: View {
    @Bindable var viewModel: PlannerViewModel
    private let theme = AppTheme.shared

    private var hourHeight: CGFloat { theme.hourRowHeightDay }
    private let timeGutterWidth: CGFloat = 52

    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        VStack(spacing: 0) {
            // All-day events bar
            if !viewModel.allDayEvents.isEmpty {
                allDayBar
                Divider()
            }

            // Calendar grid
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    calendarGrid
                        .id("calendarGrid")
                }
                .onAppear {
                    scrollToRelevantTime(proxy: proxy)
                }
                .onChange(of: viewModel.selectedDate) {
                    scrollToRelevantTime(proxy: proxy)
                }
            }
        }
        .onReceive(timer) { _ in now = Date() }
    }

    // MARK: - All-Day Events Bar

    private var allDayBar: some View {
        let events = viewModel.allDayEvents

        return HStack(spacing: 4) {
            Text("all-day")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: timeGutterWidth, alignment: .trailing)

            ForEach(events) { event in
                let eventColor = Color(cgColor: event.calendarColor)
                Text(event.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: events.count == 1 ? .infinity : nil, alignment: .leading)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(eventColor.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if viewModel.editingEvent?.id == event.id {
                                viewModel.cancelEdit()
                            } else {
                                viewModel.startEditing(event)
                            }
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    // MARK: - Calendar Grid Content

    private var calendarGrid: some View {
        ZStack(alignment: .topLeading) {
            // Hour rows in a real VStack so ScrollViewReader anchors work
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    hourRow(hour)
                        .id("hour-\(hour)")
                }
            }

            ghostBlocksLayer
            eventBlocksLayer

            // Drag ghost preview
            DragGhostOverlay(
                viewModel: viewModel,
                hourHeight: hourHeight,
                timeGutterWidth: timeGutterWidth
            )

            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                currentTimeIndicator
                    .id("currentTime")
            }
        }
        .padding(.trailing, 12)
        .contentShape(Rectangle())
        .onDrop(of: [.plainText], delegate: DayCalendarDropDelegate(
            viewModel: viewModel,
            hourHeight: hourHeight,
            selectedDate: viewModel.selectedDate
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
                    let y = value.location.y
                    let tappedTime = timeFromYPosition(y)
                    let snapped = viewModel.snapToGrid(tappedTime)
                    viewModel.createEventPrefilledStart = snapped
                    viewModel.showCreateEvent = true
                }
        )
    }

    // MARK: - Hour Grid

    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(hourLabel(hour))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isWorkingHour(hour) ? .secondary : .quaternary)
                .frame(width: timeGutterWidth, alignment: .trailing)
                .offset(y: -7) // Align label with the divider line

            Divider()
                .frame(width: 8)
                .opacity(0)

            VStack(spacing: 0) {
                // Hour line
                Rectangle()
                    .fill(Color.primary.opacity(isWorkingHour(hour) ? 0.35 : 0.15))
                    .frame(height: 0.5)
                Spacer()
                // Half-hour dashed line
                HalfHourDashLine(opacity: isWorkingHour(hour) ? 0.2 : 0.1)
                    .frame(height: 0.5)
                Spacer()
            }
        }
        .frame(height: hourHeight)
    }

    // MARK: - Event Blocks

    private var eventBlocksLayer: some View {
        let layouts = CalendarLayoutHelpers.computeEventLayouts(for: viewModel.timedEvents)
        return ForEach(viewModel.timedEvents) { event in
            let layout = layouts[event.id] ?? CalendarLayoutHelpers.EventLayout(column: 0, totalColumns: 1)
            eventBlock(event, column: layout.column, totalColumns: layout.totalColumns)
        }
    }

    // MARK: - Ghost Blocks (AI Suggestions)

    private var ghostBlocksLayer: some View {
        ForEach(viewModel.ghostEvents) { ghost in
            ghostBlock(ghost)
        }
    }

    private func ghostBlock(_ event: CalendarEventItem) -> some View {
        let y = yPosition(for: event.startDate)
        let height = max(24, durationHeight(from: event.startDate, to: event.endDate))
        let ghostPurple = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

        return GeometryReader { geo in
            let availableWidth = geo.size.width - timeGutterWidth - 12
            let xOffset = timeGutterWidth + 8

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(ghostPurple.opacity(0.12))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ghostPurple.opacity(0.5))
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                    .foregroundStyle(ghostPurple.opacity(0.7))

                                Text(event.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ghostPurple.opacity(0.9))
                                    .lineLimit(1)
                            }

                            if height > 32 {
                                Text(formatTimeRange(start: event.startDate, end: event.endDate))
                                    .font(.system(size: 9))
                                    .foregroundStyle(ghostPurple.opacity(0.5))
                            }
                        }
                        .padding(.leading, 6)
                        .padding(.vertical, 4)

                        Spacer()
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(ghostPurple.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                )
                .frame(width: availableWidth - 3, height: height)
                .position(x: xOffset + (availableWidth - 3) / 2, y: y + height / 2)
                .onTapGesture {
                    // Find and accept the corresponding suggestion
                    if let suggestion = viewModel.aiService.suggestions.first(where: {
                        "ghost-\($0.id.uuidString)" == event.id
                    }) {
                        withAnimation { viewModel.acceptAISuggestion(suggestion) }
                    }
                }
        }
    }

    private func eventBlock(_ event: CalendarEventItem, column: Int, totalColumns: Int) -> some View {
        let y = yPosition(for: event.startDate)
        let baseHeight = max(24, durationHeight(from: event.startDate, to: event.endDate))
        let isResizing = viewModel.resizingEventID == event.id
        let resizeDelta = isResizing ? viewModel.resizeDeltaY : 0
        let minHeight = 15.0 / 60.0 * hourHeight // 15 min minimum
        let height = max(minHeight, baseHeight + resizeDelta)
        let isSelected = viewModel.editingEvent?.id == event.id
        let eventColor = Color(cgColor: event.calendarColor)

        // Compute preview end time during resize
        let resizeEndTime: Date = {
            let deltaMinutes = Double(resizeDelta) / Double(hourHeight) * 60
            let newDuration = event.endDate.timeIntervalSince(event.startDate) + (deltaMinutes * 60)
            let clampedDuration = max(15 * 60, newDuration)
            return event.startDate.addingTimeInterval(clampedDuration)
        }()

        return GeometryReader { geo in
            let availableWidth = geo.size.width - timeGutterWidth - 12
            let colWidth = availableWidth / CGFloat(totalColumns)
            let xOffset = timeGutterWidth + 8 + colWidth * CGFloat(column)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(eventColor.opacity(isSelected ? 0.55 : 0.4))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(eventColor)
                                .frame(width: 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(height > 50 ? 3 : 1)

                                if height > 32 {
                                    Text(isResizing
                                         ? formatTimeRange(start: event.startDate, end: resizeEndTime)
                                         : formatTimeRange(start: event.startDate, end: event.endDate))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                if height > 50, let loc = event.location, !loc.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 8))
                                        Text(loc)
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.vertical, 4)

                            Spacer()
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                isSelected || isResizing ? .white.opacity(0.6) : Color.clear,
                                lineWidth: isSelected || isResizing ? 2 : 0
                            )
                    )

                // Resize handle at bottom
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    .overlay(alignment: .center) {
                        if isResizing {
                            Capsule()
                                .fill(.white.opacity(0.7))
                                .frame(width: 20, height: 3)
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
            .frame(width: colWidth - 3, height: height)
            .position(x: xOffset + (colWidth - 3) / 2, y: y + height / 2)
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
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        let y = yPosition(for: now)

        return HStack(spacing: 0) {
            Spacer().frame(width: timeGutterWidth)

            Circle()
                .fill(theme.nowLineColor)
                .frame(width: 10, height: 10)

            Rectangle()
                .fill(theme.nowLineColor)
                .frame(height: 2)
        }
        .offset(y: y - 5)
    }

    // MARK: - Coordinate Math

    private var startHour: Int { 0 }
    private var endHour: Int { 24 }

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    private func isWorkingHour(_ hour: Int) -> Bool {
        let workStart = Int(settings.workingHoursStart / 3600)
        let workEnd = Int(settings.workingHoursEnd / 3600)
        return hour >= workStart && hour < workEnd
    }

    private func yPosition(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let totalMinutes = CGFloat(hour * 60 + minute)
        let startMinutes = CGFloat(startHour * 60)
        return (totalMinutes - startMinutes) / 60 * hourHeight
    }

    private func timeFromYPosition(_ y: CGFloat) -> Date {
        let startMinutes = CGFloat(startHour * 60)
        let minutesFromStart = (y / hourHeight) * 60
        let totalMinutes = startMinutes + minutesFromStart

        let hours = max(0, min(Int(totalMinutes) / 60, 23))
        let minutes = max(0, min(Int(totalMinutes) % 60, 59))

        return Calendar.current.date(
            bySettingHour: hours,
            minute: minutes,
            second: 0,
            of: viewModel.selectedDate
        ) ?? viewModel.selectedDate
    }

    private func durationHeight(from start: Date, to end: Date) -> CGFloat {
        let durationMinutes = end.timeIntervalSince(start) / 60
        return CGFloat(durationMinutes) / 60 * hourHeight
    }

    // MARK: - Formatting

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "Noon" }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: start)) \u{2013} \(f.string(from: end))"
    }

    private func scrollToRelevantTime(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                // Scroll so the current hour is near the top with some context
                let currentHour = max(0, Calendar.current.component(.hour, from: Date()) - 1)
                proxy.scrollTo("hour-\(currentHour)", anchor: .top)
            } else {
                let workStart = Int(settings.workingHoursStart / 3600)
                proxy.scrollTo("hour-\(workStart)", anchor: .top)
            }
        }
    }
}
