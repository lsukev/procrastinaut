import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    private let notificationService = SystemNotificationService.shared

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable System Notifications", isOn: $settings.notificationsEnabled)

                HStack {
                    if notificationService.permissionGranted {
                        Label("Permission Granted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Permission Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Spacer()

                        Button("Open System Settings") {
                            Task { await notificationService.requestPermission() }
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Event Alerts") {
                Toggle("Upcoming event reminders", isOn: $settings.notifyEventReminders)

                Picker("Alert before event", selection: $settings.eventReminderMinutes) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
                .disabled(!settings.notifyEventReminders)

                Toggle("Calendar conflict alerts", isOn: $settings.notifyConflicts)
                Toggle("New meeting invitations", isOn: $settings.notifyInvitations)
            }
            .disabled(!settings.notificationsEnabled)

            Section("Tasks") {
                Toggle("Overdue reminder alerts", isOn: $settings.notifyOverdueReminders)
                Toggle("Focus timer completion", isOn: $settings.notifyFocusTimerEnd)
                Toggle("Daily summary", isOn: $settings.notifyDailySummary)
            }
            .disabled(!settings.notificationsEnabled)

            Section("Quiet Hours") {
                Toggle("Enable quiet hours", isOn: $settings.quietHoursEnabled)

                if settings.quietHoursEnabled {
                    HStack {
                        Text("Start")
                        Spacer()
                        Text(formatTimeOfDay(settings.quietHoursStart))
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.quietHoursStart, in: 0...86400, step: 1800)
                            .labelsHidden()
                    }

                    HStack {
                        Text("End")
                        Spacer()
                        Text(formatTimeOfDay(settings.quietHoursEnd))
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.quietHoursEnd, in: 0...86400, step: 1800)
                            .labelsHidden()
                    }

                    Text("Notifications will be silenced during quiet hours (except daily summary).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!settings.notificationsEnabled)

            Section("Sound") {
                Picker("Notification sound", selection: $settings.notificationSound) {
                    Text("Default").tag("default")
                    Text("Subtle").tag("subtle")
                    Text("None").tag("none")
                }
                .pickerStyle(.radioGroup)
            }
            .disabled(!settings.notificationsEnabled)
        }
        .formStyle(.grouped)
        .onAppear {
            Task { await notificationService.recheckPermission() }
        }
    }
}
