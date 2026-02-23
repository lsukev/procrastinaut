import SwiftUI

struct RescheduleView: View {
    let taskTitle: String
    let onReschedule: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var selectedOption: RescheduleOption = .thirtyMinutes
    @State private var customDate = Date()

    enum RescheduleOption: Hashable {
        case fifteenMinutes
        case thirtyMinutes
        case oneHour
        case tomorrow
        case custom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reschedule")
                .font(.subheadline.weight(.semibold))

            Text(taskTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                optionButton(.fifteenMinutes, label: "In 15 minutes")
                optionButton(.thirtyMinutes, label: "In 30 minutes")
                optionButton(.oneHour, label: "In 1 hour")
                optionButton(.tomorrow, label: "Tomorrow (next available slot)")
                optionButton(.custom, label: "Pick a time...")
            }

            if selectedOption == .custom {
                DatePicker("Time", selection: $customDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Spacer()
                Button("Reschedule") {
                    let delay = delayForOption(selectedOption)
                    onReschedule(delay)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
    }

    private func optionButton(_ option: RescheduleOption, label: String) -> some View {
        Button(action: { selectedOption = option }) {
            HStack {
                Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedOption == option ? .blue : .secondary)
                Text(label)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    private func delayForOption(_ option: RescheduleOption) -> TimeInterval {
        switch option {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .tomorrow: return 24 * 60 * 60
        case .custom: return customDate.timeIntervalSinceNow
        }
    }
}
