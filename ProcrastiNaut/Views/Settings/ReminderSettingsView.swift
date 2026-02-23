import SwiftUI
import EventKit

struct ReminderSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var availableLists: [EKCalendar] = []
    @State private var selectedListIDs: Set<String> = []

    var body: some View {
        Form {
            Section("Reminder Lists to Monitor") {
                if availableLists.isEmpty {
                    Text("No reminder lists available. Grant reminders access first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableLists, id: \.calendarIdentifier) { list in
                        Toggle(list.title, isOn: Binding(
                            get: { selectedListIDs.contains(list.calendarIdentifier) },
                            set: { isOn in
                                if isOn {
                                    selectedListIDs.insert(list.calendarIdentifier)
                                } else {
                                    selectedListIDs.remove(list.calendarIdentifier)
                                }
                                settings.monitoredReminderListIDs = Array(selectedListIDs)
                            }
                        ))
                    }
                }
            }

            Section("Default List") {
                if availableLists.isEmpty {
                    Text("No reminder lists available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Save new reminders to", selection: $settings.defaultReminderListID) {
                        Text("First monitored list").tag("")
                        ForEach(availableLists, id: \.calendarIdentifier) { list in
                            Text(list.title).tag(list.calendarIdentifier)
                        }
                    }
                }
            }

            Section("Include Options") {
                Toggle("Include reminders with no due date", isOn: .constant(true))
                Toggle("Only show past-due reminders", isOn: .constant(false))
                Toggle("Sort by priority", isOn: $settings.prioritySorting)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadLists()
        }
    }

    private func loadLists() {
        availableLists = EventKitManager.shared.getAvailableReminderLists()
        selectedListIDs = Set(settings.monitoredReminderListIDs)
    }
}
