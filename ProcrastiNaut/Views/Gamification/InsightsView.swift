import SwiftUI

struct InsightsView: View {
    let insights: [SchedulingInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)

                Text("Scheduling Insights")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Text("Last 30 days")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(categoryColor(insight.category))
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.system(size: 11, weight: .medium))

                        Text(insight.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func categoryColor(_ category: SchedulingInsight.InsightCategory) -> Color {
        switch category {
        case .duration: .purple
        case .timing: .blue
        case .priority: .gray
        case .interruption: .orange
        }
    }
}
