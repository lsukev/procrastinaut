import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            // MARK: - Accent Color
            Section("Accent Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(AppTheme.accentColorOptions, id: \.name) { option in
                        Button {
                            settings.accentColorName = option.name
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if settings.accentColorName == option.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(option.name.capitalized)
                    }
                }
                .padding(.vertical, 4)

                Text("Changes the today indicator, selected states, and active toggle highlights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Font Size
            Section("Font Size") {
                Picker("Text Size", selection: $settings.fontSizeTier) {
                    Text("Small").tag("small")
                    Text("Standard").tag("standard")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)

                Text("Adjusts calendar headers, event text, and sidebar labels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Calendar Density
            Section("Calendar Density") {
                Picker("Density", selection: $settings.calendarDensity) {
                    Text("Comfortable").tag("comfortable")
                    Text("Compact").tag("compact")
                }
                .pickerStyle(.segmented)

                Text("Compact reduces hour row height to show more of your day at once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Current Time Indicator
            Section("Current Time Indicator") {
                HStack(spacing: 12) {
                    ForEach(AppTheme.nowLineColorOptions, id: \.name) { option in
                        Button {
                            settings.nowLineColorName = option.name
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 14, height: 14)
                                    .overlay {
                                        if option.name == "white" {
                                            Circle().strokeBorder(.gray.opacity(0.4), lineWidth: 0.5)
                                        }
                                    }
                                Text(option.name.capitalized)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                settings.nowLineColorName == option.name
                                    ? option.color.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        settings.nowLineColorName == option.name
                                            ? option.color.opacity(0.4)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - Animations
            Section("Animations") {
                Toggle("Enable animations", isOn: $settings.animationsEnabled)

                Text("Disabling removes transitions and motion throughout the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Appearance Mode
            Section("Appearance") {
                Picker("Mode", selection: $settings.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}
