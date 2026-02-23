import SwiftUI

struct ReminderDragCard: View {
    let reminder: ReminderItem
    @Bindable var viewModel: PlannerViewModel

    @State private var dueDatePickerDate = Date()
    @State private var showDueDatePicker = false

    var body: some View {
        HStack(spacing: 10) {
            // Priority color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // List name with color dot
                    HStack(spacing: 3) {
                        Circle()
                            .fill(listColor)
                            .frame(width: 6, height: 6)
                        Text(reminder.listName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    // Duration pill
                    Text(formatDuration(reminder.duration))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())

                    // Due date
                    if let due = reminder.dueDate {
                        Text(shortDueText(due))
                            .font(.system(size: 9))
                            .foregroundColor(due < Date() ? .red : .gray)
                    }

                    // Location
                    if let loc = NoteMetadataBuilder.parseLocation(from: reminder.notes) {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                                .font(.system(size: 8))
                            Text(loc)
                                .lineLimit(1)
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.purple)
                    }
                }

                // Tags
                let tags = NoteMetadataBuilder.parseTags(from: reminder.notes)
                if !tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(tags.prefix(4), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 8, weight: .medium))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        if tags.count > 4 {
                            Text("+\(tags.count - 4)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if reminder.isPlanned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    reminder.isPlanned ? Color.green.opacity(0.3) : Color.gray.opacity(0.15),
                    lineWidth: 0.5
                )
        )
        .opacity(reminder.isPlanned ? 0.6 : 1.0)
        .draggable(reminder.id) {
            // Compact drag preview
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityColor)
                    .frame(width: 3, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text(formatDuration(reminder.duration))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onTapGesture(count: 2) {
            viewModel.editingReminder = reminder
        }
        .contextMenu { contextMenuContent }
        .popover(isPresented: $showDueDatePicker) {
            dueDatePopover
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        // Edit
        Button {
            viewModel.editingReminder = reminder
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        // Mark as Completed
        Button {
            viewModel.completeReminder(reminder)
        } label: {
            Label("Mark as Completed", systemImage: "checkmark.circle")
        }

        Divider()

        // Due Date submenu
        Menu {
            Button {
                viewModel.setReminderDueDate(reminder, date: Calendar.current.startOfDay(for: Date()))
            } label: {
                Label("Today", systemImage: "calendar")
            }

            Button {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                viewModel.setReminderDueDate(reminder, date: Calendar.current.startOfDay(for: tomorrow))
            } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }

            Button {
                let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
                viewModel.setReminderDueDate(reminder, date: Calendar.current.startOfDay(for: nextWeek))
            } label: {
                Label("Next Week", systemImage: "calendar.badge.clock")
            }

            Divider()

            Button {
                dueDatePickerDate = reminder.dueDate ?? Date()
                showDueDatePicker = true
            } label: {
                Label("Pick a Date...", systemImage: "calendar.badge.plus")
            }

            if reminder.dueDate != nil {
                Divider()
                Button(role: .destructive) {
                    viewModel.setReminderDueDate(reminder, date: nil)
                } label: {
                    Label("Remove Due Date", systemImage: "calendar.badge.minus")
                }
            }
        } label: {
            Label("Due Date", systemImage: "calendar")
        }

        // Priority submenu
        Menu {
            Button {
                viewModel.setReminderPriority(reminder, priority: .none)
            } label: {
                HStack {
                    Text("None")
                    if reminder.priority == .none { Image(systemName: "checkmark") }
                }
            }
            Button {
                viewModel.setReminderPriority(reminder, priority: .low)
            } label: {
                HStack {
                    Text("Low")
                    if reminder.priority == .low { Image(systemName: "checkmark") }
                }
            }
            Button {
                viewModel.setReminderPriority(reminder, priority: .medium)
            } label: {
                HStack {
                    Text("Medium")
                    if reminder.priority == .medium { Image(systemName: "checkmark") }
                }
            }
            Button {
                viewModel.setReminderPriority(reminder, priority: .high)
            } label: {
                HStack {
                    Text("High")
                    if reminder.priority == .high { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Label("Priority", systemImage: "exclamationmark.circle")
        }

        // List submenu
        Menu {
            ForEach(viewModel.allReminderLists) { list in
                Button {
                    if list.name != reminder.listName {
                        viewModel.moveReminder(reminder, toListNamed: list.name)
                    }
                } label: {
                    HStack {
                        Text(list.name)
                        if list.name == reminder.listName {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("List", systemImage: "list.bullet")
        }

        Divider()

        // Copy title
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(reminder.title, forType: .string)
        } label: {
            Label("Copy Title", systemImage: "doc.on.doc")
        }

        Divider()

        // Delete
        Button(role: .destructive) {
            viewModel.deleteReminder(reminder)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Due Date Popover

    private var dueDatePopover: some View {
        VStack(spacing: 12) {
            Text("Set Due Date")
                .font(.system(size: 13, weight: .semibold))

            DatePicker(
                "Due Date",
                selection: $dueDatePickerDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Button("Cancel") {
                    showDueDatePicker = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Set Date") {
                    viewModel.setReminderDueDate(reminder, date: dueDatePickerDate)
                    showDueDatePicker = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Helpers

    private var priorityColor: Color {
        switch reminder.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        case .none: .gray
        }
    }

    private var listColor: Color {
        if let cg = reminder.listColor {
            return Color(cgColor: cg)
        }
        return .gray
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func shortDueText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Due today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if date < Date() {
            return "Overdue"
        } else {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "Due \(f.string(from: date))"
        }
    }
}
