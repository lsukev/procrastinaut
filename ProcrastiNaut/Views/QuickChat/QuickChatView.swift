import SwiftUI
import EventKit

struct QuickChatView: View {
    @Bindable var viewModel: QuickChatViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main input area
            VStack(spacing: 8) {
                inputRow
                if viewModel.parsedPreview != nil {
                    metadataPreview
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if viewModel.showCalendarPicker {
                    calendarPickerRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if viewModel.showReminderListPicker {
                    reminderListPickerRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let result = viewModel.result {
                    resultBanner(result)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(16)
        }
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            // Delay focus until the panel is fully key — immediate assignment
            // is ignored because the window isn't ready yet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: viewModel.inputText) {
            viewModel.updatePreview()
        }
        .onChange(of: viewModel.speechService.transcribedText) {
            viewModel.syncSpeechText()
        }
        .onKeyPress(.escape) {
            viewModel.onDismiss?()
            return .handled
        }
        .onKeyPress(.tab) {
            if viewModel.isAIAvailable {
                viewModel.useAIMode.toggle()
            }
            return .handled
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.parsedPreview != nil)
        .animation(.easeOut(duration: 0.15), value: viewModel.showCalendarPicker)
        .animation(.easeOut(duration: 0.15), value: viewModel.showReminderListPicker)
        .animation(.easeOut(duration: 0.2), value: viewModel.result != nil)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "Add a reminder or event\u{2026}",
                text: $viewModel.inputText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16))
            .focused($isTextFieldFocused)
            .onSubmit {
                viewModel.submit()
            }

            // Mode toggle pill
            modeToggle

            // Mic button
            micButton

            // Submit button
            if !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                } else {
                    Button(action: { viewModel.submit() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        Button {
            if viewModel.isAIAvailable {
                viewModel.useAIMode.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel.useAIMode ? "sparkles" : "bolt.fill")
                    .font(.system(size: 9))
                Text(viewModel.useAIMode ? "AI" : "Instant")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(viewModel.useAIMode ? .purple : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                (viewModel.useAIMode ? Color.purple : Color.gray).opacity(0.12),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .opacity(viewModel.isAIAvailable ? 1 : 0.4)
        .help(viewModel.isAIAvailable
              ? (viewModel.useAIMode ? "Using Claude AI for parsing" : "Using instant local parsing")
              : "Add Claude API key in Settings to enable AI mode")
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button(action: { viewModel.toggleVoiceInput() }) {
            ZStack {
                if viewModel.speechService.isRecording {
                    Circle()
                        .fill(.red.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .scaleEffect(viewModel.speechService.isRecording ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: viewModel.speechService.isRecording
                        )
                }

                Image(systemName: viewModel.speechService.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.speechService.isRecording ? .red : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(viewModel.speechService.isRecording ? "Stop recording" : "Start voice input")
    }

    // MARK: - Metadata Preview

    private var metadataPreview: some View {
        HStack(spacing: 6) {
            if let parsed = viewModel.parsedPreview {
                metadataPill(icon: "clock", text: formatDuration(parsed.duration), color: .blue)

                if let priority = parsed.priority {
                    metadataPill(icon: "flag.fill", text: priorityLabel(priority), color: priorityColor(priority))
                }

                if let energy = parsed.energy {
                    metadataPill(icon: energy.symbol, text: energy.displayName, color: .orange)
                }

                if let date = parsed.targetDate {
                    metadataPill(icon: "calendar", text: shortDate(date), color: .purple)
                }

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

                if let list = parsed.listName {
                    metadataPill(icon: "list.bullet", text: list, color: .green)
                }

                if parsed.url != nil {
                    metadataPill(icon: "link", text: "Link", color: .cyan)
                }
            }

            Spacer()
        }
    }

    private func metadataPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
    }

    // MARK: - Calendar Picker

    /// Calendars grouped by their source account (iCloud, Google, etc.)
    private var calendarsByAccount: [(account: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: viewModel.availableCalendars) { $0.source.title }
        return grouped
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (account: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
    }

    private var calendarPickerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text("Event on:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedCalendarID) {
                ForEach(calendarsByAccount, id: \.account) { group in
                    Section(group.account) {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            Label {
                                Text(calendar.title)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(Color(cgColor: calendar.cgColor))
                            }
                            .tag(calendar.calendarIdentifier)
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)

            Spacer()
        }
    }

    // MARK: - Reminder List Picker

    /// Reminder lists grouped by their source account
    private var reminderListsByAccount: [(account: String, lists: [EKCalendar])] {
        let grouped = Dictionary(grouping: viewModel.availableReminderLists) { $0.source.title }
        return grouped
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (account: $0.key, lists: $0.value.sorted { $0.title < $1.title }) }
    }

    private var reminderListPickerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text("List:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedReminderListID) {
                ForEach(reminderListsByAccount, id: \.account) { group in
                    Section(group.account) {
                        ForEach(group.lists, id: \.calendarIdentifier) { list in
                            Label {
                                Text(list.title)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(Color(cgColor: list.cgColor))
                            }
                            .tag(list.calendarIdentifier)
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)

            Spacer()
        }
    }

    // MARK: - Result Banner

    @ViewBuilder
    private func resultBanner(_ result: QuickChatResult) -> some View {
        switch result {
        case .success(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .foregroundStyle(.green)
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)

        case .error(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)

        case .answer(let text):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(.purple)
                    Text("AI Answer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.purple)
                }

                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Formatting

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
