import Foundation
import EventKit

struct ChatBarResult: Sendable {
    let success: Bool
    let message: String
}

enum ChatBarAction {
    case createReminder(
        title: String,
        dueDate: Date?,
        dueTime: DateComponents?,
        duration: Int,
        priority: TaskPriority,
        listName: String?,
        notes: String?
    )
    case createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?
    )
    case answer(text: String)
}

@MainActor
@Observable
final class ChatBarService {
    var isProcessing: Bool = false
    var lastResult: ChatBarResult?
    var error: String?

    private let apiClient = ClaudeAPIClient.shared
    private let settings = UserSettings.shared
    private let eventKitManager = EventKitManager.shared

    // MARK: - Process Input

    func processInput(_ input: String, calendarContext: String? = nil) async -> ChatBarAction? {
        let apiKey = settings.claudeAPIKey
        guard !apiKey.isEmpty else {
            error = "Add your Claude API key in Settings → AI to use the chat bar."
            return nil
        }

        isProcessing = true
        error = nil
        lastResult = nil

        let systemPrompt = buildSystemPrompt()
        var userPrompt = input
        if let calendarContext, !calendarContext.isEmpty {
            userPrompt += "\n\nHere is my current calendar and reminder data:\n\(calendarContext)"
        }

        do {
            let response = try await apiClient.sendMessage(
                system: systemPrompt,
                userMessage: userPrompt,
                model: settings.claudeModel,
                apiKey: apiKey
            )

            let action = try parseResponse(response)
            isProcessing = false
            return action
        } catch {
            self.error = error.localizedDescription
            isProcessing = false
            return nil
        }
    }

    // MARK: - Execute Action

    func executeAction(_ action: ChatBarAction) async -> ChatBarResult {
        switch action {
        case let .createReminder(title, dueDate, dueTime, duration, priority, listName, notes):
            return await executeCreateReminder(
                title: title, dueDate: dueDate, dueTime: dueTime,
                duration: duration, priority: priority,
                listName: listName, notes: notes
            )

        case let .createEvent(title, startDate, endDate, location, notes):
            return executeCreateEvent(
                title: title, startDate: startDate, endDate: endDate,
                location: location, notes: notes
            )

        case let .answer(text):
            return ChatBarResult(success: true, message: text)
        }
    }

    // MARK: - Reminder Creation

    private func executeCreateReminder(
        title: String,
        dueDate: Date?,
        dueTime: DateComponents?,
        duration: Int,
        priority: TaskPriority,
        listName: String?,
        notes: String?
    ) async -> ChatBarResult {
        let targetList: EKCalendar?
        if let listName {
            targetList = eventKitManager.reminderList(withTitle: listName)
                ?? eventKitManager.getAvailableReminderLists().first
        } else {
            targetList = eventKitManager.getAvailableReminderLists().first
        }

        guard let list = targetList else {
            return ChatBarResult(success: false, message: "No reminder lists available")
        }

        let composedNotes = NoteMetadataBuilder.buildNotes(
            durationMinutes: duration,
            location: nil,
            userNotes: notes,
            tags: []
        )

        do {
            _ = try eventKitManager.createReminder(
                title: title,
                list: list,
                dueDate: dueDate,
                dueTime: dueTime,
                priority: priority,
                notes: composedNotes.isEmpty ? nil : composedNotes
            )

            let dateStr = formatConfirmationDate(dueDate, time: dueTime)
            return ChatBarResult(
                success: true,
                message: "Reminder created: \(title)\(dateStr)"
            )
        } catch {
            return ChatBarResult(success: false, message: "Failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Creation

    private func executeCreateEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?
    ) -> ChatBarResult {
        guard let calendar = getTargetCalendar() else {
            return ChatBarResult(success: false, message: "Could not access calendar")
        }

        do {
            _ = try eventKitManager.createCalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                location: location,
                notes: notes
            )

            let dateStr = formatEventConfirmation(start: startDate, end: endDate)
            return ChatBarResult(
                success: true,
                message: "Event created: \(title) — \(dateStr)"
            )
        } catch {
            return ChatBarResult(success: false, message: "Failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Calendar Context

    /// Fetch 14 days of calendar events and open reminders, formatted as text for Claude.
    func buildCalendarContext() async -> String {
        let now = Date()
        let cal = Calendar.current
        let startDate = cal.startOfDay(for: now)
        guard let endDate = cal.date(byAdding: .day, value: 14, to: startDate) else { return "" }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE"

        // Fetch events from viewable + monitored calendars
        let allCalIDs = Set(settings.viewableCalendarIDs).union(settings.monitoredCalendarIDs)
        let calendars: [EKCalendar]? = allCalIDs.isEmpty
            ? nil
            : allCalIDs.compactMap { eventKitManager.calendar(withIdentifier: $0) }
        let events = eventKitManager.fetchEvents(from: calendars, start: startDate, end: endDate)

        // Fetch open reminders
        let reminderListIDs = settings.monitoredReminderListIDs
        let reminderLists: [EKCalendar]? = reminderListIDs.isEmpty
            ? nil
            : reminderListIDs.compactMap { eventKitManager.calendar(withIdentifier: $0) }
        let reminders = await eventKitManager.fetchOpenReminders(from: reminderLists)

        // Group events by day
        let timedEvents = events.filter { !$0.isAllDay }
        let allDayEvents = events.filter { $0.isAllDay }
        let grouped = Dictionary(grouping: timedEvents) { cal.startOfDay(for: $0.startDate) }
        let allDayGrouped = Dictionary(grouping: allDayEvents) { cal.startOfDay(for: $0.startDate) }

        var context = "CALENDAR EVENTS (next 14 days):\n"
        for dayOffset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let label = "\(dateFmt.string(from: day)) (\(dayFmt.string(from: day)))"
            let dayEvents = (grouped[day] ?? []).sorted { $0.startDate < $1.startDate }
            let dayAllDay = allDayGrouped[day] ?? []

            if dayEvents.isEmpty && dayAllDay.isEmpty {
                context += "\n\(label): No events\n"
            } else {
                context += "\n\(label):\n"
                for event in dayAllDay {
                    context += "  All day: \(event.title ?? "Untitled")\n"
                }
                for event in dayEvents {
                    context += "  \(timeFmt.string(from: event.startDate))-\(timeFmt.string(from: event.endDate)) \(event.title ?? "Untitled")\n"
                }
            }
        }

        // Format reminders
        context += "\nOPEN REMINDERS (\(reminders.count) items):\n"
        for reminder in reminders {
            var line = "- \(reminder.title ?? "Untitled")"
            if let list = reminder.calendar?.title {
                line += " | List: \(list)"
            }
            if reminder.priority > 0 {
                let pLabel: String = switch reminder.priority {
                case 1: "high"
                case 5: "medium"
                case 9: "low"
                default: "unknown"
                }
                line += " | Priority: \(pLabel)"
            }
            if let dueComps = reminder.dueDateComponents, let due = cal.date(from: dueComps) {
                line += " | Due: \(dateFmt.string(from: due))"
                if due < now { line += " (OVERDUE)" }
            }
            context += "\(line)\n"
        }

        return context
    }

    // MARK: - System Prompt

    private func buildSystemPrompt() -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        let reminderLists = eventKitManager.getAvailableReminderLists().map(\.title)
        let listsStr = reminderLists.joined(separator: ", ")

        let workStart = formatSecondsToTime(settings.workingHoursStart)
        let workEnd = formatSecondsToTime(settings.workingHoursEnd)

        return """
        You are a smart assistant for ProcrastiNaut, a macOS productivity app. \
        The user will type a natural-language request. They may want to create a calendar event, \
        create a reminder, or ask a question about their schedule, calendar, or reminders. \
        Your job is to determine what they want and respond accordingly.

        Current date/time: \(dateFormatter.string(from: now)) \(timeFormatter.string(from: now)) (\(dayFormatter.string(from: now)))
        Timezone: \(TimeZone.current.identifier)
        Working hours: \(workStart) – \(workEnd)
        Available reminder lists: \(listsStr)

        DECISION RULES:
        - If the request is a QUESTION about their schedule, calendar, reminders, or upcoming events → provide an ANSWER
        - Questions typically use words like "what", "how many", "do I have", "when is", "show me", "list", "any", "free", etc.
        - If the request involves a specific time slot, a meeting, lunch, appointment, or something that occupies a time block → create an EVENT
        - If the request is a task, to-do, something to remember, or uses words like "remind me", "don't forget", "need to" → create a REMINDER
        - When in doubt between event and reminder, default to REMINDER

        Respond ONLY with valid JSON, no markdown fences, no extra text.

        For EVENTS, use:
        {
          "action": "event",
          "title": "Clean, concise title for the item",
          "date": "YYYY-MM-DD",
          "startTime": "HH:mm" (24h format),
          "endTime": "HH:mm" (24h format; if not specified, default to 1 hour after startTime),
          "location": "location string or null",
          "priority": "none",
          "notes": "any extra context or null"
        }

        For REMINDERS, use:
        {
          "action": "reminder",
          "title": "Clean, concise title for the item",
          "date": "YYYY-MM-DD" (resolved from relative references like 'tomorrow', 'next Tuesday'),
          "duration": 30 (in minutes; default 30 if not specified),
          "location": "location string or null",
          "list": "reminder list name or null" (pick the best match from the available lists, or null for default),
          "priority": "high", "medium", "low", or "none" (default "none"),
          "notes": "any extra context or null"
        }

        For ANSWERS to questions, use:
        {
          "action": "answer",
          "text": "Your concise, friendly answer to the user's question."
        }

        IMPORTANT:
        - Always resolve relative dates. "tomorrow" = \(dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: now)!)), "next week" = one week from today, etc.
        - For events without a specified end time, default duration is 1 hour
        - For reminders without a specified duration, default is 30 minutes
        - The title should be clean and natural — don't include the date/time in the title
        - If a location is mentioned (e.g. "at Blue Hill"), extract it into the location field
        - For answers: reference specific event/reminder names and times. Format with newlines (\\n) for readability. For list-type answers, use bullet points like "• Event name — 9:00 AM – 10:00 AM". Group by day when spanning multiple days, with day headers like "Monday, Feb 23:". Keep answers concise but well-structured — never one long paragraph. When action is "answer", only "action" and "text" fields are required.
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String) throws -> ChatBarAction {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }

        guard let actionType = json["action"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        // Handle answer action (no title required)
        if actionType == "answer" {
            guard let text = json["text"] as? String else {
                throw ClaudeAPIError.invalidResponse
            }
            return .answer(text: text)
        }

        guard let title = json["title"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        let dateStr = json["date"] as? String
        let location = json["location"] as? String
        let notes = json["notes"] as? String

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if actionType == "event" {
            guard let dateStr,
                  let date = dateFormatter.date(from: dateStr),
                  let startTimeStr = json["startTime"] as? String,
                  let startDate = combineDateAndTime(date: date, timeString: startTimeStr) else {
                throw ClaudeAPIError.invalidResponse
            }

            let endDate: Date
            if let endTimeStr = json["endTime"] as? String,
               let parsedEnd = combineDateAndTime(date: date, timeString: endTimeStr) {
                endDate = parsedEnd
            } else {
                endDate = startDate.addingTimeInterval(3600) // default 1 hour
            }

            return .createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes
            )
        } else {
            // Reminder
            let dueDate = dateStr.flatMap { dateFormatter.date(from: $0) }
            var dueTime: DateComponents?
            if let startTimeStr = json["startTime"] as? String {
                dueTime = parseTimeComponents(startTimeStr)
            }

            let duration = json["duration"] as? Int ?? settings.defaultTaskDuration
            let priorityStr = json["priority"] as? String ?? "none"
            let priority = parsePriority(priorityStr)
            let listName = json["list"] as? String

            return .createReminder(
                title: title,
                dueDate: dueDate,
                dueTime: dueTime,
                duration: duration,
                priority: priority,
                listName: listName,
                notes: notes
            )
        }
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}") {
            return String(text[openBrace...closeBrace])
        }
        return text
    }

    private func combineDateAndTime(date: Date, timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    private func parseTimeComponents(_ timeString: String) -> DateComponents? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    private func parsePriority(_ str: String) -> TaskPriority {
        switch str.lowercased() {
        case "high": .high
        case "medium": .medium
        case "low": .low
        default: .none
        }
    }

    private func getTargetCalendar() -> EKCalendar? {
        if !settings.blockingCalendarID.isEmpty,
           let cal = eventKitManager.calendar(withIdentifier: settings.blockingCalendarID) {
            return cal
        }
        return eventKitManager.getOrCreateProcrastiNautCalendar()
    }

    private func formatSecondsToTime(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }

    private func formatConfirmationDate(_ date: Date?, time: DateComponents?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = time != nil ? .short : .none
        if let time, let hour = time.hour, let minute = time.minute {
            let composed = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
            return " — \(f.string(from: composed ?? date))"
        }
        return " — \(f.string(from: date))"
    }

    private func formatEventConfirmation(start: Date, end: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        if Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(dateFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
        } else {
            return "\(dateFormatter.string(from: start)) – \(dateFormatter.string(from: end))"
        }
    }
}
