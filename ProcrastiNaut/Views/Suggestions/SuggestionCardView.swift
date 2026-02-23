import SwiftUI

struct SuggestionCardView: View {
    let task: ProcrastiNautTask
    let onApprove: () -> Void
    let onSkip: () -> Void
    let onChangeDuration: (Int) -> Void

    @State private var selectedDuration: Int

    init(
        task: ProcrastiNautTask,
        onApprove: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onChangeDuration: @escaping (Int) -> Void
    ) {
        self.task = task
        self.onApprove = onApprove
        self.onSkip = onSkip
        self.onChangeDuration = onChangeDuration
        self._selectedDuration = State(initialValue: Int(task.suggestedDuration / 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack(spacing: 8) {
                priorityIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.reminderTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)

                    if let dueDate = task.dueDate {
                        Text(dueDateText(dueDate))
                            .font(.system(size: 10))
                            .foregroundStyle(dueDate < Date() ? .red : .secondary)
                    }
                }

                Spacer()
            }

            // Time and duration row
            HStack(spacing: 12) {
                if let start = task.suggestedStartTime, let end = task.suggestedEndTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatTimeRange(start: start, end: end))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedDuration) {
                    Text("15m").tag(15)
                    Text("30m").tag(30)
                    Text("45m").tag(45)
                    Text("1h").tag(60)
                    Text("1.5h").tag(90)
                    Text("2h").tag(120)
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .onChange(of: selectedDuration) { _, newValue in
                    onChangeDuration(newValue)
                }
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Approve")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward")
                            .font(.system(size: 10, weight: .bold))
                        Text("Skip")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private var priorityIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(priorityColor)
            .frame(width: 4, height: 32)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        case .none: .gray
        }
    }

    private func dueDateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Due today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d overdue"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Due \(formatter.string(from: date))"
        }
    }
}
