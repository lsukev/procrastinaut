import SwiftUI
import EventKit
import MapKit

enum RepeatOption: String, CaseIterable {
    case never = "Never"
    case daily = "Every Day"
    case weekly = "Every Week"
    case biweekly = "Every 2 Weeks"
    case monthly = "Every Month"
    case yearly = "Every Year"
}

struct CreateEventView: View {
    @Bindable var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var selectedCalendarID = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var urlText = ""
    @State private var repeatOption: RepeatOption = .never
    @State private var hasEndRepeat = false
    @State private var endRepeatDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var isCreating = false
    @FocusState private var titleFocused: Bool

    // Location search state
    @State private var locationResults: [MKMapItem] = []
    @State private var locationSearchTask: Task<Void, Never>?
    @State private var showLocationResults = false
    @State private var isSelectingLocation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Event")
                    .font(.system(size: 15, weight: .semibold))
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
                        TextField("Event title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .focused($titleFocused)
                    }

                    // Start Date & Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starts")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "Start",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    }

                    // End Date & Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ends")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "End",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    }

                    // Calendar picker (grouped by account, with colors)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Menu {
                            let grouped = Dictionary(grouping: viewModel.writableCalendars, by: \.sourceName)
                            let sortedKeys = grouped.keys.sorted()
                            ForEach(sortedKeys, id: \.self) { account in
                                Section(account) {
                                    ForEach(grouped[account] ?? [], id: \.id) { cal in
                                        Button {
                                            selectedCalendarID = cal.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(nsImage: calendarColorImage(cal.color, selected: selectedCalendarID == cal.id))
                                                Text(cal.name)
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(selectedCalendarColor)
                                    .frame(width: 10, height: 10)
                                Text(selectedCalendarName)
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Location with autocomplete
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField("Search for a location", text: $location)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onChange(of: location) { _, newValue in
                                    guard !isSelectingLocation else {
                                        isSelectingLocation = false
                                        return
                                    }
                                    searchLocation(newValue)
                                }
                        }

                        // Location search results dropdown
                        if showLocationResults, !locationResults.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(locationResults.prefix(5).enumerated()), id: \.offset) { index, item in
                                    Button {
                                        selectLocation(item)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name ?? "Unknown")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.primary)
                                            if let address = formatAddress(item.placemark), !address.isEmpty {
                                                Text(address)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if index < min(locationResults.count, 5) - 1 {
                                        Divider().padding(.horizontal, 8)
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
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

                    // Repeat
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeat")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Repeat", selection: $repeatOption) {
                            ForEach(RepeatOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()

                        if repeatOption != .never {
                            Toggle(isOn: $hasEndRepeat) {
                                Text("End Repeat")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            if hasEndRepeat {
                                DatePicker(
                                    "End Date",
                                    selection: $endRepeatDate,
                                    in: startDate...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.stepperField)
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button("Create") {
                    createEvent()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: 600)
        .onAppear {
            if let prefilled = viewModel.createEventPrefilledStart {
                // Use the prefilled start time (from double-click on calendar)
                startDate = prefilled
                endDate = prefilled.addingTimeInterval(1800) // 30 min default
                viewModel.createEventPrefilledStart = nil
            } else {
                // Default to the selected date with current time rounded to next 15 min
                let cal = Calendar.current
                let now = Date()
                let minute = cal.component(.minute, from: now)
                let roundedMinute = ((minute / 15) + 1) * 15
                var components = cal.dateComponents([.year, .month, .day], from: viewModel.selectedDate)
                let timeComponents = cal.dateComponents([.hour], from: now)
                components.hour = timeComponents.hour
                components.minute = roundedMinute % 60
                if roundedMinute >= 60 {
                    components.hour = (components.hour ?? 0) + 1
                }
                if let start = cal.date(from: components) {
                    startDate = start
                    endDate = start.addingTimeInterval(3600)
                }
            }

            // Default calendar selection
            if let first = viewModel.writableCalendars.first {
                selectedCalendarID = first.id
            }
            titleFocused = true
        }
        .onChange(of: startDate) { _, newStart in
            // Keep end at least 15 minutes after start
            if endDate <= newStart {
                endDate = newStart.addingTimeInterval(3600)
            }
        }
    }

    // MARK: - Calendar Helpers

    private var selectedCalendarName: String {
        viewModel.writableCalendars.first(where: { $0.id == selectedCalendarID })?.name ?? "Select Calendar"
    }

    private var selectedCalendarColor: Color {
        if let cal = viewModel.writableCalendars.first(where: { $0.id == selectedCalendarID }) {
            return Color(cgColor: cal.color)
        }
        return .gray
    }

    /// Creates a colored circle NSImage that renders properly in native macOS menus.
    /// Native menus ignore SwiftUI .foregroundStyle, so we draw a real NSImage.
    private func calendarColorImage(_ cgColor: CGColor, selected: Bool, size: CGFloat = 12) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let color = NSColor(cgColor: cgColor) ?? .gray
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()

        if selected {
            // Draw a white checkmark in the center
            NSColor.white.setStroke()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: size * 0.25, y: size * 0.50))
            check.line(to: NSPoint(x: size * 0.45, y: size * 0.30))
            check.line(to: NSPoint(x: size * 0.75, y: size * 0.72))
            check.lineWidth = 1.5
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false  // Prevent macOS from rendering as template/monochrome
        return image
    }

    // MARK: - Location Search

    private func searchLocation(_ query: String) {
        locationSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 2 else {
            locationResults = []
            showLocationResults = false
            return
        }

        locationSearchTask = Task {
            // Debounce: wait 300ms before searching
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            let search = MKLocalSearch(request: request)

            if let response = try? await search.start() {
                locationResults = response.mapItems
                showLocationResults = true
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        isSelectingLocation = true
        var parts: [String] = []
        if let name = item.name { parts.append(name) }
        if let address = formatAddress(item.placemark), !address.isEmpty, address != item.name {
            parts.append(address)
        }
        location = parts.joined(separator: ", ")
        showLocationResults = false
        locationResults = []
    }

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var parts: [String] = []
        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                parts.append("\(number) \(street)")
            } else {
                parts.append(street)
            }
        }
        if let city = placemark.locality { parts.append(city) }
        if let state = placemark.administrativeArea { parts.append(state) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Create

    private func createEvent() {
        isCreating = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let finalLocation = location.trimmingCharacters(in: .whitespaces)
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = URL(string: urlText.trimmingCharacters(in: .whitespaces))

        let recurrenceRule = buildRecurrenceRule()

        Task {
            await viewModel.createEvent(
                title: trimmedTitle,
                startDate: startDate,
                endDate: endDate,
                calendarID: selectedCalendarID,
                location: finalLocation.isEmpty ? nil : finalLocation,
                notes: finalNotes.isEmpty ? nil : finalNotes,
                url: finalURL,
                recurrenceRule: recurrenceRule
            )
            isCreating = false
        }
    }

    private func buildRecurrenceRule() -> EKRecurrenceRule? {
        guard repeatOption != .never else { return nil }

        let frequency: EKRecurrenceFrequency
        let interval: Int

        switch repeatOption {
        case .never:
            return nil
        case .daily:
            frequency = .daily
            interval = 1
        case .weekly:
            frequency = .weekly
            interval = 1
        case .biweekly:
            frequency = .weekly
            interval = 2
        case .monthly:
            frequency = .monthly
            interval = 1
        case .yearly:
            frequency = .yearly
            interval = 1
        }

        let end: EKRecurrenceEnd? = hasEndRepeat
            ? EKRecurrenceEnd(end: endRepeatDate)
            : nil

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: end
        )
    }
}
