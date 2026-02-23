import SwiftUI

struct BadgesView: View {
    let badges: [Badge]

    private var groupedBadges: [(Badge.BadgeCategory, [Badge])] {
        Badge.BadgeCategory.allCases.compactMap { category in
            let categoryBadges = badges.filter { $0.category == category }
            return categoryBadges.isEmpty ? nil : (category, categoryBadges)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Badges")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                let earned = badges.filter(\.isEarned).count
                Text("\(earned)/\(badges.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // Recently earned (last 7 days)
            let recentBadges = badges.filter { badge in
                guard let earnedAt = badge.earnedAt else { return false }
                return earnedAt.timeIntervalSinceNow > -7 * 86400
            }
            if !recentBadges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recently Earned")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.yellow)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recentBadges) { badge in
                                badgeCell(badge, isRecent: true)
                            }
                        }
                    }
                }
            }

            // All badges by category
            ForEach(groupedBadges, id: \.0) { category, categoryBadges in
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categoryBadges) { badge in
                                badgeCell(badge, isRecent: false)
                            }
                        }
                    }
                }
            }
        }
    }

    private func badgeCell(_ badge: Badge, isRecent: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(badge.isEarned
                        ? LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)

                if isRecent && badge.isEarned {
                    Circle()
                        .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: badge.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(badge.isEarned ? Color.yellow : Color.gray.opacity(0.3))
            }

            Text(badge.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .foregroundStyle(badge.isEarned ? .primary : .tertiary)
        }
        .frame(width: 56)
        .help(badge.description)
    }
}
