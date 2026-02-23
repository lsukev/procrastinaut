import Foundation

struct DailyChallenge: Codable, Sendable, Identifiable {
    var id: String
    let title: String
    let description: String
    let iconName: String
    let type: ChallengeType
    let xpReward: Int
    var isCompleted: Bool = false

    enum ChallengeType: Codable, Sendable {
        case completeCount(Int)
        case completeBeforeTime(hour: Int)
        case completeAllHighPriority
        case perfectDay
        case noReschedules
    }

    static let catalog: [DailyChallenge] = [
        DailyChallenge(
            id: "orbital_velocity",
            title: "Orbital Velocity",
            description: "Complete 3 tasks today",
            iconName: "circle.circle.fill",
            type: .completeCount(3),
            xpReward: 15
        ),
        DailyChallenge(
            id: "morning_launch",
            title: "Morning Launch",
            description: "Complete a task before noon",
            iconName: "sunrise.fill",
            type: .completeBeforeTime(hour: 12),
            xpReward: 15
        ),
        DailyChallenge(
            id: "mission_critical",
            title: "Mission Critical",
            description: "Complete all high-priority tasks",
            iconName: "exclamationmark.triangle.fill",
            type: .completeAllHighPriority,
            xpReward: 25
        ),
        DailyChallenge(
            id: "perfect_orbit",
            title: "Perfect Orbit",
            description: "Achieve 100% daily completion",
            iconName: "circle.badge.checkmark.fill",
            type: .perfectDay,
            xpReward: 30
        ),
        DailyChallenge(
            id: "steady_course",
            title: "Steady Course",
            description: "Complete tasks with zero reschedules",
            iconName: "arrow.forward",
            type: .noReschedules,
            xpReward: 20
        ),
        DailyChallenge(
            id: "double_burn",
            title: "Double Burn",
            description: "Complete 2 tasks before 10 AM",
            iconName: "flame",
            type: .completeBeforeTime(hour: 10),
            xpReward: 20
        ),
        DailyChallenge(
            id: "full_throttle",
            title: "Full Throttle",
            description: "Complete 5 tasks in a single day",
            iconName: "bolt.fill",
            type: .completeCount(5),
            xpReward: 25
        ),
        DailyChallenge(
            id: "warp_speed",
            title: "Warp Speed",
            description: "Complete 7 tasks today",
            iconName: "hare.fill",
            type: .completeCount(7),
            xpReward: 30
        ),
    ]
}
