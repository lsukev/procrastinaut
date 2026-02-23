import Foundation
import SwiftData

@Model
final class GamificationRecord {
    var currentStreak: Int
    var longestStreak: Int
    var totalTasksCompleted: Int
    var currentLevel: Int
    var lastStreakDate: Date?
    var earnedBadgeIDs: [String]

    // XP
    var totalXP: Int
    var todayXP: Int
    var todayXPResetDate: Date?

    // Daily Challenge
    var currentChallengeID: String?
    var challengeDate: Date?
    var challengeStreak: Int
    var challengeCompleted: Bool

    // Streak Freeze
    var streakFreezesAvailable: Int
    var streakFreezesUsedThisWeek: Int
    var lastFreezeResetDate: Date?

    init() {
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalTasksCompleted = 0
        self.currentLevel = 1
        self.lastStreakDate = nil
        self.earnedBadgeIDs = []
        self.totalXP = 0
        self.todayXP = 0
        self.todayXPResetDate = nil
        self.currentChallengeID = nil
        self.challengeDate = nil
        self.challengeStreak = 0
        self.challengeCompleted = false
        self.streakFreezesAvailable = 0
        self.streakFreezesUsedThisWeek = 0
        self.lastFreezeResetDate = nil
    }

    /// Convert to the value-type GamificationState for use in the UI
    func toState() -> GamificationState {
        var state = GamificationState()
        state.currentStreak = currentStreak
        state.longestStreak = longestStreak
        state.totalTasksCompleted = totalTasksCompleted
        state.currentLevel = currentLevel
        state.lastStreakDate = lastStreakDate
        state.earnedBadges = Badge.allBadges.map { badge in
            var b = badge
            if earnedBadgeIDs.contains(badge.id) {
                b.earnedAt = Date()
            }
            return b
        }

        // XP
        state.totalXP = totalXP
        state.todayXP = todayXP
        state.todayXPResetDate = todayXPResetDate

        // Daily Challenge
        if let challengeID = currentChallengeID,
           var challenge = DailyChallenge.catalog.first(where: { $0.id == challengeID }) {
            challenge.isCompleted = challengeCompleted
            state.currentChallenge = challenge
        }
        state.challengeDate = challengeDate
        state.challengeStreak = challengeStreak

        // Streak Freeze
        state.streakFreezesAvailable = streakFreezesAvailable
        state.streakFreezesUsedThisWeek = streakFreezesUsedThisWeek
        state.lastFreezeResetDate = lastFreezeResetDate

        return state
    }

    /// Update from a GamificationState
    func update(from state: GamificationState) {
        currentStreak = state.currentStreak
        longestStreak = state.longestStreak
        totalTasksCompleted = state.totalTasksCompleted
        currentLevel = state.currentLevel
        lastStreakDate = state.lastStreakDate
        earnedBadgeIDs = state.earnedBadges.filter { $0.isEarned }.map(\.id)

        // XP
        totalXP = state.totalXP
        todayXP = state.todayXP
        todayXPResetDate = state.todayXPResetDate

        // Daily Challenge
        currentChallengeID = state.currentChallenge?.id
        challengeDate = state.challengeDate
        challengeStreak = state.challengeStreak
        challengeCompleted = state.currentChallenge?.isCompleted ?? false

        // Streak Freeze
        streakFreezesAvailable = state.streakFreezesAvailable
        streakFreezesUsedThisWeek = state.streakFreezesUsedThisWeek
        lastFreezeResetDate = state.lastFreezeResetDate
    }
}
