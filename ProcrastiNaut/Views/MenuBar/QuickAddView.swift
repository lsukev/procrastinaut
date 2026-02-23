import SwiftUI
import EventKit

struct QuickAddView: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var isFocused: Bool

    let onTaskCreated: (ProcrastiNautTask) -> Void

    private var parsed: NaturalLanguageParser.ParsedTask {
        NaturalLanguageParser.parse(inputText)
    }

    private var hasInput: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 4) {
            // Input field
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)

                TextField("Add task: \"Call dentist tomorrow 2pm 30m !high\"", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isFocused)
                    .onSubmit { handleSubmit() }
                    .onChange(of: inputText) { _, _ in
                        errorMessage = nil
                        successMessage = nil
                    }

                if isProcessing {
                    ProgressView()
                        .controlSize(.mini)
                } else if hasInput {
                    Button(action: handleSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 0.5)
            )

            // Live metadata preview
            if hasInput {
                metadataPreview
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeOut(duration: 0.15), value: inputText)
            }

            // Status messages
            if let errorMessage {
                statusBanner(icon: "exclamationmark.circle.fill", text: errorMessage, color: .red)
            }

            if let successMessage {
                statusBanner(icon: "checkmark.circle.fill", text: successMessage, color: .green)
            }
        }
    }

    // MARK: - Metadata Preview

    private var metadataPreview: some View {
        HStack(spacing: 6) {
            // Duration
            metadataPill(icon: "clock", text: formatDuration(parsed.duration), color: .blue)

            // Priority
            if let priority = parsed.priority {
                metadataPill(icon: "flag.fill", text: priorityLabel(priority), color: priorityColor(priority))
            }

            // Energy
            if let energy = parsed.energy {
                metadataPill(icon: energy.symbol, text: energy.displayName, color: .orange)
            }

            // Date
            if let date = parsed.targetDate {
                metadataPill(icon: "calendar", text: shortDate(date), color: .purple)
            }

            // Time
            if let time = parsed.specificTime, let hour = time.hour {
                let minute = time.minute ?? 0
                let ampm = hour >= 12 ? "PM" : "AM"
                let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                let timeStr = minute > 0
                    ? "\(displayHour):\(String(format: "%02d", minute)) \(ampm)"
                    : "\(displayHour) \(ampm)"
                metadataPill(icon: "clock.fill", text: timeStr, color: .indigo)
            } else if let tod = parsed.timeOfDay {
                metadataPill(
                    icon: tod == .morning ? "sunrise" : (tod == .afternoon ? "sun.max" : "moon"),
                    text: tod.rawValue.capitalized,
                    color: .indigo
                )
            }

            // List
            if let list = parsed.listName {
                metadataPill(icon: "list.bullet", text: list, color: .green)
            }

            // URL
            if parsed.url != nil {
                metadataPill(icon: "link", text: "Link", color: .cyan)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func metadataPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func statusBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Submit

    func focus() {
        isFocused = true
    }

    private func handleSubmit() {
        guard hasInput else { return }

        isProcessing = true
        errorMessage = nil
        successMessage = nil

        let result = parsed

        Task {
            let outcome = await createReminderAndSchedule(parsed: result)
            switch outcome {
            case .success(let task):
                onTaskCreated(task)
                successMessage = "Added \"\(result.title)\""
                inputText = ""
                // Auto-clear success after 2s
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    successMessage = nil
                }
            case .failure(let error):
                errorMessage = error
            }
            isProcessing = false
        }
    }

    private enum CreateOutcome {
        case success(ProcrastiNautTask)
        case failure(String)
    }

    private func createReminderAndSchedule(parsed: NaturalLanguageParser.ParsedTask) async -> CreateOutcome {
        let ekManager = EventKitManager.shared

        // Determine target reminder list
        let targetList: EKCalendar
        if let listName = parsed.listName, let found = ekManager.reminderList(withTitle: listName) {
            targetList = found
        } else {
            let lists = ekManager.getAvailableReminderLists()
            guard let first = lists.first else {
                return .failure("No reminder lists available.")
            }
            targetList = first
        }

        // Build notes with duration tag
        var notes = parsed.durationTag
        if let extraNotes = parsed.notes, !extraNotes.isEmpty {
            notes += "\n\(extraNotes)"
        }

        // Create the reminder in Apple Reminders
        let reminder: EKReminder
        do {
            reminder = try ekManager.createReminder(
                title: parsed.title,
                list: targetList,
                dueDate: parsed.targetDate,
                dueTime: parsed.specificTime,
                priority: parsed.priority ?? .none,
                notes: notes,
                url: parsed.url
            )
        } catch {
            return .failure("Failed to create reminder: \(error.localizedDescription)")
        }

        // Also schedule it as a calendar event in the next available slot
        let today = Date()
        let events = ekManager.fetchEvents(from: nil, start: today.startOfDay, end: today.endOfDay)
        let engine = SuggestionEngine()
        let slots = engine.findAvailableSlots(date: today, events: events, fromTime: Date())
        let durationSeconds = TimeInterval(parsed.duration * 60)

        guard let slot = slots.first(where: { $0.duration >= durationSeconds }) else {
            // Reminder created but no slot today — still a success
            let task = ProcrastiNautTask(
                id: UUID(),
                reminderIdentifier: reminder.calendarItemIdentifier,
                reminderTitle: parsed.title,
                reminderListName: targetList.title,
                priority: parsed.priority ?? .medium,
                dueDate: parsed.targetDate,
                reminderNotes: notes,
                reminderURL: parsed.url,
                energyRequirement: parsed.energy ?? .medium,
                suggestedStartTime: nil,
                suggestedEndTime: nil,
                suggestedDuration: durationSeconds,
                status: .pending,
                createdAt: Date()
            )
            return .success(task)
        }

        let task = ProcrastiNautTask(
            id: UUID(),
            reminderIdentifier: reminder.calendarItemIdentifier,
            reminderTitle: parsed.title,
            reminderListName: targetList.title,
            priority: parsed.priority ?? .medium,
            dueDate: parsed.targetDate,
            reminderNotes: notes,
            reminderURL: parsed.url,
            energyRequirement: parsed.energy ?? .medium,
            suggestedStartTime: slot.start,
            suggestedEndTime: slot.start.addingTimeInterval(durationSeconds),
            suggestedDuration: durationSeconds,
            status: .approved,
            createdAt: Date()
        )

        guard let calendar = ekManager.getOrCreateProcrastiNautCalendar() else {
            return .success(task)
        }

        do {
            _ = try ekManager.createTimeBlock(for: task, on: calendar)
        } catch {
            // Reminder was created, calendar event failed — still partial success
        }

        return .success(task)
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func priorityLabel(_ p: TaskPriority) -> String {
        switch p {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .none: "None"
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        case .none: .gray
        }
    }

    private func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }
}
