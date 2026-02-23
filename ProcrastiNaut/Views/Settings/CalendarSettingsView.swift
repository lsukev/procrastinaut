import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var availableCalendars: [EKCalendar] = []
    @State private var viewableCalendarIDs: Set<String> = []
    @State private var monitoredCalendarIDs: Set<String> = []
    @State private var blockingCalendarID: String = ""

    var body: some View {
        Form {
            Section {
                if availableCalendars.isEmpty {
                    Text("No calendars available. Grant calendar access first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Column headers
                    HStack {
                        Text("Calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("View")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 50)
                        Text("Monitor")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 60)
                    }

                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        calendarRow(calendar)
                    }
                }
            } header: {
                Text("Calendars")
            } footer: {
                Text("**View** shows events on the planner calendar. **Monitor** uses the calendar for busy-time detection in AI scheduling.")
                    .font(.caption)
            }

            Section("Create Events On") {
                Picker("Calendar", selection: $blockingCalendarID) {
                    Text("ProcrastiNaut (auto-created)").tag("")
                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        Text("\(calendar.title) (\(calendar.source.title))")
                            .tag(calendar.calendarIdentifier)
                    }
                }
                .onChange(of: blockingCalendarID) { _, newValue in
                    settings.blockingCalendarID = newValue
                }
            }

            Section("Working Hours") {
                timePicker(label: "Start", value: $settings.workingHoursStart)
                timePicker(label: "End", value: $settings.workingHoursEnd)
            }

            Section("Working Days") {
                workingDaysGrid
            }

            Section("Event Appearance") {
                Picker("Color Coding", selection: $settings.eventColorMode) {
                    Text("By priority").tag("priority")
                    Text("By source list").tag("list")
                    Text("Single color").tag("single")
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadCalendars()
        }
    }

    // MARK: - Calendar Row

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        HStack {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 8, height: 8)
            Text(calendar.title)
                .lineLimit(1)
            Text("(\(calendar.source.title))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()

            // View toggle
            Toggle("", isOn: Binding(
                get: { viewableCalendarIDs.contains(calendar.calendarIdentifier) },
                set: { isOn in
                    if isOn {
                        viewableCalendarIDs.insert(calendar.calendarIdentifier)
                    } else {
                        viewableCalendarIDs.remove(calendar.calendarIdentifier)
                    }
                    settings.viewableCalendarIDs = Array(viewableCalendarIDs)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(width: 50)

            // Monitor toggle
            Toggle("", isOn: Binding(
                get: { monitoredCalendarIDs.contains(calendar.calendarIdentifier) },
                set: { isOn in
                    if isOn {
                        monitoredCalendarIDs.insert(calendar.calendarIdentifier)
                    } else {
                        monitoredCalendarIDs.remove(calendar.calendarIdentifier)
                    }
                    settings.monitoredCalendarIDs = Array(monitoredCalendarIDs)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(width: 60)
        }
    }

    // MARK: - Working Days

    private var workingDaysGrid: some View {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return HStack {
            ForEach(0..<7, id: \.self) { index in
                Toggle(dayNames[index], isOn: Binding(
                    get: { settings.workingDays.contains(index) },
                    set: { isOn in
                        var days = settings.workingDays
                        if isOn {
                            days.insert(index)
                        } else {
                            days.remove(index)
                        }
                        settings.workingDays = days
                    }
                ))
                .toggleStyle(.checkbox)
            }
        }
    }

    private func timePicker(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(formatTimeOfDay(value.wrappedValue))
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: 0...86400, step: 1800)
                .labelsHidden()
        }
    }

    private func loadCalendars() {
        availableCalendars = EventKitManager.shared.getAvailableCalendars()
        viewableCalendarIDs = Set(settings.viewableCalendarIDs)
        monitoredCalendarIDs = Set(settings.monitoredCalendarIDs)
        blockingCalendarID = settings.blockingCalendarID
    }
}
