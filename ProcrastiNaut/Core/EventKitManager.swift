import EventKit
import SwiftData

enum PermissionState: Sendable {
    case allGranted
    case calendarDenied
    case remindersDenied
    case allDenied
    case notDetermined
}

@MainActor
@Observable
final class EventKitManager {
    static let shared = EventKitManager()

    private let eventStore = EKEventStore()
    private(set) var permissionState: PermissionState = .notDetermined

    // MARK: - Permissions

    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            updatePermissionState()
            return granted
        } catch {
            print("Calendar access error: \(error)")
            updatePermissionState()
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            updatePermissionState()
            return granted
        } catch {
            print("Reminders access error: \(error)")
            updatePermissionState()
            return false
        }
    }

    func checkPermissions() -> PermissionState {
        updatePermissionState()
        return permissionState
    }

    private func updatePermissionState() {
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        let remStatus = EKEventStore.authorizationStatus(for: .reminder)

        switch (calStatus, remStatus) {
        case (.fullAccess, .fullAccess):
            permissionState = .allGranted
        case (.fullAccess, _):
            permissionState = .remindersDenied
        case (_, .fullAccess):
            permissionState = .calendarDenied
        case (.notDetermined, _), (_, .notDetermined):
            permissionState = .notDetermined
        default:
            permissionState = .allDenied
        }
    }

    // MARK: - Calendars

    func getAvailableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    func getAvailableReminderLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
    }

    func getOrCreateProcrastiNautCalendar() -> EKCalendar? {
        // Check if it already exists
        if let existing = getAvailableCalendars().first(where: { $0.title == "ProcrastiNaut" }) {
            return existing
        }

        // Create it
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "ProcrastiNaut"

        // Use the default local source, or iCloud source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            return nil
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("Failed to create ProcrastiNaut calendar: \(error)")
            return nil
        }
    }

    func calendar(withIdentifier id: String) -> EKCalendar? {
        eventStore.calendar(withIdentifier: id)
    }

    // MARK: - Reminders

    /// Create a new reminder in the specified list with full metadata
    func createReminder(
        title: String,
        list: EKCalendar,
        dueDate: Date? = nil,
        dueTime: DateComponents? = nil,
        priority: TaskPriority = .none,
        notes: String? = nil,
        url: URL? = nil
    ) throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = list

        if let dueDate {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            if let time = dueTime {
                components.hour = time.hour
                components.minute = time.minute
            }
            reminder.dueDateComponents = components
        }

        // Map TaskPriority to EKReminder priority
        switch priority {
        case .high: reminder.priority = 1
        case .medium: reminder.priority = 5
        case .low: reminder.priority = 9
        case .none: reminder.priority = 0
        }

        reminder.notes = notes
        reminder.url = url

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    /// Find a reminder list by title
    func reminderList(withTitle title: String) -> EKCalendar? {
        getAvailableReminderLists().first { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }
    }

    func fetchOpenReminders(from lists: [EKCalendar]?) async -> [EKReminder] {
        let calendars = lists?.isEmpty == false ? lists : nil
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let result = reminders ?? []
                // EKReminder is not Sendable but we're on @MainActor, so this is safe
                nonisolated(unsafe) let sendableResult = result
                continuation.resume(returning: sendableResult)
            }
        }
    }

    func completeReminder(identifier: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    /// Update a reminder's priority
    func updateReminderPriority(identifier: String, priority: TaskPriority) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        switch priority {
        case .high: reminder.priority = 1
        case .medium: reminder.priority = 5
        case .low: reminder.priority = 9
        case .none: reminder.priority = 0
        }
        try eventStore.save(reminder, commit: true)
    }

    /// Update a reminder's due date
    func updateReminderDueDate(identifier: String, dueDate: Date?) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate
            )
        } else {
            reminder.dueDateComponents = nil
        }
        try eventStore.save(reminder, commit: true)
    }

    /// Move a reminder to a different list
    func moveReminder(identifier: String, toList: EKCalendar) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        reminder.calendar = toList
        try eventStore.save(reminder, commit: true)
    }

    /// Delete a reminder permanently
    func deleteReminder(identifier: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        try eventStore.remove(reminder, commit: true)
    }

    /// Update a reminder's notes
    func updateReminderNotes(identifier: String, notes: String?) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        reminder.notes = notes
        try eventStore.save(reminder, commit: true)
    }

    /// Update a reminder's URL
    func updateReminderURL(identifier: String, url: URL?) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }
        reminder.url = url
        try eventStore.save(reminder, commit: true)
    }

    /// Update all editable fields of a reminder in a single save.
    func updateReminder(
        identifier: String,
        title: String,
        list: EKCalendar,
        dueDate: Date?,
        dueTime: DateComponents?,
        priority: TaskPriority,
        notes: String?,
        url: URL?
    ) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw ProcrastiNautError.reminderNotFound
        }

        reminder.title = title
        reminder.calendar = list

        if let dueDate {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            if let time = dueTime {
                components.hour = time.hour
                components.minute = time.minute
            }
            reminder.dueDateComponents = components
        } else {
            reminder.dueDateComponents = nil
        }

        switch priority {
        case .high: reminder.priority = 1
        case .medium: reminder.priority = 5
        case .low: reminder.priority = 9
        case .none: reminder.priority = 0
        }

        reminder.notes = notes
        reminder.url = url

        try eventStore.save(reminder, commit: true)
    }

    // MARK: - Calendar Events

    func fetchEvents(from calendars: [EKCalendar]?, start: Date, end: Date) -> [EKEvent] {
        let cals = calendars?.isEmpty == false ? calendars : nil
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: cals)
        return eventStore.events(matching: predicate)
    }

    /// Fetch events in the next 3 months where the current user has a pending invitation.
    func fetchPendingInvitations(from calendars: [EKCalendar]?) -> [EKEvent] {
        let start = Date()
        guard let end = Calendar.current.date(byAdding: .month, value: 3, to: start) else { return [] }
        let events = fetchEvents(from: calendars, start: start, end: end)
        return events.filter { event in
            guard let attendees = event.attendees else { return false }
            return attendees.contains { $0.isCurrentUser && $0.participantStatus == .pending }
        }
        .sorted { $0.startDate < $1.startDate }
    }

    func createTimeBlock(for task: ProcrastiNautTask, on calendar: EKCalendar) throws -> EKEvent {
        guard let startTime = task.suggestedStartTime,
              let endTime = task.suggestedEndTime else {
            throw ProcrastiNautError.eventCreationFailed
        }

        let event = EKEvent(eventStore: eventStore)

        // Title with block indicator for split tasks
        if let blockIndex = task.blockIndex, let total = task.totalBlocks {
            event.title = "\u{1F4CB} \(task.reminderTitle) (\(blockIndex)/\(total))"
        } else {
            event.title = "\u{1F4CB} \(task.reminderTitle)"
        }

        event.startDate = startTime
        event.endDate = endTime
        event.calendar = calendar
        event.timeZone = .current

        // Carry reminder context into event
        var notes = "Created by ProcrastiNaut\nReminder: \(task.reminderIdentifier)"
        if let reminderNotes = task.reminderNotes, !reminderNotes.isEmpty {
            notes += "\n\n--- Original Notes ---\n\(reminderNotes)"
        }
        event.notes = notes

        if let url = task.reminderURL {
            event.url = url
        }

        try eventStore.save(event, span: .thisEvent)
        return event
    }

    /// Create a general calendar event (not a ProcrastiNaut time block)
    func createCalendarEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendar: EKCalendar,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        recurrenceRule: EKRecurrenceRule? = nil
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.timeZone = .current
        if let location { event.location = location }
        if let notes { event.notes = notes }
        if let url { event.url = url }
        if let recurrenceRule { event.recurrenceRules = [recurrenceRule] }
        try eventStore.save(event, span: recurrenceRule != nil ? .futureEvents : .thisEvent)
        return event
    }

    /// Find a specific event occurrence by identifier and date
    func findEventOccurrence(identifier: String, on date: Date) -> EKEvent? {
        // Search a window around the occurrence date to find the exact instance
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        let predicate = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let dayEvents = eventStore.events(matching: predicate)

        // Match by calendarItemIdentifier and start date
        return dayEvents.first { event in
            event.calendarItemIdentifier == identifier && event.startDate == date
        }
    }

    func deleteEvent(identifier: String, occurrenceDate: Date, span: EKSpan = .thisEvent) throws {
        // Find the specific occurrence for recurring events
        guard let event = findEventOccurrence(identifier: identifier, on: occurrenceDate)
                ?? eventStore.calendarItem(withIdentifier: identifier) as? EKEvent
                ?? eventStore.event(withIdentifier: identifier) else {
            throw ProcrastiNautError.eventNotFound
        }
        if !event.calendar.allowsContentModifications {
            throw ProcrastiNautError.calendarReadOnly(name: event.calendar.title)
        }
        try eventStore.remove(event, span: span, commit: true)
    }

    func updateEvent(identifier: String, occurrenceDate: Date, title: String?, startDate: Date?, endDate: Date?, span: EKSpan = .thisEvent) throws {
        // Find the specific occurrence for recurring events
        guard let event = findEventOccurrence(identifier: identifier, on: occurrenceDate)
                ?? eventStore.calendarItem(withIdentifier: identifier) as? EKEvent
                ?? eventStore.event(withIdentifier: identifier) else {
            throw ProcrastiNautError.eventNotFound
        }
        if !event.calendar.allowsContentModifications {
            throw ProcrastiNautError.calendarReadOnly(name: event.calendar.title)
        }
        if let title { event.title = title }
        if let startDate { event.startDate = startDate }
        if let endDate { event.endDate = endDate }
        try eventStore.save(event, span: span, commit: true)
    }

    func event(withIdentifier id: String) -> EKEvent? {
        eventStore.event(withIdentifier: id)
    }

    /// Checks for conflicts in the given time range across monitored calendars
    func checkForConflicts(start: Date, end: Date, calendars: [EKCalendar]?) -> [EKEvent] {
        let events = fetchEvents(from: calendars, start: start, end: end)
        // Filter out ProcrastiNaut-created events
        return events.filter { event in
            !(event.notes?.contains("Created by ProcrastiNaut") ?? false)
        }
    }

    /// Creates a time block with conflict verification
    func createVerifiedTimeBlock(for task: ProcrastiNautTask, on calendar: EKCalendar, monitoredCalendars: [EKCalendar]?) throws -> EKEvent {
        guard let startTime = task.suggestedStartTime,
              let endTime = task.suggestedEndTime else {
            throw ProcrastiNautError.eventCreationFailed
        }

        // Re-verify no conflicts
        let conflicts = checkForConflicts(start: startTime, end: endTime, calendars: monitoredCalendars)
        if !conflicts.isEmpty {
            let conflictNames = conflicts.map(\.title).compactMap { $0 }.joined(separator: ", ")
            throw ProcrastiNautError.conflictDetected(details: conflictNames)
        }

        return try createTimeBlock(for: task, on: calendar)
    }

    // MARK: - Change Observation

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { _ in
            handler()
        }
    }
}
