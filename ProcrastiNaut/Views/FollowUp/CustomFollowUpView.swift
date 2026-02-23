import SwiftUI

struct CustomFollowUpView: View {
    let task: ProcrastiNautTask
    let onDone: () -> Void
    let onPartial: () -> Void
    let onNotDone: (RescheduleReason) -> Void

    @State private var showingReasons = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text("Task Follow-Up")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Divider()

            // Task info
            VStack(spacing: 6) {
                Text("Did you complete:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(task.reminderTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let start = task.suggestedStartTime, let end = task.suggestedEndTime {
                    Text(formatTimeRange(start: start, end: end))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if showingReasons {
                // Phase 2: Reason selection
                reasonGrid
            } else {
                // Phase 1: Done / Not Done
                doneNotDoneButtons
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showingReasons)
    }

    // MARK: - Phase 1: Done / Not Done

    private var doneNotDoneButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onDone) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: { showingReasons = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Not Done")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            Button(action: onPartial) {
                Text("Partially done...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Phase 2: Reason Grid

    private var reasonGrid: some View {
        VStack(spacing: 8) {
            Text("What happened?")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(RescheduleReason.allCases, id: \.self) { reason in
                    reasonButton(reason)
                }
            }

            Button(action: { showingReasons = false }) {
                Text("Back")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func reasonButton(_ reason: RescheduleReason) -> some View {
        Button(action: { onNotDone(reason) }) {
            VStack(spacing: 4) {
                Image(systemName: reason.icon)
                    .font(.system(size: 16))
                Text(reason.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(reasonColor(reason).opacity(0.1))
            .foregroundStyle(reasonColor(reason))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(reasonColor(reason).opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func reasonColor(_ reason: RescheduleReason) -> Color {
        switch reason {
        case .tooLong: .purple
        case .badTime: .blue
        case .interrupted: .orange
        case .notImportant: .gray
        }
    }
}
