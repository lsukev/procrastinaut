import SwiftUI

struct CreateReminderView: View {
    @Bindable var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var title = ""
    @State private var selectedListName = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasDueTime = false
    @State private var dueTime = Date()
    @State private var priority: TaskPriority = .none
    @State private var durationMinutes: Int = 30
    @State private var notes = ""
    @State private var tagsText = ""
    @State private var location = ""
    @State private var urlText = ""
    @State private var isCreating = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Reminder")
                        .font(.system(size: 15, weight: .semibold))
                    if let event = viewModel.createReminderFromEvent {
                        Text(event.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Reminder title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .focused($titleFocused)
                    }

                    // List picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("List")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("List", selection: $selectedListName) {
                            ForEach(viewModel.allReminderLists) { list in
                                Text(list.name).tag(list.name)
                            }
                        }
                        .labelsHidden()
                    }

                    // Due Date
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $hasDueDate) {
                            Text("Due Date")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        if hasDueDate {
                            DatePicker(
                                "Date",
                                selection: $dueDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()

                            Toggle(isOn: $hasDueTime) {
                                Text("Due Time")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            if hasDueTime {
                                DatePicker(
                                    "Time",
                                    selection: $dueTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Priority", selection: $priority) {
                            Text("None").tag(TaskPriority.none)
                            Text("Low").tag(TaskPriority.low)
                            Text("Medium").tag(TaskPriority.medium)
                            Text("High").tag(TaskPriority.high)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Stepper(
                                "\(durationText)",
                                value: $durationMinutes,
                                in: 5...480,
                                step: 5
                            )
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                            )
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("#errand #home #urgent", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        if !parsedTags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(parsedTags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField("Add location", text: $location)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }

                    // URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField("https://", text: $urlText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button(isFromEvent ? "Done" : "Cancel") {
                    viewModel.createReminderFromEvent = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button(isFromEvent ? "Create & Next" : "Create") {
                    createReminder()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360, height: 520)
        .onAppear {
            selectedListName = viewModel.defaultListName
            durationMinutes = UserSettings.shared.defaultTaskDuration
            titleFocused = true

            // Pre-fill from event context
            if let event = viewModel.createReminderFromEvent {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                notes = "From: \(event.title) (\(formatter.string(from: event.startDate)))"
                hasDueDate = true
                dueDate = event.startDate
                if let loc = event.location, !loc.isEmpty {
                    location = loc
                }
            }
        }
        .onDisappear {
            viewModel.createReminderFromEvent = nil
        }
    }

    // MARK: - Helpers

    private var isFromEvent: Bool {
        viewModel.createReminderFromEvent != nil
    }

    private var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private var parsedTags: [String] {
        tagsText
            .components(separatedBy: .whitespaces)
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private func createReminder() {
        isCreating = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let finalDueDate = hasDueDate ? dueDate : nil
        var finalDueTime: DateComponents?
        if hasDueDate && hasDueTime {
            finalDueTime = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
        }
        let finalURL = URL(string: urlText.trimmingCharacters(in: .whitespaces))
        let finalLocation = location.trimmingCharacters(in: .whitespaces)
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = parsedTags

        Task {
            await viewModel.createReminder(
                title: trimmedTitle,
                listName: selectedListName,
                dueDate: finalDueDate,
                dueTime: finalDueTime,
                priority: priority,
                durationMinutes: durationMinutes,
                notes: finalNotes.isEmpty ? nil : finalNotes,
                tags: tags,
                location: finalLocation.isEmpty ? nil : finalLocation,
                url: finalURL,
                fromEventID: viewModel.createReminderFromEvent?.id
            )
            isCreating = false

            // When creating from an event, reset title for the next reminder
            if isFromEvent {
                title = ""
                titleFocused = true
            }
        }
    }
}
