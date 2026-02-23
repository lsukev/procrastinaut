import SwiftUI

struct PartialCompletionView: View {
    let taskTitle: String
    let onSubmit: (Int) -> Void
    let onCancel: () -> Void

    @State private var selectedMinutes: Int = 30
    @State private var customMinutes: String = ""
    @State private var useCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Partial Progress")
                .font(.subheadline.weight(.semibold))

            Text(taskTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("How much time do you still need?")
                .font(.caption)

            VStack(alignment: .leading, spacing: 6) {
                minuteOption(15)
                minuteOption(30)
                minuteOption(45)

                Button(action: { useCustom = true; selectedMinutes = 0 }) {
                    HStack {
                        Image(systemName: useCustom ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(useCustom ? .blue : .secondary)
                        Text("Custom:")
                            .font(.caption)
                        if useCustom {
                            TextField("min", text: $customMinutes)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                            Text("minutes")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Spacer()
                Button("Schedule Remaining") {
                    let minutes = useCustom ? (Int(customMinutes) ?? 30) : selectedMinutes
                    onSubmit(minutes)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
    }

    private func minuteOption(_ minutes: Int) -> some View {
        Button(action: { selectedMinutes = minutes; useCustom = false }) {
            HStack {
                Image(systemName: (!useCustom && selectedMinutes == minutes) ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle((!useCustom && selectedMinutes == minutes) ? .blue : .secondary)
                Text("\(minutes) minutes")
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}
