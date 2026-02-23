import SwiftUI

struct StreakView: View {
    let currentStreak: Int
    let longestStreak: Int
    let currentTitle: String
    let levelProgress: Double
    let nextLevelTitle: String?
    var totalXP: Int = 0
    var todayXP: Int = 0
    var streakFreezesAvailable: Int = 0
    var freezeEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Streak + XP counters
            HStack(spacing: 8) {
                // Current streak with animated flame
                HStack(spacing: 6) {
                    AnimatedFlameView(isActive: currentStreak > 0, streakCount: currentStreak)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(currentStreak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(currentStreak > 0 ? .primary : .secondary)

                        Text("Streak")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(currentStreak > 0 ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                streakPill(
                    value: longestStreak,
                    label: "Best",
                    icon: "trophy.fill",
                    color: .blue,
                    isActive: longestStreak > 0
                )

                Spacer()

                // XP pills
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                        Text("\(totalXP)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary)

                    if todayXP > 0 {
                        Text("+\(todayXP) today")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.green)
                    }
                }

                // Freeze indicator
                if freezeEnabled && streakFreezesAvailable > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                        Text("\(streakFreezesAvailable)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .help("Streak freezes available")
                }
            }

            // Level progress
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)

                Text(currentTitle)
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                if let next = nextLevelTitle {
                    Text(next)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * levelProgress, 4), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private func streakPill(value: Int, label: String, icon: String, color: Color, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? color : Color.gray.opacity(0.3))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .primary : .secondary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? color.opacity(0.1) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
