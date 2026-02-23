import AppIntents

// MARK: - Scan Now Intent

struct ScanNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Reminders"
    static let description: IntentDescription = "Scans your reminders and generates time block suggestions"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDelegate.shared?.menuBarController?.showPopover()
        return .result()
    }
}

// MARK: - Quick Add Intent

struct QuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Task"
    static let description: IntentDescription = "Add a quick task to ProcrastiNaut"

    @Parameter(title: "Task Name")
    var taskName: String

    @Parameter(title: "Duration (minutes)", default: 30)
    var duration: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = EventKitManager.shared
        let today = Date()

        guard let calendar = manager.getOrCreateProcrastiNautCalendar() else {
            return .result(value: "Could not access calendar")
        }

        let events = manager.fetchEvents(from: nil, start: today, end: today.endOfDay)
        let engine = SuggestionEngine()
        let slots = engine.findAvailableSlots(date: today, events: events, fromTime: Date())
        let durationSeconds = TimeInterval(duration * 60)

        guard let slot = slots.first(where: { $0.duration >= durationSeconds }) else {
            return .result(value: "No available \(duration)-minute slot today")
        }

        let task = ProcrastiNautTask(
            id: UUID(),
            reminderIdentifier: "",
            reminderTitle: taskName,
            reminderListName: "",
            priority: .medium,
            dueDate: today,
            reminderNotes: nil,
            reminderURL: nil,
            energyRequirement: .medium,
            suggestedStartTime: slot.start,
            suggestedEndTime: slot.start.addingTimeInterval(durationSeconds),
            suggestedDuration: durationSeconds,
            status: .approved,
            createdAt: Date()
        )

        do {
            _ = try manager.createTimeBlock(for: task, on: calendar)
            return .result(value: "Created '\(taskName)' at \(timeString(slot.start))")
        } catch {
            return .result(value: "Failed: \(error.localizedDescription)")
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Shortcuts Provider

struct ProcrastiNautShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanNowIntent(),
            phrases: [
                "Scan reminders in \(.applicationName)",
                "Plan my day with \(.applicationName)"
            ],
            shortTitle: "Scan Reminders",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: QuickAddIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Quick add to \(.applicationName)"
            ],
            shortTitle: "Quick Add Task",
            systemImageName: "plus.circle"
        )
    }
}
