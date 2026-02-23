import SwiftUI

struct CompletionStatsView: View {
    let totalCompleted: Int
    let todayCompleted: Int
    let todayTotal: Int
    let completionRate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Stats", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                statItem(
                    value: "\(todayCompleted)/\(todayTotal)",
                    label: "Today",
                    color: completionRate >= 0.8 ? .green : .blue
                )

                statItem(
                    value: "\(Int(completionRate * 100))%",
                    label: "Rate",
                    color: completionRate >= 0.8 ? .green : .orange
                )

                statItem(
                    value: "\(totalCompleted)",
                    label: "All Time",
                    color: .purple
                )
            }

            ProgressView(value: completionRate)
                .tint(completionRate >= 0.8 ? .green : .blue)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
