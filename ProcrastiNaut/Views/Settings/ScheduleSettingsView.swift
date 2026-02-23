import SwiftUI

struct ScheduleSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("Focus Time Blocks") {
                Text("Protected time ranges where no tasks will be scheduled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Placeholder - focus blocks will be fully implemented in Phase 16
                Text("No focus blocks configured.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button("Add Focus Block") {
                    // Will be implemented in advanced settings
                }
                .controlSize(.small)
            }

            Section("Energy Levels") {
                Toggle("Match task difficulty to energy level", isOn: $settings.matchEnergyToTasks)

                Text("Configure when you're at peak energy vs low energy. High-priority tasks will be scheduled during high-energy times.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Show current energy blocks
                ForEach(settings.energyBlocks) { block in
                    HStack {
                        Text(formatTimeOfDay(block.startTime))
                        Text("–")
                        Text(formatTimeOfDay(block.endTime))
                        Spacer()
                        Text(block.level.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(energyColor(block.level).opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func energyColor(_ level: EnergyLevel) -> Color {
        switch level {
        case .highFocus: .orange
        case .medium: .blue
        case .low: .gray
        }
    }
}
