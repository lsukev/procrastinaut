import Foundation
import EventKit

enum QuickChatResult: Sendable {
    case success(String)
    case error(String)
    case answer(String)
}

@MainActor
@Observable
final class QuickChatViewModel {
    var inputText: String = ""
    var parsedPreview: NaturalLanguageParser.ParsedTask?
    var useAIMode: Bool
    var isProcessing: Bool = false
    var result: QuickChatResult?
    var speechService = SpeechRecognitionService()
    var onDismiss: (() -> Void)?

    // Calendar selection
    var availableCalendars: [EKCalendar] = []
    var selectedCalendarID: String = ""
    var showCalendarPicker: Bool = false

    // Reminder list selection
    var availableReminderLists: [EKCalendar] = []
    var selectedReminderListID: String = ""
    var showReminderListPicker: Bool = false

    private let chatBarService = ChatBarService()
    private let eventKitManager = EventKitManager.shared
    private let settings = UserSettings.shared

    var isAIAvailable: Bool {
        !settings.claudeAPIKey.isEmpty && settings.aiEnabled
    }

    init() {
        useAIMode = UserSettings.shared.quickChatDefaultAIMode
        selectedCalendarID = UserSettings.shared.blockingCalendarID
        loadCalendars()
        loadReminderLists()
    }

    // MARK: - Calendar Loading

    func loadCalendars() {
        availableCalendars = eventKitManager.getAvailableCalendars()
        // If selected ID is empty or invalid, default to first available or ProcrastiNaut
        if selectedCalendarID.isEmpty ||
            !availableCalendars.contains(where: { $0.calendarIdentifier == selectedCalendarID }) {
            if let procrastinaut = eventKitManager.getOrCreateProcrastiNautCalendar() {
                selectedCalendarID = procrastinaut.calendarIdentifier
            } else if let first = availableCalendars.first {
                selectedCalendarID = first.calendarIdentifier
            }
        }
    }

    // MARK: - Reminder List Loading

    func loadReminderLists() {
        availableReminderLists = eventKitManager.getAvailableReminderLists()

        // Default to user's setting, then first available
        let settingID = settings.defaultReminderListID
        if !settingID.isEmpty,
           availableReminderLists.contains(where: { $0.calendarIdentifier == settingID }) {
            selectedReminderListID = settingID
        } else if let first = availableReminderLists.first {
            selectedReminderListID = first.calendarIdentifier
        }
    }

    // MARK: - Live Preview

    func updatePreview() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else {
            parsedPreview = nil
            showCalendarPicker = false
            showReminderListPicker = false
            return
        }
        let parsed = NaturalLanguageParser.parse(inputText)
        parsedPreview = parsed

        let isEvent = looksLikeEvent(parsed)
        showCalendarPicker = isEvent
        showReminderListPicker = !isEvent

        // If user typed #ListName, auto-select that list
        if let listName = parsed.listName,
           let match = availableReminderLists.first(where: {
               $0.title.localizedCaseInsensitiveCompare(listName) == .orderedSame
           }) {
            selectedReminderListID = match.calendarIdentifier
        }
    }

    // MARK: - Submit

    func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        result = nil

        Task {
            if useAIMode && isAIAvailable {
                await submitWithAI(trimmed)
            } else {
                await submitWithLocalNLP(trimmed)
            }
        }
    }

    // MARK: - Local NLP Submit

    private func submitWithLocalNLP(_ input: String) async {
        let parsed = NaturalLanguageParser.parse(input)

        if looksLikeEvent(parsed) {
            await createEvent(from: parsed)
        } else {
            await createReminder(from: parsed)
        }
    }

    /// Determines if parsed input should create a calendar event rather than a reminder.
    /// Broadened heuristic: specific time + meeting keywords, OR explicit "event:" prefix,
    /// OR keywords like "event", "calendar", "schedule", "block".
    private func looksLikeEvent(_ parsed: NaturalLanguageParser.ParsedTask) -> Bool {
        let lower = inputText.lowercased().trimmingCharacters(in: .whitespaces)

        // Explicit prefix: "event: ..." or "cal: ..."
        if lower.hasPrefix("event:") || lower.hasPrefix("event :")
            || lower.hasPrefix("cal:") || lower.hasPrefix("cal :") {
            return true
        }

        let meetingKeywords = [
            "meeting", "lunch", "dinner", "breakfast", "coffee",
            "call", "appointment", "interview", "standup", "sync",
            "review", "demo", "presentation", "class", "session",
            "workshop", "webinar", "conference", "party", "hangout",
            "event", "calendar", "schedule", "block", "reserve",
            "gym", "workout", "yoga", "doctor", "dentist", "haircut",
        ]
        let titleLower = parsed.title.lowercased()
        let hasKeyword = meetingKeywords.contains { titleLower.contains($0) }

        // Event if: has specific time + keyword, OR has specific time + date
        if parsed.specificTime != nil && hasKeyword {
            return true
        }
        if parsed.specificTime != nil && parsed.targetDate != nil {
            return true
        }

        return false
    }

    private func createReminder(from parsed: NaturalLanguageParser.ParsedTask) async {
        let targetList: EKCalendar
        if let listName = parsed.listName,
           let found = eventKitManager.reminderList(withTitle: listName) {
            targetList = found
        } else if !selectedReminderListID.isEmpty,
                  let selected = availableReminderLists.first(where: { $0.calendarIdentifier == selectedReminderListID }) {
            targetList = selected
        } else {
            guard let first = eventKitManager.getAvailableReminderLists().first else {
                result = .error("No reminder lists available")
                isProcessing = false
                return
            }
            targetList = first
        }

        let notes = NoteMetadataBuilder.buildNotes(
            durationMinutes: parsed.duration,
            location: nil,
            userNotes: parsed.notes,
            tags: []
        )

        do {
            _ = try eventKitManager.createReminder(
                title: parsed.title,
                list: targetList,
                dueDate: parsed.targetDate,
                dueTime: parsed.specificTime,
                priority: parsed.priority ?? .none,
                notes: notes.isEmpty ? nil : notes
            )

            result = .success("Reminder created: \(parsed.title)")
            isProcessing = false
            autoDismissAfterSuccess()
        } catch {
            result = .error("Failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    private func createEvent(from parsed: NaturalLanguageParser.ParsedTask) async {
        guard let calendar = resolveSelectedCalendar() else {
            result = .error("Could not access calendar")
            isProcessing = false
            return
        }

        // Strip "event:" or "cal:" prefix from title if present
        var title = parsed.title
        for prefix in ["event:", "cal:"] {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        if title.isEmpty { title = parsed.title }

        let targetDate = parsed.targetDate ?? Date()
        let startDate: Date

        if let time = parsed.specificTime, let hour = time.hour {
            let minute = time.minute ?? 0
            startDate = Calendar.current.date(
                bySettingHour: hour, minute: minute, second: 0, of: targetDate
            ) ?? targetDate
        } else {
            startDate = targetDate
        }

        let durationSeconds = TimeInterval(parsed.duration * 60)
        let endDate = startDate.addingTimeInterval(durationSeconds)

        do {
            _ = try eventKitManager.createCalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                location: nil,
                notes: parsed.notes
            )

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            result = .success("Event created: \(title) at \(timeFormatter.string(from: startDate)) on \(calendar.title)")
            isProcessing = false
            autoDismissAfterSuccess()
        } catch {
            result = .error("Failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    /// Resolve the selected calendar ID to an EKCalendar, falling back to ProcrastiNaut.
    private func resolveSelectedCalendar() -> EKCalendar? {
        if !selectedCalendarID.isEmpty,
           let cal = eventKitManager.calendar(withIdentifier: selectedCalendarID) {
            return cal
        }
        return eventKitManager.getOrCreateProcrastiNautCalendar()
    }

    // MARK: - AI Submit

    private func submitWithAI(_ input: String) async {
        // Fetch calendar context so Claude can answer questions about schedule
        let calendarContext = await chatBarService.buildCalendarContext()

        guard let action = await chatBarService.processInput(input, calendarContext: calendarContext) else {
            result = .error(chatBarService.error ?? "AI processing failed")
            isProcessing = false
            return
        }

        switch action {
        case let .answer(text):
            // Display answer — do NOT auto-dismiss
            result = .answer(text)
            isProcessing = false

        case let .createEvent(title, startDate, endDate, location, notes):
            // For events, override the calendar with the user's selection
            guard let calendar = resolveSelectedCalendar() else {
                result = .error("Could not access calendar")
                isProcessing = false
                return
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
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                result = .success("Event created: \(title) at \(timeFormatter.string(from: startDate)) on \(calendar.title)")
                autoDismissAfterSuccess()
            } catch {
                result = .error("Failed: \(error.localizedDescription)")
            }
            isProcessing = false

        default:
            // Reminders — use ChatBarService's default handling
            let actionResult = await chatBarService.executeAction(action)
            if actionResult.success {
                result = .success(actionResult.message)
                autoDismissAfterSuccess()
            } else {
                result = .error(actionResult.message)
            }
            isProcessing = false
        }
    }

    // MARK: - Voice Input

    func toggleVoiceInput() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let granted = await speechService.requestPermission()
                guard granted else { return }
                do {
                    try speechService.startRecording()
                } catch {
                    result = .error("Mic error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Sync transcribed speech text into inputText (called from view onChange).
    func syncSpeechText() {
        if speechService.isRecording && !speechService.transcribedText.isEmpty {
            inputText = speechService.transcribedText
            updatePreview()
        }
    }

    // MARK: - Reset

    func reset() {
        inputText = ""
        parsedPreview = nil
        result = nil
        isProcessing = false
        showCalendarPicker = false
        showReminderListPicker = false
        useAIMode = settings.quickChatDefaultAIMode
        selectedCalendarID = settings.blockingCalendarID
        loadCalendars()
        loadReminderLists()
        if speechService.isRecording {
            speechService.stopRecording()
        }
    }

    // MARK: - Auto Dismiss

    private func autoDismissAfterSuccess() {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            onDismiss?()
        }
    }
}
