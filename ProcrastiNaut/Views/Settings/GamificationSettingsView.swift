import SwiftUI

struct GamificationSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("Stats & Progress") {
                Toggle("Show completion stats in popover", isOn: $settings.showCompletionStats)
            }

            Section("Streaks") {
                Toggle("Enable streaks", isOn: $settings.enableStreaks)

                if settings.enableStreaks {
                    HStack {
                        Text("Streak threshold")
                        Spacer()
                        Text("\(Int(settings.streakThreshold * 100))%")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $settings.streakThreshold, in: 0.5...1.0, step: 0.05)
                        .help("Minimum daily completion rate to maintain your streak")
                }
            }

            Section("Streak Protection") {
                Toggle("Enable streak freeze", isOn: $settings.enableStreakFreeze)
                    .help("Automatically preserve your streak on missed days")

                if settings.enableStreakFreeze {
                    Stepper("Freezes per week: \(settings.maxFreezesPerWeek)",
                            value: $settings.maxFreezesPerWeek, in: 1...3)
                        .help("Maximum streak freezes available each week")
                }
            }

            Section("Badges") {
                Toggle("Enable badges", isOn: $settings.enableBadges)
            }
        }
        .formStyle(.grouped)
    }
}
