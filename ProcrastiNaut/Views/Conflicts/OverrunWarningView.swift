import SwiftUI

struct OverrunWarningView: View {
    let taskTitle: String
    let endTime: Date
    let nextEventTitle: String?
    let onMarkDone: () -> Void
    let onContinueLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Time Running Out")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Divider()

            Text("\"\(taskTitle)\" ends at \(formattedTime(endTime))")
                .font(.caption)

            if let next = nextEventTitle {
                Text("Your next event: \"\(next)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: onMarkDone) {
                    Label("Mark Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button(action: onContinueLater) {
                    Label("Continue Later", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
            }
        }
        .padding()
        .background(.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
