import SwiftUI
import EventKit

// MARK: - Models

struct ReminderListInfo: Identifiable, Hashable {
    let id: String          // calendar identifier
    let name: String
    let color: CGColor?
    let isMonitored: Bool
}

struct ReminderItem: Identifiable, Hashable {
    let id: String                    // calendarItemIdentifier
    let title: String
    let listName: String
    let listColor: CGColor?
    let priority: TaskPriority
    let dueDate: Date?
    let duration: TimeInterval        // seconds
    let notes: String?
    let url: URL?
    var isPlanned: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReminderItem, rhs: ReminderItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct CalendarEventItem: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarColor: CGColor
    let calendarID: String
    let calendarName: String
    let isProcrastiNaut: Bool
    let isAllDay: Bool
    let reminderIdentifier: String?   // extracted from notes if ProcrastiNaut event
    let location: String?
}

struct PendingInvitation: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: CGColor
    let calendarName: String
    let organizerName: String
    let attendeeCount: Int
    let location: String?
    let eventIdentifier: String   // for opening in Calendar.app
}

struct EventAttendee: Identifiable {
    let id: String
    let name: String
    let email: String?
    let status: AttendeeStatus
    let isOrganizer: Bool

    enum AttendeeStatus: String {
        case accepted, declined, tentative, pending, unknown

        var label: String {
            switch self {
            case .accepted: "Accepted"
            case .declined: "Declined"
            case .tentative: "Tentative"
            case .pending: "Pending"
            case .unknown: "Unknown"
            }
        }

        var symbolName: String {
            switch self {
            case .accepted: "checkmark.circle.fill"
            case .declined: "xmark.circle.fill"
            case .tentative: "questionmark.circle.fill"
            case .pending: "clock.fill"
            case .unknown: "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .accepted: .green
            case .declined: .red
            case .tentative: .orange
            case .pending: .secondary
            case .unknown: .secondary
            }
        }
    }
}

enum CalendarViewMode: String, CaseIterable {
    case day, week, month, year

    var label: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

enum ReminderSortMode: String, CaseIterable {
    case priority, dueDate, listName

    var label: String {
        switch self {
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .listName: "List"
        }
    }
}

/// Describes a pending action on a recurring event awaiting user span choice.
enum RecurrenceAction {
    case save
    case delete(id: String)
}

// MARK: - ViewModel

@MainActor
@Observable
final class PlannerViewModel {
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var calendarViewMode: CalendarViewMode = .day
    var reminders: [ReminderItem] = []
    var calendarEvents: [CalendarEventItem] = []
    var pendingInvitations: [PendingInvitation] = []
    var errorMessage: String?
    var isLoading = false
    var sortMode: ReminderSortMode = .priority
    var hideAlreadyPlanned = false
    var selectedListFilter: String? = nil   // nil = "All Lists" (monitored)

    /// All reminder lists available on the device
    var allReminderLists: [ReminderListInfo] = []

    // Reminder creation & editing
    var showCreateReminder = false
    var createReminderFromEvent: CalendarEventItem?
    var editingReminder: ReminderItem?

    /// Default list name for new reminders (user setting, first monitored, or first available)
    var defaultListName: String {
        let settingID = settings.defaultReminderListID
        if !settingID.isEmpty,
           let match = allReminderLists.first(where: { $0.id == settingID }) {
            return match.name
        }
        return allReminderLists.first(where: { $0.isMonitored })?.name
            ?? allReminderLists.first?.name
            ?? "Reminders"
    }

    // Event editing
    var editingEvent: CalendarEventItem?
    var editTitle: String = ""
    var editStartTime: Date = Date()
    var editEndTime: Date = Date()

    // Rich event detail (populated from full EKEvent lookup)
    var editLocation: String = ""
    var editNotes: String = ""
    var editURL: URL?
    var editCalendarName: String = ""
    var editCalendarColor: CGColor?
    var editIsReadOnly: Bool = false
    var editAttendees: [EventAttendee] = []
    var editAlarms: [String] = []
    var editRecurrenceDescription: String?
    var editLinkedReminderTitle: String?
    var editMeetingLink: URL?

    // Recurring event series prompt (edit/delete)
    var showRecurrenceChoice: Bool = false
    var pendingRecurrenceAction: RecurrenceAction?

    // Recurring event series prompt (move/drag)
    var showMoveRecurrenceChoice: Bool = false
    var pendingMoveEventID: String?
    var pendingMoveOccurrenceDate: Date?
    var pendingMoveNewStart: Date?
    var pendingMoveNewEnd: Date?

    // Create new event
    var showCreateEvent: Bool = false
    var createEventPrefilledStart: Date?

    // AI scheduling
    let aiService = AISchedulingService()
    var showAISuggestions: Bool = false

    // Chat bar
    let chatBarService = ChatBarService()
    var chatBarText: String = ""
    var showChatBarResult: Bool = false

    // Voice input
    let speechService = SpeechRecognitionService()

    // Undo
    var undoableAction: PlannerUndoAction?
    private var undoDismissTask: Task<Void, Never>?

    // Templates
    var showTemplateEditor: Bool = false

    // Command palette
    var showCommandPalette: Bool = false

    // Focus timer
    var focusTimerRunning: Bool = false
    var focusTimerEvent: CalendarEventItem?
    var focusTimerEndDate: Date?
    var focusTimerRemainingSeconds: Int = 0
    var focusTimerFormatted: String = ""
    var focusTimerProgress: Double = 0
    private var focusTimer: Timer?

    // Drag ghost preview
    var dragGhostTime: Date?
    var dragGhostItemID: String?
    var dragGhostTitle: String?
    var dragGhostDuration: TimeInterval = 1800 // default 30min

    // Resize event state
    var resizingEventID: String?
    var resizeDeltaY: CGFloat = 0

    // Sidebars
    var showTaskSidebar: Bool = true
    var showCalendarSidebar: Bool = false

    private let eventKitManager = EventKitManager.shared
    private let settings = UserSettings.shared
    private var changeObserver: NSObjectProtocol?

    /// Unique reminder list names from the loaded reminders, sorted alphabetically.
    var availableListNames: [String] {
        Array(Set(reminders.map(\.listName))).sorted()
    }

    var sortedReminders: [ReminderItem] {
        var list = reminders
        if hideAlreadyPlanned {
            list = list.filter { !$0.isPlanned }
        }
        switch sortMode {
        case .priority:
            list.sort { $0.priority < $1.priority }
        case .dueDate:
            list.sort {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        case .listName:
            list.sort { $0.listName.localizedCompare($1.listName) == .orderedAscending }
        }
        return list
    }

    // Overdue reminders
    var overdueReminders: [ReminderItem] {
        let now = Date()
        return reminders.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due < now && !reminder.isPlanned
        }
    }

    var overdueCount: Int {
        overdueReminders.count
    }

    var unplannedCount: Int {
        reminders.filter { !$0.isPlanned }.count
    }

    var plannedCount: Int {
        reminders.filter { $0.isPlanned }.count
    }

    var timedEvents: [CalendarEventItem] {
        calendarEvents.filter { !$0.isAllDay }
    }

    var allDayEvents: [CalendarEventItem] {
        calendarEvents.filter { $0.isAllDay }
    }

    var dayTitle: String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(selectedDate) {
            f.dateFormat = "'Today,' MMMM d"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            f.dateFormat = "'Tomorrow,' MMMM d"
        } else {
            f.dateFormat = "EEEE, MMMM d"
        }
        return f.string(from: selectedDate)
    }

    /// Title adapting to the current view mode
    var viewTitle: String {
        let cal = Calendar.current
        let f = DateFormatter()
        switch calendarViewMode {
        case .day:
            return dayTitle
        case .week:
            guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return "" }
            let weekEnd = cal.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            let f2 = DateFormatter()
            f.dateFormat = "MMM d"
            f2.dateFormat = "MMM d, yyyy"
            return "\(f.string(from: weekInterval.start)) – \(f2.string(from: weekEnd))"
        case .month:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: selectedDate)
        case .year:
            f.dateFormat = "yyyy"
            return f.string(from: selectedDate)
        }
    }

    /// Date range for the currently visible calendar area
    var visibleDateRange: (start: Date, end: Date) {
        let cal = Calendar.current
        switch calendarViewMode {
        case .day:
            let start = cal.startOfDay(for: selectedDate)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .week:
            let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate)!
            return (interval.start, interval.end)
        case .month:
            let interval = cal.dateInterval(of: .month, for: selectedDate)!
            // Extend to full weeks for grid display
            let displayStart = cal.dateInterval(of: .weekOfYear, for: interval.start)!.start
            let lastDay = cal.date(byAdding: .day, value: -1, to: interval.end)!
            let displayEnd = cal.dateInterval(of: .weekOfYear, for: lastDay)!.end
            return (displayStart, displayEnd)
        case .year:
            let interval = cal.dateInterval(of: .year, for: selectedDate)!
            return (interval.start, interval.end)
        }
    }

    /// 7 dates for the week containing selectedDate
    var weekDates: [Date] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Events filtered to a specific day
    func events(for date: Date) -> [CalendarEventItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return calendarEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
    }

    func timedEvents(for date: Date) -> [CalendarEventItem] {
        events(for: date).filter { !$0.isAllDay }
    }

    func allDayEvents(for date: Date) -> [CalendarEventItem] {
        events(for: date).filter { $0.isAllDay }
    }

    func ghostEvents(for date: Date) -> [CalendarEventItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return aiService.suggestions.compactMap { suggestion in
            guard suggestion.suggestedStartTime >= dayStart,
                  suggestion.suggestedStartTime < dayEnd else { return nil }
            return CalendarEventItem(
                id: "ghost-\(suggestion.id.uuidString)",
                title: suggestion.reminderTitle,
                startDate: suggestion.suggestedStartTime,
                endDate: suggestion.suggestedEndTime,
                calendarColor: NSColor.purple.cgColor,
                calendarID: "ghost",
                calendarName: "Suggestion",
                isProcrastiNaut: false,
                isAllDay: false,
                reminderIdentifier: suggestion.reminderID,
                location: nil
            )
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Populate available reminder lists for the picker
        let monitoredIDs = Set(settings.monitoredReminderListIDs)
        allReminderLists = eventKitManager.getAvailableReminderLists().map { cal in
            ReminderListInfo(
                id: cal.calendarIdentifier,
                name: cal.title,
                color: cal.cgColor,
                isMonitored: monitoredIDs.contains(cal.calendarIdentifier)
            )
        }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        // Fetch reminders from the selected list, or monitored lists if "All"
        let reminderLists: [EKCalendar]?
        if let filter = selectedListFilter,
           let selectedCal = eventKitManager.getAvailableReminderLists().first(where: { $0.title == filter }) {
            reminderLists = [selectedCal]
        } else {
            reminderLists = monitoredReminderLists()
        }
        let fetchedReminders = await eventKitManager.fetchOpenReminders(from: reminderLists)

        let range = visibleDateRange

        // Fetch events from union of viewable + monitored calendars
        let calendarsToFetch = mergedCalendars()
        let fetchedEvents = eventKitManager.fetchEvents(from: calendarsToFetch, start: range.start, end: range.end)

        // Convert events
        let eventItems = fetchedEvents.map { event in
            let isProcrastiNaut = event.notes?.contains("Created by ProcrastiNaut") ?? false
            var reminderID: String?
            if isProcrastiNaut, let notes = event.notes,
               let range = notes.range(of: #"Reminder: (.+)"#, options: .regularExpression) {
                let match = String(notes[range])
                reminderID = String(match.dropFirst("Reminder: ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n").first
            }
            return CalendarEventItem(
                id: event.calendarItemIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarColor: event.calendar.cgColor,
                calendarID: event.calendar.calendarIdentifier,
                calendarName: event.calendar.title,
                isProcrastiNaut: isProcrastiNaut,
                isAllDay: event.isAllDay,
                reminderIdentifier: reminderID,
                location: event.location
            )
        }

        // Build set of planned reminder IDs
        let plannedIDs = Set(eventItems.compactMap(\.reminderIdentifier))

        // Convert reminders
        let defaultDuration = TimeInterval(settings.defaultTaskDuration * 60)
        let reminderItems = fetchedReminders.map { reminder in
            let parsedDuration = DurationParser.parse(reminder.notes)
            return ReminderItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "Untitled",
                listName: reminder.calendar.title,
                listColor: reminder.calendar.cgColor,
                priority: TaskPriority.from(ekPriority: reminder.priority),
                dueDate: reminder.dueDateComponents?.date,
                duration: parsedDuration ?? defaultDuration,
                notes: reminder.notes,
                url: reminder.url,
                isPlanned: plannedIDs.contains(reminder.calendarItemIdentifier)
            )
        }

        // Filter displayed events: only viewable calendars + ProcrastiNaut-created events
        let viewableIDs = Set(settings.viewableCalendarIDs)
        self.calendarEvents = eventItems.filter { $0.isProcrastiNaut || viewableIDs.contains($0.calendarID) }
        self.reminders = reminderItems

        // Schedule system notifications for upcoming events
        // Uses async/await to avoid race condition between cancel and re-add
        let notifService = SystemNotificationService.shared
        await notifService.rescheduleAllEventReminders(for: self.calendarEvents)

        // Schedule overdue reminder notifications
        for reminder in self.reminders {
            if let due = reminder.dueDate, due < Date(), !reminder.isPlanned {
                notifService.scheduleOverdueReminder(
                    id: reminder.id, title: reminder.title, dueDate: due
                )
            }
        }

        // Load pending meeting invitations
        let rawInvitations = eventKitManager.fetchPendingInvitations(from: monitoredCalendars())
        self.pendingInvitations = rawInvitations.map { event in
            let organizerName = event.organizer?.name ?? "Unknown"
            return PendingInvitation(
                id: event.calendarItemIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarColor: event.calendar.cgColor,
                calendarName: event.calendar.title,
                organizerName: organizerName,
                attendeeCount: event.attendees?.count ?? 0,
                location: event.location,
                eventIdentifier: event.eventIdentifier
            )
        }

        // Schedule invitation notifications for new invitations
        for invite in self.pendingInvitations {
            notifService.scheduleInvitationAlert(
                id: invite.id, title: invite.title,
                organizer: invite.organizerName, startDate: invite.startDate
            )
        }
    }

    // MARK: - Invitation Actions

    /// Opens the event in Calendar.app so the user can accept/decline/tentative the invitation.
    func openInvitationInCalendar(_ invitation: PendingInvitation) {
        // calshow: opens Calendar.app to the given date (epoch seconds)
        let epoch = invitation.startDate.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
        if let url = URL(string: "ical://ekevent?id=\(invitation.eventIdentifier)") {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "calshow:\(epoch)") {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: - Drop Handling

    /// Unified drop handler — checks for event/template prefix first, falls back to reminder
    func handleDrop(itemID: String, atTime targetTime: Date) {
        if itemID.hasPrefix("event:") {
            handleEventMove(itemData: itemID, toTime: targetTime)
        } else if itemID.hasPrefix("template:") {
            let templateID = String(itemID.dropFirst("template:".count))
            handleTemplateDrop(templateID: templateID, atTime: targetTime)
        } else {
            handleDrop(reminderID: itemID, atTime: targetTime)
        }
    }

    /// Move an existing calendar event to a new time (and possibly day).
    /// itemData format: "event:{calendarItemIdentifier}:{originalStartTimestamp}"
    func handleEventMove(itemData: String, toTime targetTime: Date) {
        let parts = itemData.split(separator: ":")
        guard parts.count >= 3,
              let originalTimestamp = Double(parts[2]) else {
            errorMessage = "Invalid event drag data"
            return
        }
        let eventIdentifier = String(parts[1])
        let originalStartDate = Date(timeIntervalSince1970: originalTimestamp)

        // Find the event in our loaded events to get duration
        guard let existingEvent = calendarEvents.first(where: { $0.id == eventIdentifier }) else {
            errorMessage = "Event not found"
            return
        }

        let snappedStart = snapToGrid(targetTime)
        let duration = existingEvent.endDate.timeIntervalSince(existingEvent.startDate)
        let newEnd = snappedStart.addingTimeInterval(duration)

        // Check if this is a recurring event
        let ekEvent = eventKitManager.findEventOccurrence(identifier: eventIdentifier, on: originalStartDate)
            ?? eventKitManager.event(withIdentifier: eventIdentifier)
        let isRecurring = ekEvent?.recurrenceRules?.isEmpty == false

        if isRecurring {
            // Store the move info and show recurrence dialog
            pendingMoveEventID = eventIdentifier
            pendingMoveOccurrenceDate = originalStartDate
            pendingMoveNewStart = snappedStart
            pendingMoveNewEnd = newEnd
            showMoveRecurrenceChoice = true
            return
        }

        performEventMove(
            identifier: eventIdentifier,
            occurrenceDate: originalStartDate,
            newStart: snappedStart,
            newEnd: newEnd,
            span: .thisEvent
        )
    }

    private func performEventMove(
        identifier: String,
        occurrenceDate: Date,
        newStart: Date,
        newEnd: Date,
        span: EKSpan
    ) {
        let oldStart = occurrenceDate
        let oldDuration = newEnd.timeIntervalSince(newStart)
        let oldEnd = oldStart.addingTimeInterval(oldDuration)

        // Find original times from the actual event for accurate undo
        let originalEvent = calendarEvents.first(where: { $0.id == identifier })
        let undoStart = originalEvent?.startDate ?? oldStart
        let undoEnd = originalEvent?.endDate ?? oldEnd
        let eventTitle = originalEvent?.title ?? "Event"

        do {
            try eventKitManager.updateEvent(
                identifier: identifier,
                occurrenceDate: occurrenceDate,
                title: nil,
                startDate: newStart,
                endDate: newEnd,
                span: span
            )

            let ekManager = eventKitManager
            performUndoableAction(
                description: "Moved \"\(eventTitle)\"",
                action: { },
                undo: { [identifier, undoStart, undoEnd] in
                    await MainActor.run {
                        try? ekManager.updateEvent(
                            identifier: identifier,
                            occurrenceDate: newStart,
                            title: nil,
                            startDate: undoStart,
                            endDate: undoEnd
                        )
                    }
                }
            )
            Task { await loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called when the user picks a span for a recurring event move.
    func confirmMoveRecurrenceAction(span: EKSpan) {
        guard let id = pendingMoveEventID,
              let occDate = pendingMoveOccurrenceDate,
              let newStart = pendingMoveNewStart,
              let newEnd = pendingMoveNewEnd else { return }

        pendingMoveEventID = nil
        pendingMoveOccurrenceDate = nil
        pendingMoveNewStart = nil
        pendingMoveNewEnd = nil
        showMoveRecurrenceChoice = false

        performEventMove(
            identifier: id,
            occurrenceDate: occDate,
            newStart: newStart,
            newEnd: newEnd,
            span: span
        )
    }

    func handleTemplateDrop(templateID: String, atTime targetTime: Date) {
        guard let template = settings.eventTemplates.first(where: { $0.id.uuidString == templateID }) else {
            errorMessage = "Template not found"
            return
        }

        let snappedStart = snapToGrid(targetTime)
        let endTime = snappedStart.addingTimeInterval(template.duration)

        guard let calendar = getTargetCalendar() else {
            errorMessage = "Could not access calendar"
            return
        }

        do {
            let event = try eventKitManager.createCalendarEvent(
                title: template.name,
                startDate: snappedStart,
                endDate: endTime,
                calendar: calendar
            )

            let eventID = event.calendarItemIdentifier
            let eventStart = event.startDate ?? snappedStart
            let ekManager = eventKitManager
            withAnimation(.easeInOut(duration: 0.25)) {
                let undoAction = PlannerUndoAction(description: "Created \"\(template.name)\"") { [eventID, eventStart] in
                    await MainActor.run {
                        try? ekManager.deleteEvent(identifier: eventID, occurrenceDate: eventStart)
                    }
                }
                undoableAction = undoAction

                undoDismissTask?.cancel()
                undoDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(undoAction.duration))
                    if !Task.isCancelled {
                        await MainActor.run {
                            if self?.undoableAction?.id == undoAction.id {
                                self?.dismissUndo()
                            }
                        }
                    }
                }
            }

            errorMessage = nil
            Task { await loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleDrop(reminderID: String, atTime targetTime: Date) {
        guard let reminder = reminders.first(where: { $0.id == reminderID }) else {
            errorMessage = "Reminder not found"
            return
        }

        let snappedStart = snapToGrid(targetTime)
        let endTime = snappedStart.addingTimeInterval(reminder.duration)

        // Check working hours
        let workEndDate = dateAtTimeOfDay(settings.workingHoursEnd, on: selectedDate)
        if endTime > workEndDate {
            let remainingTime = workEndDate.timeIntervalSince(snappedStart)
            let minSlot = TimeInterval(settings.minimumSlotSize * 60)
            if remainingTime < minSlot {
                errorMessage = "Not enough time remaining in the workday"
                return
            }
        }

        // Check conflicts
        let monitoredCals = monitoredCalendars()
        let conflicts = eventKitManager.checkForConflicts(
            start: snappedStart,
            end: endTime,
            calendars: monitoredCals
        )
        if !conflicts.isEmpty {
            let names = conflicts.compactMap(\.title).joined(separator: ", ")
            errorMessage = "Conflicts with: \(names)"
            return
        }

        // Build task and create event
        guard let calendar = getTargetCalendar() else {
            errorMessage = "Could not access calendar"
            return
        }

        let task = ProcrastiNautTask(
            id: UUID(),
            reminderIdentifier: reminder.id,
            reminderTitle: reminder.title,
            reminderListName: reminder.listName,
            priority: reminder.priority,
            dueDate: reminder.dueDate,
            reminderNotes: reminder.notes,
            reminderURL: reminder.url,
            energyRequirement: .medium,
            suggestedStartTime: snappedStart,
            suggestedEndTime: endTime,
            suggestedDuration: reminder.duration,
            status: .approved,
            createdAt: Date()
        )

        do {
            let createdEvent = try eventKitManager.createTimeBlock(for: task, on: calendar)
            errorMessage = nil
            // Mark as planned immediately so checkmark shows before reload
            if let index = reminders.firstIndex(where: { $0.id == reminderID }) {
                reminders[index].isPlanned = true
            }

            // Wrap in undo action
            let eventID = createdEvent.calendarItemIdentifier
            let eventStart = createdEvent.startDate ?? snappedStart
            let ekManager = eventKitManager
            withAnimation(.easeInOut(duration: 0.25)) {
                let undoAction = PlannerUndoAction(description: "Scheduled \"\(reminder.title)\"") { [eventID, eventStart] in
                    await MainActor.run {
                        try? ekManager.deleteEvent(identifier: eventID, occurrenceDate: eventStart)
                    }
                }
                undoableAction = undoAction

                undoDismissTask?.cancel()
                undoDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(undoAction.duration))
                    if !Task.isCancelled {
                        await MainActor.run {
                            if self?.undoableAction?.id == undoAction.id {
                                self?.dismissUndo()
                            }
                        }
                    }
                }
            }

            Task { await loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEvent(id: String) {
        // If it's a recurring event, ask the user first
        if editRecurrenceDescription != nil {
            pendingRecurrenceAction = .delete(id: id)
            showRecurrenceChoice = true
            return
        }
        performDelete(id: id, span: .thisEvent)
    }

    private func performDelete(id: String, span: EKSpan) {
        guard let event = editingEvent else { return }
        do {
            try eventKitManager.deleteEvent(identifier: id, occurrenceDate: event.startDate, span: span)
            editingEvent = nil
            errorMessage = nil
            Task { await loadData() }
        } catch {
            editingEvent = nil
            errorMessage = error.localizedDescription
        }
    }

    func resizeEvent(_ event: CalendarEventItem, newEndDate: Date) {
        let snappedEnd = snapToGrid(newEndDate)
        // Ensure minimum 15-minute duration
        let minEnd = event.startDate.addingTimeInterval(15 * 60)
        let finalEnd = snappedEnd > minEnd ? snappedEnd : minEnd

        let oldEndDate = event.endDate

        do {
            try eventKitManager.updateEvent(
                identifier: event.id,
                occurrenceDate: event.startDate,
                title: nil,
                startDate: nil,
                endDate: finalEnd
            )
            performUndoableAction(
                description: "Resized \"\(event.title)\"",
                action: { },
                undo: { [weak self] in
                    guard let self else { return }
                    await MainActor.run {
                        try? self.eventKitManager.updateEvent(
                            identifier: event.id,
                            occurrenceDate: event.startDate,
                            title: nil,
                            startDate: nil,
                            endDate: oldEndDate
                        )
                    }
                    await self.loadData()
                }
            )
            Task { await loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startEditing(_ event: CalendarEventItem) {
        editingEvent = event
        editTitle = event.title
        editStartTime = event.startDate
        editEndTime = event.endDate

        // Fetch full EKEvent for rich detail
        let ekEvent = eventKitManager.findEventOccurrence(identifier: event.id, on: event.startDate)
            ?? (eventKitManager.event(withIdentifier: event.id))

        if let ek = ekEvent {
            editLocation = ek.location ?? ""
            editNotes = ek.notes ?? ""
            editURL = ek.url
            editCalendarName = ek.calendar.title
            editCalendarColor = ek.calendar.cgColor
            editIsReadOnly = !ek.calendar.allowsContentModifications
            editRecurrenceDescription = ek.recurrenceRules?.first.map { describeRecurrence($0) }

            editAttendees = (ek.attendees ?? []).map { participant in
                EventAttendee(
                    id: participant.url.absoluteString,
                    name: participant.name ?? participant.url.absoluteString,
                    email: extractEmail(from: participant),
                    status: mapParticipantStatus(participant.participantStatus),
                    isOrganizer: participant.isCurrentUser
                )
            }

            editAlarms = (ek.alarms ?? []).map { describeAlarm($0) }

            if event.isProcrastiNaut, let reminderID = event.reminderIdentifier {
                editLinkedReminderTitle = reminders.first(where: { $0.id == reminderID })?.title
            } else {
                editLinkedReminderTitle = nil
            }

            // Extract meeting link from notes, URL, or location
            editMeetingLink = extractMeetingLink(
                notes: ek.notes, url: ek.url, location: ek.location
            )
        } else {
            clearRichEditState()
        }
    }

    func saveEdit() {
        // If it's a recurring event, ask the user first
        if editRecurrenceDescription != nil {
            pendingRecurrenceAction = .save
            showRecurrenceChoice = true
            return
        }
        performSave(span: .thisEvent)
    }

    private func performSave(span: EKSpan) {
        guard let event = editingEvent else { return }
        do {
            try eventKitManager.updateEvent(
                identifier: event.id,
                occurrenceDate: event.startDate,
                title: editTitle,
                startDate: editStartTime,
                endDate: editEndTime,
                span: span
            )
            editingEvent = nil
            Task { await loadData() }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    /// Called when the user picks "This Event Only" or "All Future Events" from the recurrence dialog.
    func confirmRecurrenceAction(span: EKSpan) {
        guard let action = pendingRecurrenceAction else { return }
        pendingRecurrenceAction = nil
        showRecurrenceChoice = false

        switch action {
        case .save:
            performSave(span: span)
        case .delete(let id):
            performDelete(id: id, span: span)
        }
    }

    func cancelEdit() {
        editingEvent = nil
        clearRichEditState()
    }

    private func clearRichEditState() {
        editLocation = ""
        editNotes = ""
        editURL = nil
        editCalendarName = ""
        editCalendarColor = nil
        editIsReadOnly = false
        editAttendees = []
        editAlarms = []
        editRecurrenceDescription = nil
        editLinkedReminderTitle = nil
        editMeetingLink = nil
    }

    // MARK: - Meeting Link Extraction

    /// Searches notes, URL, and location fields for video conferencing links
    /// (Microsoft Teams, Zoom, Google Meet, Webex, GoTo Meeting).
    private func extractMeetingLink(notes: String?, url: URL?, location: String?) -> URL? {
        // Check the event's URL property first (some calendars put the join link there)
        if let url, isMeetingURL(url) {
            return url
        }

        // Search notes for a meeting URL
        let searchTexts = [notes, location].compactMap { $0 }
        for text in searchTexts {
            if let found = findMeetingURL(in: text) {
                return found
            }
        }
        return nil
    }

    private func isMeetingURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return meetingHostPatterns.contains(where: { host.contains($0) })
    }

    private func findMeetingURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text),
                  let url = URL(string: String(text[range])) else { continue }
            if isMeetingURL(url) {
                return url
            }
        }
        return nil
    }

    private let meetingHostPatterns = [
        "teams.microsoft.com",
        "teams.live.com",
        "zoom.us",
        "meet.google.com",
        "webex.com",
        "gotomeeting.com",
        "gotomeet.me",
        "chime.aws",
        "bluejeans.com",
    ]

    // MARK: - Reminder Context Menu Actions

    func completeReminder(_ reminder: ReminderItem) {
        do {
            try eventKitManager.completeReminder(identifier: reminder.id)
            reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = "Failed to complete: \(error.localizedDescription)"
        }
    }

    func setReminderPriority(_ reminder: ReminderItem, priority: TaskPriority) {
        do {
            try eventKitManager.updateReminderPriority(identifier: reminder.id, priority: priority)
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                let old = reminders[index]
                reminders[index] = ReminderItem(
                    id: old.id, title: old.title, listName: old.listName,
                    listColor: old.listColor, priority: priority, dueDate: old.dueDate,
                    duration: old.duration, notes: old.notes, url: old.url,
                    isPlanned: old.isPlanned
                )
            }
        } catch {
            errorMessage = "Failed to set priority: \(error.localizedDescription)"
        }
    }

    func setReminderDueDate(_ reminder: ReminderItem, date: Date?) {
        do {
            try eventKitManager.updateReminderDueDate(identifier: reminder.id, dueDate: date)
            Task { await loadData() }
        } catch {
            errorMessage = "Failed to set due date: \(error.localizedDescription)"
        }
    }

    func moveReminder(_ reminder: ReminderItem, toListNamed listName: String) {
        guard let targetList = eventKitManager.reminderList(withTitle: listName) else {
            errorMessage = "List '\(listName)' not found"
            return
        }
        do {
            try eventKitManager.moveReminder(identifier: reminder.id, toList: targetList)
            Task { await loadData() }
        } catch {
            errorMessage = "Failed to move reminder: \(error.localizedDescription)"
        }
    }

    func deleteReminder(_ reminder: ReminderItem) {
        do {
            try eventKitManager.deleteReminder(identifier: reminder.id)
            reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Reminder Creation

    func createReminder(
        title: String,
        listName: String,
        dueDate: Date?,
        dueTime: DateComponents?,
        priority: TaskPriority,
        durationMinutes: Int,
        notes: String?,
        tags: [String],
        location: String?,
        url: URL?,
        fromEventID: String? = nil
    ) async {
        guard let targetList = eventKitManager.reminderList(withTitle: listName)
                ?? eventKitManager.getAvailableReminderLists().first else {
            errorMessage = "No reminder lists available"
            return
        }

        let composedNotes = NoteMetadataBuilder.buildNotes(
            durationMinutes: durationMinutes,
            location: location,
            userNotes: notes,
            tags: tags,
            fromEventID: fromEventID
        )

        do {
            _ = try eventKitManager.createReminder(
                title: title,
                list: targetList,
                dueDate: dueDate,
                dueTime: dueTime,
                priority: priority,
                notes: composedNotes.isEmpty ? nil : composedNotes,
                url: url
            )
            // Keep sheet open when creating from an event (user may add more)
            if createReminderFromEvent == nil {
                showCreateReminder = false
            }
            await loadData()
        } catch {
            errorMessage = "Failed to create reminder: \(error.localizedDescription)"
        }
    }

    /// Returns reminders that were created from a specific calendar event.
    func remindersFromEvent(_ eventID: String) -> [ReminderItem] {
        reminders.filter { NoteMetadataBuilder.parseEventID(from: $0.notes) == eventID }
    }

    // MARK: - Reminder Editing

    func updateReminder(
        id: String,
        title: String,
        listName: String,
        dueDate: Date?,
        dueTime: DateComponents?,
        priority: TaskPriority,
        durationMinutes: Int,
        notes: String?,
        tags: [String],
        location: String?,
        url: URL?,
        fromEventID: String? = nil
    ) async {
        guard let targetList = eventKitManager.reminderList(withTitle: listName)
                ?? eventKitManager.getAvailableReminderLists().first else {
            errorMessage = "No reminder lists available"
            return
        }

        let composedNotes = NoteMetadataBuilder.buildNotes(
            durationMinutes: durationMinutes,
            location: location,
            userNotes: notes,
            tags: tags,
            fromEventID: fromEventID
        )

        do {
            try eventKitManager.updateReminder(
                identifier: id,
                title: title,
                list: targetList,
                dueDate: dueDate,
                dueTime: dueTime,
                priority: priority,
                notes: composedNotes.isEmpty ? nil : composedNotes,
                url: url
            )
            editingReminder = nil
            await loadData()
        } catch {
            errorMessage = "Failed to update reminder: \(error.localizedDescription)"
        }
    }

    // MARK: - Create Event

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarID: String,
        location: String?,
        notes: String?,
        url: URL?,
        recurrenceRule: EKRecurrenceRule?
    ) async {
        guard let calendar = eventKitManager.calendar(withIdentifier: calendarID) else {
            errorMessage = "Calendar not found"
            return
        }

        do {
            _ = try eventKitManager.createCalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                location: location,
                notes: notes,
                url: url,
                recurrenceRule: recurrenceRule
            )
            showCreateEvent = false
            await loadData()
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
    }

    /// Writable calendars available for event creation, including account source name
    var writableCalendars: [(id: String, name: String, color: CGColor, sourceName: String)] {
        eventKitManager.getAvailableCalendars()
            .filter { $0.allowsContentModifications }
            .map { (id: $0.calendarIdentifier, name: $0.title, color: $0.cgColor, sourceName: $0.source.title) }
    }

    // MARK: - Navigation

    func navigateDay(offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        selectedDate = newDate
        Task { await loadData() }
    }

    /// Navigate forward/backward by the appropriate interval for the current view mode
    func navigate(offset: Int) {
        let cal = Calendar.current
        let component: Calendar.Component
        switch calendarViewMode {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        guard let newDate = cal.date(byAdding: component, value: offset, to: selectedDate) else { return }
        selectedDate = newDate
        Task { await loadData() }
    }

    func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
        Task { await loadData() }
    }

    // MARK: - Chat Bar

    func submitChatBar() async {
        let input = chatBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        guard let action = await chatBarService.processInput(input) else {
            showChatBarResult = true
            return
        }

        let result = await chatBarService.executeAction(action)
        chatBarService.lastResult = result

        if result.success {
            chatBarText = ""
            showChatBarResult = true
            await loadData()

            // Auto-dismiss success after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                if showChatBarResult {
                    showChatBarResult = false
                    chatBarService.lastResult = nil
                }
            }
        } else {
            showChatBarResult = true
        }
    }

    func toggleVoiceInput() async {
        if speechService.isRecording {
            speechService.stopRecording()
            // Transfer transcribed text to chat bar and auto-submit
            let transcribed = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcribed.isEmpty {
                chatBarText = transcribed
                await submitChatBar()
            }
        } else {
            let granted = await speechService.requestPermission()
            guard granted else {
                chatBarService.error = speechService.error
                showChatBarResult = true
                return
            }
            do {
                try speechService.startRecording()
            } catch {
                chatBarService.error = "Microphone error: \(error.localizedDescription)"
                showChatBarResult = true
            }
        }
    }

    // MARK: - Undo

    func performUndoableAction(description: String, action: () throws -> Void, undo: @escaping @Sendable () async -> Void) {
        do {
            try action()

            undoDismissTask?.cancel()

            let undoAction = PlannerUndoAction(description: description, undo: undo)
            withAnimation(.easeInOut(duration: 0.25)) {
                undoableAction = undoAction
            }

            // Auto-dismiss after duration
            undoDismissTask = Task {
                try? await Task.sleep(for: .seconds(undoAction.duration))
                if !Task.isCancelled, undoableAction?.id == undoAction.id {
                    dismissUndo()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func executeUndo() {
        guard let action = undoableAction else { return }
        undoDismissTask?.cancel()
        let undoClosure = action.undoClosure
        withAnimation(.easeInOut(duration: 0.25)) {
            undoableAction = nil
        }
        Task {
            await undoClosure()
            await loadData()
        }
    }

    func dismissUndo() {
        undoDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            undoableAction = nil
        }
    }

    // MARK: - Focus Timer

    func startFocusTimer(for event: CalendarEventItem) {
        stopFocusTimer()
        focusTimerEvent = event
        focusTimerEndDate = event.endDate
        focusTimerRunning = true
        updateFocusTimer()

        focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFocusTimer()
            }
        }
    }

    func stopFocusTimer() {
        focusTimer?.invalidate()
        focusTimer = nil
        focusTimerRunning = false
        focusTimerEvent = nil
        focusTimerEndDate = nil
        focusTimerRemainingSeconds = 0
        focusTimerFormatted = ""
        focusTimerProgress = 0
    }

    private func updateFocusTimer() {
        guard let endDate = focusTimerEndDate, let event = focusTimerEvent else { return }

        focusTimerRemainingSeconds = max(0, Int(endDate.timeIntervalSinceNow))

        if focusTimerRemainingSeconds <= 0 {
            SystemNotificationService.shared.scheduleFocusTimerEnd(title: event.title)
            stopFocusTimer()
            return
        }

        let minutes = focusTimerRemainingSeconds / 60
        let seconds = focusTimerRemainingSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            focusTimerFormatted = String(format: "%d:%02d:%02d", hours, mins, seconds)
        } else {
            focusTimerFormatted = String(format: "%d:%02d", minutes, seconds)
        }

        let total = event.endDate.timeIntervalSince(event.startDate)
        let elapsed = Date().timeIntervalSince(event.startDate)
        focusTimerProgress = min(1.0, max(0.0, elapsed / total))
    }

    // MARK: - Drag Ghost Preview

    func updateDragGhost(itemID: String, at position: CGFloat, hourHeight: CGFloat, on date: Date) {
        let rawTime = CalendarLayoutHelpers.timeFromYPosition(position, hourHeight: hourHeight, on: date)
        let snapped = snapToGrid(rawTime)
        dragGhostTime = snapped

        if dragGhostItemID != itemID {
            dragGhostItemID = itemID
            // Determine title and duration from item
            if itemID.hasPrefix("event:") {
                let parts = itemID.split(separator: ":")
                if parts.count >= 2 {
                    let eventIdentifier = String(parts[1])
                    if let existingEvent = calendarEvents.first(where: { $0.id == eventIdentifier }) {
                        dragGhostTitle = existingEvent.title
                        dragGhostDuration = existingEvent.endDate.timeIntervalSince(existingEvent.startDate)
                    }
                }
            } else if itemID.hasPrefix("template:") {
                let templateIDStr = String(itemID.dropFirst("template:".count))
                if let templateID = UUID(uuidString: templateIDStr),
                   let template = settings.eventTemplates.first(where: { $0.id == templateID }) {
                    dragGhostTitle = template.name
                    dragGhostDuration = template.duration
                }
            } else if let reminder = reminders.first(where: { $0.id == itemID }) {
                dragGhostTitle = reminder.title
                dragGhostDuration = reminder.duration > 0 ? reminder.duration : 1800
            } else {
                dragGhostTitle = "New Event"
                dragGhostDuration = 1800
            }
        }
    }

    func clearDragGhost() {
        dragGhostTime = nil
        dragGhostItemID = nil
        dragGhostTitle = nil
        dragGhostDuration = 1800
    }

    // MARK: - AI Scheduling

    /// Ghost events for the currently displayed day (from AI suggestions)
    var ghostEvents: [CalendarEventItem] {
        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        return aiService.suggestions.compactMap { suggestion in
            guard suggestion.suggestedStartTime >= dayStart,
                  suggestion.suggestedStartTime < dayEnd else { return nil }
            return CalendarEventItem(
                id: "ghost-\(suggestion.id.uuidString)",
                title: suggestion.reminderTitle,
                startDate: suggestion.suggestedStartTime,
                endDate: suggestion.suggestedEndTime,
                calendarColor: NSColor.purple.cgColor,
                calendarID: "ghost",
                calendarName: "Suggestion",
                isProcrastiNaut: false,
                isAllDay: false,
                reminderIdentifier: suggestion.reminderID,
                location: nil
            )
        }
    }

    func requestAISuggestions() async {
        guard settings.aiEnabled else {
            errorMessage = "AI scheduling is disabled. Enable it in Settings > AI."
            return
        }

        // Show the panel immediately so the loading animation is visible
        withAnimation(.easeInOut(duration: 0.25)) {
            showAISuggestions = true
        }

        // Fetch events across the look-ahead period
        let lookAheadDays = settings.aiLookAheadDays
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: lookAheadDays, to: start) else { return }
        let monitoredCals = monitoredCalendars()
        let multiDayEvents = eventKitManager.fetchEvents(from: monitoredCals, start: start, end: end)

        let eventItems = multiDayEvents.map { event in
            CalendarEventItem(
                id: event.calendarItemIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarColor: event.calendar.cgColor,
                calendarID: event.calendar.calendarIdentifier,
                calendarName: event.calendar.title,
                isProcrastiNaut: event.notes?.contains("Created by ProcrastiNaut") ?? false,
                isAllDay: event.isAllDay,
                reminderIdentifier: nil,
                location: event.location
            )
        }

        await aiService.generateSuggestions(
            reminders: reminders,
            events: eventItems,
            lookAheadDays: lookAheadDays
        )
    }

    func acceptAISuggestion(_ suggestion: AISuggestion) {
        let accepted = aiService.acceptSuggestion(suggestion)

        guard let reminder = reminders.first(where: { $0.id == accepted.reminderID }) else {
            errorMessage = "Reminder not found for this suggestion"
            return
        }

        guard let calendar = getTargetCalendar() else {
            errorMessage = "Could not access calendar"
            return
        }

        // Check for conflicts at accept time
        let monitoredCals = monitoredCalendars()
        let conflicts = eventKitManager.checkForConflicts(
            start: accepted.suggestedStartTime,
            end: accepted.suggestedEndTime,
            calendars: monitoredCals
        )
        if !conflicts.isEmpty {
            let names = conflicts.compactMap(\.title).joined(separator: ", ")
            errorMessage = "Conflicts with: \(names)"
            return
        }

        let task = ProcrastiNautTask(
            id: UUID(),
            reminderIdentifier: reminder.id,
            reminderTitle: reminder.title,
            reminderListName: reminder.listName,
            priority: reminder.priority,
            dueDate: reminder.dueDate,
            reminderNotes: reminder.notes,
            reminderURL: reminder.url,
            energyRequirement: .medium,
            suggestedStartTime: accepted.suggestedStartTime,
            suggestedEndTime: accepted.suggestedEndTime,
            suggestedDuration: accepted.suggestedEndTime.timeIntervalSince(accepted.suggestedStartTime),
            status: .approved,
            createdAt: Date()
        )

        do {
            _ = try eventKitManager.createTimeBlock(for: task, on: calendar)
            errorMessage = nil
            // Navigate to the suggestion's day
            let suggestionDay = Calendar.current.startOfDay(for: accepted.suggestedDate)
            if suggestionDay != selectedDate {
                selectedDate = suggestionDay
            }
            Task { await loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Change Observation

    func startObservingChanges() {
        changeObserver = eventKitManager.observeChanges { [weak self] in
            Task { @MainActor in
                await self?.loadData()
            }
        }
    }

    func stopObservingChanges() {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
            changeObserver = nil
        }
    }

    // MARK: - Helpers

    func snapToGrid(_ date: Date, intervalMinutes: Int = 15) -> Date {
        let cal = Calendar.current
        let minute = cal.component(.minute, from: date)
        let snappedMinute = (minute / intervalMinutes) * intervalMinutes
        return cal.date(
            bySettingHour: cal.component(.hour, from: date),
            minute: snappedMinute,
            second: 0,
            of: date
        ) ?? date
    }

    private func dateAtTimeOfDay(_ secondsFromMidnight: Double, on date: Date) -> Date {
        let dayStart = Calendar.current.startOfDay(for: date)
        return dayStart.addingTimeInterval(secondsFromMidnight)
    }

    private func monitoredCalendars() -> [EKCalendar]? {
        let ids = settings.monitoredCalendarIDs
        guard !ids.isEmpty else { return nil }
        return ids.compactMap { eventKitManager.calendar(withIdentifier: $0) }
    }

    private func viewableCalendars() -> [EKCalendar]? {
        let ids = settings.viewableCalendarIDs
        guard !ids.isEmpty else { return nil }
        return ids.compactMap { eventKitManager.calendar(withIdentifier: $0) }
    }

    /// Returns the union of viewable + monitored calendars for fetching events.
    /// Viewable events are shown on the calendar; monitored events are used for conflict detection.
    private func mergedCalendars() -> [EKCalendar]? {
        let allIDs = Set(settings.viewableCalendarIDs).union(settings.monitoredCalendarIDs)
        guard !allIDs.isEmpty else { return nil }
        return allIDs.compactMap { eventKitManager.calendar(withIdentifier: $0) }
    }

    private func monitoredReminderLists() -> [EKCalendar]? {
        let ids = settings.monitoredReminderListIDs
        guard !ids.isEmpty else { return nil }
        return ids.compactMap { eventKitManager.calendar(withIdentifier: $0) }
    }

    private func getTargetCalendar() -> EKCalendar? {
        if !settings.blockingCalendarID.isEmpty,
           let cal = eventKitManager.calendar(withIdentifier: settings.blockingCalendarID) {
            return cal
        }
        return eventKitManager.getOrCreateProcrastiNautCalendar()
    }

    // MARK: - Event Detail Helpers

    private func mapParticipantStatus(_ status: EKParticipantStatus) -> EventAttendee.AttendeeStatus {
        switch status {
        case .accepted: .accepted
        case .declined: .declined
        case .tentative: .tentative
        case .pending: .pending
        default: .unknown
        }
    }

    private func extractEmail(from participant: EKParticipant) -> String? {
        let urlString = participant.url.absoluteString
        if urlString.hasPrefix("mailto:") {
            return String(urlString.dropFirst(7))
        }
        return nil
    }

    private func describeAlarm(_ alarm: EKAlarm) -> String {
        let offset = alarm.relativeOffset
        if offset == 0 { return "At time of event" }
        let minutes = Int(abs(offset) / 60)
        if minutes < 60 { return "\(minutes)m before" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours)h before" }
        return "\(hours)h \(remainingMinutes)m before"
    }

    private func describeRecurrence(_ rule: EKRecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: return "Repeats daily"
        case .weekly: return "Repeats weekly"
        case .monthly: return "Repeats monthly"
        case .yearly: return "Repeats yearly"
        @unknown default: return "Repeats"
        }
    }
}
