import SwiftUI

struct DailyChallengeView: View {
    let challenge: DailyChallenge

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(challenge.isCompleted
                        ? Color.green.opacity(0.15)
                        : Color.purple.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : challenge.iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(challenge.isCompleted ? .green : .purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Daily Challenge")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.purple.opacity(0.8))
                        .textCase(.uppercase)

                    Spacer()

                    Text("+\(challenge.xpReward) XP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(challenge.isCompleted ? .green : .purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (challenge.isCompleted ? Color.green : Color.purple)
                                .opacity(0.1)
                        )
                        .clipShape(Capsule())
                }

                Text(challenge.title)
                    .font(.system(size: 12, weight: .semibold))
                    .strikethrough(challenge.isCompleted)

                Text(challenge.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(challenge.isCompleted ? Color.green.opacity(0.05) : Color.purple.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    challenge.isCompleted ? Color.green.opacity(0.2) : Color.purple.opacity(0.15),
                    lineWidth: 0.5
                )
        )
    }
}
