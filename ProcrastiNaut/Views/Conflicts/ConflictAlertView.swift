import SwiftUI

struct ConflictAlertView: View {
    let conflict: ConflictMonitor.ConflictInfo
    let onReschedule: () -> Void
    let onKeepBoth: () -> Void
    let onCancelBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Schedule Conflict")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Your block for:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(conflict.task.reminderTitle)
                    .font(.subheadline.weight(.medium))

                if let start = conflict.task.suggestedStartTime, let end = conflict.task.suggestedEndTime {
                    Text(formatTimeRange(start: start, end: end))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Conflicts with:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Text(conflict.conflictingEventTitle)
                    .font(.subheadline.weight(.medium))

                Text(formatTimeRange(start: conflict.conflictingEventStart, end: conflict.conflictingEventEnd))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 6) {
                Button(action: onReschedule) {
                    Label("Reschedule Task", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                HStack(spacing: 8) {
                    Button(action: onKeepBoth) {
                        Label("Keep Both", systemImage: "pin")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)

                    Button(action: onCancelBlock) {
                        Label("Cancel Block", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
