import SwiftUI

struct EnergySettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var energyBlocks: [EnergyBlock] = []

    var body: some View {
        Form {
            Section("Energy Matching") {
                Toggle("Match energy levels to tasks", isOn: $settings.matchEnergyToTasks)
                    .help("Schedule high-energy tasks during your peak hours")
            }

            Section("Energy Blocks") {
                ForEach(energyBlocks.indices, id: \.self) { index in
                    energyBlockRow(index: index)
                }

                Button("Add Block") {
                    let newBlock = EnergyBlock(
                        startTime: 32400,  // 9 AM
                        endTime: 43200,    // 12 PM
                        level: .medium
                    )
                    energyBlocks.append(newBlock)
                    settings.energyBlocks = energyBlocks
                }
                .controlSize(.small)
            }

            Section("List Defaults") {
                Text("Set default energy requirements per reminder list in Reminders settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            energyBlocks = settings.energyBlocks
        }
    }

    private func energyBlockRow(index: Int) -> some View {
        HStack {
            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromSeconds(energyBlocks[index].startTime) },
                    set: { newDate in
                        energyBlocks[index].startTime = secondsFromMidnight(newDate)
                        settings.energyBlocks = energyBlocks
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .frame(width: 90)

            Text("–")
                .foregroundStyle(.secondary)

            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromSeconds(energyBlocks[index].endTime) },
                    set: { newDate in
                        energyBlocks[index].endTime = secondsFromMidnight(newDate)
                        settings.energyBlocks = energyBlocks
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .frame(width: 90)

            Spacer()

            Picker("", selection: Binding(
                get: { energyBlocks[index].level },
                set: { newValue in
                    energyBlocks[index].level = newValue
                    settings.energyBlocks = energyBlocks
                }
            )) {
                Text("High Focus").tag(EnergyLevel.highFocus)
                Text("Medium").tag(EnergyLevel.medium)
                Text("Low").tag(EnergyLevel.low)
            }
            .frame(width: 140)

            Button(role: .destructive) {
                energyBlocks.remove(at: index)
                settings.energyBlocks = energyBlocks
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    /// Convert seconds-from-midnight to a Date (today at that time) for DatePicker.
    private func dateFromSeconds(_ seconds: TimeInterval) -> Date {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return Calendar.current.date(bySettingHour: hours, minute: minutes, second: 0, of: Date()) ?? Date()
    }

    /// Convert a Date back to seconds-from-midnight.
    private func secondsFromMidnight(_ date: Date) -> TimeInterval {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
    }
}
