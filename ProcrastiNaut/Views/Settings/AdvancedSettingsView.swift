import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("Notifications") {
                Picker("Follow-up rate limit", selection: $settings.followUpRateLimit) {
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                }

                Picker("Undo window", selection: $settings.undoWindowDuration) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }
            }

            Section("Gamification") {
                Toggle("Enable streaks", isOn: $settings.enableStreaks)
                Toggle("Enable badges", isOn: $settings.enableBadges)

                if settings.enableStreaks {
                    HStack {
                        Text("Streak threshold")
                        Spacer()
                        Text("\(Int(settings.streakThreshold * 100))%")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.streakThreshold, in: 0.5...1.0, step: 0.1)
                            .frame(width: 150)
                    }
                }
            }

            Section("Weekly Planning") {
                Toggle("Enable weekly planning mode", isOn: $settings.weeklyPlanningEnabled)

                if settings.weeklyPlanningEnabled {
                    Picker("Planning day", selection: $settings.weeklyPlanningDay) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Saturday").tag(7)
                    }

                    HStack {
                        Text("Planning time")
                        Spacer()
                        Text(formatTimeOfDay(settings.weeklyPlanningTime))
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.weeklyPlanningTime, in: 0...86400, step: 1800)
                            .labelsHidden()
                    }
                }
            }

            Section("Data Management") {
                Picker("Auto-archive after", selection: $settings.archiveAfterDays) {
                    Text("30 days").tag(30)
                    Text("60 days").tag(60)
                    Text("90 days").tag(90)
                    Text("180 days").tag(180)
                    Text("1 year").tag(365)
                }

                Picker("Delete archived after", selection: $settings.deleteArchivedAfterDays) {
                    Text("6 months").tag(180)
                    Text("1 year").tag(365)
                    Text("2 years").tag(730)
                    Text("Never").tag(99999)
                }
            }

            Section("Permissions") {
                PermissionsView()
            }
        }
        .formStyle(.grouped)
    }
}
