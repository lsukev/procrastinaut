import SwiftUI
import EventKit

struct EventContextPanel: View {
    @Bindable var viewModel: PlannerViewModel

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timeSection
                    calendarBadge

                    if let meetingLink = viewModel.editMeetingLink {
                        joinMeetingButton(meetingLink)
                    }

                    if !viewModel.editLocation.isEmpty {
                        locationSection
                    }

                    if !viewModel.editAttendees.isEmpty {
                        attendeesSection
                    }

                    if let url = viewModel.editURL {
                        urlSection(url)
                    }

                    if !viewModel.editNotes.isEmpty {
                        notesSection
                    }

                    if !viewModel.editAlarms.isEmpty {
                        alarmsSection
                    }

                    if let recurrence = viewModel.editRecurrenceDescription {
                        recurrenceSection(recurrence)
                    }

                    if let reminderTitle = viewModel.editLinkedReminderTitle {
                        linkedReminderSection(reminderTitle)
                    }

                    editSection
                }
                .padding(14)
            }

            Divider()
            actionButtons
        }
        .frame(width: 300)
        .confirmationDialog(
            recurrenceDialogTitle,
            isPresented: $viewModel.showRecurrenceChoice,
            titleVisibility: .visible
        ) {
            Button("This Event Only") {
                viewModel.confirmRecurrenceAction(span: .thisEvent)
            }
            Button("All Future Events") {
                viewModel.confirmRecurrenceAction(span: .futureEvents)
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingRecurrenceAction = nil
            }
        }
    }

    private var recurrenceDialogTitle: String {
        switch viewModel.pendingRecurrenceAction {
        case .save:
            return "This is a recurring event. Which events do you want to update?"
        case .delete:
            return "This is a recurring event. Which events do you want to delete?"
        case .none:
            return "This is a recurring event."
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            if let color = viewModel.editCalendarColor {
                Circle()
                    .fill(Color(cgColor: color))
                    .frame(width: 10, height: 10)
            }

            Text(viewModel.editTitle)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.cancelEdit()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Time

    private var timeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatDateRange(start: viewModel.editStartTime, end: viewModel.editEndTime))
                    .font(.system(size: 13))

                Text(formatDuration(from: viewModel.editStartTime, to: viewModel.editEndTime))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Calendar Badge

    private var calendarBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(viewModel.editCalendarName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if viewModel.editIsReadOnly {
                Text("Read-only")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Join Meeting

    private func joinMeetingButton(_ url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: meetingIcon(for: url))
                    .font(.system(size: 14, weight: .medium))

                Text("Join \(meetingServiceName(for: url))")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(meetingColor(for: url), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func meetingServiceName(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") {
            return "Teams Meeting"
        } else if host.contains("zoom.us") {
            return "Zoom Meeting"
        } else if host.contains("meet.google.com") {
            return "Google Meet"
        } else if host.contains("webex.com") {
            return "Webex Meeting"
        } else if host.contains("gotomeeting.com") || host.contains("gotomeet.me") {
            return "GoTo Meeting"
        } else {
            return "Meeting"
        }
    }

    private func meetingIcon(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("teams") {
            return "video.fill"
        } else if host.contains("zoom") {
            return "video.fill"
        } else if host.contains("meet.google") {
            return "video.fill"
        } else {
            return "video.fill"
        }
    }

    private func meetingColor(for url: URL) -> Color {
        let host = url.host?.lowercased() ?? ""
        if host.contains("teams") {
            return Color(red: 0.29, green: 0.21, blue: 0.69) // Teams purple
        } else if host.contains("zoom") {
            return Color(red: 0.16, green: 0.50, blue: 0.93) // Zoom blue
        } else if host.contains("meet.google") {
            return Color(red: 0.0, green: 0.59, blue: 0.53)  // Meet teal
        } else if host.contains("webex") {
            return Color(red: 0.0, green: 0.45, blue: 0.75)  // Webex blue
        } else {
            return .blue
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.editLocation)
                    .font(.system(size: 12))

                Button {
                    openInMaps(location: viewModel.editLocation)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Attendees

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text("\(viewModel.editAttendees.count) attendee\(viewModel.editAttendees.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ForEach(viewModel.editAttendees) { attendee in
                    HStack(spacing: 6) {
                        Image(systemName: attendee.status.symbolName)
                            .font(.system(size: 11))
                            .foregroundStyle(attendee.status.color)

                        Text(attendee.name)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text(attendee.status.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }

    // MARK: - URL

    private func urlSection(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Text(url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notes

    @State private var showFullNotes = false

    private var notesSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.editNotes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(showFullNotes ? nil : 4)

                if viewModel.editNotes.count > 150 {
                    Button(showFullNotes ? "Show less" : "Show more") {
                        withAnimation { showFullNotes.toggle() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Alarms

    private var alarmsSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.editAlarms, id: \.self) { alarm in
                    Text(alarm)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Recurrence

    private func recurrenceSection(_ description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Linked Reminder

    private func linkedReminderSection(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 13))
                .foregroundStyle(.purple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Linked Reminder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(title)
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - Edit Section

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Edit")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 3) {
                Text("Title")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Event title", text: $viewModel.editTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .disabled(viewModel.editIsReadOnly)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.editStartTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .controlSize(.small)
                        .disabled(viewModel.editIsReadOnly)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("End")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $viewModel.editEndTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .controlSize(.small)
                        .disabled(viewModel.editIsReadOnly)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if !viewModel.editIsReadOnly {
                Button {
                    if let event = viewModel.editingEvent {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.deleteEvent(id: event.id)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Delete event")
            }

            Spacer()

            Button("Close") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.cancelEdit()
                }
            }
            .controlSize(.small)

            if !viewModel.editIsReadOnly {
                Button("Save") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.saveEdit()
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }

    // MARK: - Formatting Helpers

    private func formatDateRange(start: Date, end: Date) -> String {
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

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func openInMaps(location: String) {
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
}
