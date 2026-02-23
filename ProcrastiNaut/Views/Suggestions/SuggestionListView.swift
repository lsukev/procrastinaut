import SwiftUI

struct SuggestionListView: View {
    @Binding var suggestions: [ProcrastiNautTask]
    let onApprove: (ProcrastiNautTask) -> Void
    let onApproveAll: () -> Void
    let onSkip: (ProcrastiNautTask) -> Void
    let onDismiss: () -> Void
    let onChangeDuration: (ProcrastiNautTask, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Suggestions")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("\(suggestions.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if suggestions.isEmpty {
                emptyState
            } else {
                // Suggestion cards
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(suggestions) { task in
                            SuggestionCardView(
                                task: task,
                                onApprove: { onApprove(task) },
                                onSkip: { onSkip(task) },
                                onChangeDuration: { newDuration in
                                    onChangeDuration(task, newDuration)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                // Footer
                HStack(spacing: 10) {
                    Button(action: onApproveAll) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Approve All")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.5))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green.opacity(0.6))

            Text("All caught up!")
                .font(.system(size: 14, weight: .semibold))

            Text("No suggestions available right now.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
