import SwiftUI
import Sparkle

struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    private let updater: SPUUpdater

    init() {
        updater = AppDelegate.shared?.updaterController.updater
            ?? SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            ).updater
    }

    var body: some View {
        Form {
            Section("Updates") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ProcrastiNaut v\(appVersion)")
                            .font(.system(size: 12, weight: .medium))
                        if let lastCheck = updater.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck, style: .relative) ago")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button("Check for Updates") {
                        updater.checkForUpdates()
                    }
                }

                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            }

            Section("Timing") {
                timePicker(label: "Morning Scan Time", value: $settings.morningScanTime)

                Picker("Default Task Duration", selection: $settings.defaultTaskDuration) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                }

                Picker("Buffer Between Tasks", selection: $settings.bufferBetweenBlocks) {
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("20 minutes").tag(20)
                    Text("30 minutes").tag(30)
                }

                Picker("Follow-up Delay", selection: $settings.followUpDelay) {
                    Text("Immediately").tag(0)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }

                Stepper("Max Suggestions/Day: \(settings.maxSuggestionsPerDay)",
                        value: $settings.maxSuggestionsPerDay, in: 1...20)
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.setEnabled($0) }
                ))

                Toggle("Show completion stats in menu bar", isOn: $settings.showCompletionStats)
                Toggle("Auto-approve recurring tasks", isOn: $settings.autoApproveRecurring)
                Toggle("Learn task durations from history", isOn: $settings.enableDurationLearning)
            }

            Section("Scheduling Preference") {
                Picker("Schedule tasks", selection: $settings.preferredSlotTimes) {
                    Text("Morning first").tag("morning_first")
                    Text("Afternoon first").tag("afternoon_first")
                    Text("Spread evenly").tag("spread_evenly")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Quick Chat") {
                HotkeyRecorderView()
                Toggle("Default to AI mode", isOn: $settings.quickChatDefaultAIMode)
                    .help("When enabled, Quick Chat will use Claude AI for parsing instead of local NLP. Requires an API key in Settings > AI.")
            }

            Section("Weather") {
                Toggle("Show weather in month view", isOn: $settings.showWeatherInMonthView)

                Picker("Temperature unit", selection: $settings.temperatureUnit) {
                    Text("Fahrenheit (\u{00B0}F)").tag("fahrenheit")
                    Text("Celsius (\u{00B0}C)").tag("celsius")
                }

                if settings.cachedLatitude != 0 || settings.cachedLongitude != 0 {
                    HStack {
                        Text("Location cached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset Location") {
                            settings.cachedLatitude = 0
                            settings.cachedLongitude = 0
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Weather will request location access when you view the month calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: settings.temperatureUnit) { _, _ in
                Task { await WeatherService.shared.fetchWeatherIfNeeded(force: true) }
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private func timePicker(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(formatTimeOfDay(value.wrappedValue))
                .foregroundStyle(.secondary)

            Stepper("",
                    value: value,
                    in: 0...86400,
                    step: 1800) // 30 minute increments
                .labelsHidden()
        }
    }
}
