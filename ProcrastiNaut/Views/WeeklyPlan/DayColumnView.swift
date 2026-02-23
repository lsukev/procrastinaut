import SwiftUI

struct DayColumnView: View {
    let dayPlan: DailyPlan
    let dayLabel: String

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(dayPlan.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day header
            Text(dayLabel)
                .font(.caption.weight(.semibold))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isToday ? Color.blue.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Task list
            if dayPlan.tasks.isEmpty {
                Text("No tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 4) {
                    ForEach(dayPlan.tasks) { task in
                        taskChip(task)
                    }
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            // Completion rate
            if !dayPlan.tasks.isEmpty {
                Text("\(dayPlan.completedCount)/\(dayPlan.tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(width: 90)
        .padding(6)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func taskChip(_ task: ProcrastiNautTask) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.reminderTitle)
                .font(.system(size: 9))
                .lineLimit(2)

            if let start = task.suggestedStartTime {
                Text(timeFormatter.string(from: start))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor(task.status).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .completed: .green
        case .approved, .inProgress: .blue
        case .pending: .gray
        default: .gray
        }
    }
}
