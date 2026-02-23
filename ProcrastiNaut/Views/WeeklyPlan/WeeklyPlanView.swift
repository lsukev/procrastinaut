import SwiftUI

struct WeeklyPlanView: View {
    @Binding var weeklyPlan: WeeklyPlan?
    let onGeneratePlan: () -> Void

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE M/d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if let plan = weeklyPlan {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(plan.dayPlans) { dayPlan in
                            DayColumnView(
                                dayPlan: dayPlan,
                                dayLabel: dayFormatter.string(from: dayPlan.date)
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if !plan.unassignedTasks.isEmpty {
                    unassignedSection(plan.unassignedTasks)
                }
            } else {
                NoAvailabilityView(
                    message: "No weekly plan yet",
                    suggestion: "Tap Generate to create a plan for this week"
                )
            }
        }
        .padding()
    }

    private var headerSection: some View {
        HStack {
            Label("Weekly Plan", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button(action: onGeneratePlan) {
                Label("Generate", systemImage: "wand.and.stars")
            }
            .controlSize(.small)
        }
    }

    private func unassignedSection(_ tasks: [ProcrastiNautTask]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(tasks.count) unassigned", systemImage: "tray")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(tasks) { task in
                HStack(spacing: 6) {
                    Circle()
                        .fill(priorityColor(task.priority))
                        .frame(width: 6, height: 6)

                    Text(task.reminderTitle)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(task.suggestedDuration / 60))m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: .red
        case .medium: .yellow
        case .low: .blue
        case .none: .gray
        }
    }
}
