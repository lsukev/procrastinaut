import Foundation
import SwiftData

@MainActor
@Observable
final class GamificationEngine {
    var state = GamificationState()

    /// Published when a badge is earned or a level-up occurs; UI observes this to show toast/confetti.
    var lastAchievement: AchievementEvent?

    /// Set when XP is awarded so the UI can show a floating "+N XP" animation.
    var lastXPGain: Int?

    private let settings = UserSettings.shared
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadState()
        selectDailyChallenge()
    }

    // MARK: - XP Constants

    private enum XPReward {
        static let taskComplete = 10
        static let highPriorityBonus = 5
        static let earlyCompletionBonus = 3
        static let perfectDayBonus = 25
        static let challengeComplete = 20
        static let streakMultiplierPer5Days = 0.1  // +10% per 5 streak days, capped at 2x
    }

    // MARK: - Task Completion

    func recordTaskCompleted(at time: Date = Date(), task: ProcrastiNautTask? = nil) {
        guard settings.showCompletionStats else { return }

        let oldLevel = state.currentLevel
        state.recordTaskCompletion()

        // Calculate XP
        var xp = XPReward.taskComplete
        if let task {
            if task.priority == .high { xp += XPReward.highPriorityBonus }
            if let endTime = task.suggestedEndTime, time < endTime {
                xp += XPReward.earlyCompletionBonus
            }
        }
        // Streak multiplier: +10% per 5 streak days, capped at 2x
        let multiplier = 1.0 + min(1.0, Double(state.currentStreak / 5) * XPReward.streakMultiplierPer5Days)
        xp = Int(Double(xp) * multiplier)

        state.awardXP(xp)
        lastXPGain = xp

        checkBadges(completionTime: time, task: task)
        checkLevelUp(oldLevel: oldLevel)
        saveState()
    }

    func recordDayEnd(plan: DailyPlan) {
        guard settings.enableStreaks else { return }

        let oldLevel = state.currentLevel
        state.recordDayCompletion(
            dailyRate: plan.completionRate,
            threshold: settings.streakThreshold,
            freezeEnabled: settings.enableStreakFreeze,
            maxFreezes: settings.maxFreezesPerWeek
        )
        checkDayBadges(plan: plan)

        // Perfect day XP bonus
        if plan.completionRate >= 1.0 && !plan.tasks.isEmpty {
            state.awardXP(XPReward.perfectDayBonus)
            lastXPGain = XPReward.perfectDayBonus
        }

        // Check daily challenge progress
        checkChallengeProgress(plan: plan)

        checkLevelUp(oldLevel: oldLevel)
        saveState()
    }

    func recordMultiBlockCompleted() {
        awardBadge("splitter")
    }

    func recordAIUsed() {
        awardBadge("planner")
    }

    func recordSpeedCompletion() {
        awardBadge("speed_demon")
    }

    // MARK: - Badge Checks

    private func checkBadges(completionTime: Date, task: ProcrastiNautTask? = nil) {
        // First Launch
        if state.totalTasksCompleted >= 1 {
            awardBadge("first_launch")
        }

        // Early Bird — before 9 AM
        let hour = Calendar.current.component(.hour, from: completionTime)
        if hour < 9 {
            awardBadge("early_bird")
        }

        // Night Owl — after 5 PM
        if hour >= 17 {
            awardBadge("night_owl")
        }

        // Streak tiers
        if state.currentStreak >= 7 { awardBadge("first_week_streak") }
        if state.currentStreak >= 30 { awardBadge("streak_saver") }
        if state.currentStreak >= 60 { awardBadge("streak_master") }
        if state.currentStreak >= 100 { awardBadge("streak_legend") }

        // Milestone badges
        let milestones: [(Int, String)] = [
            (10, "tasks_10"), (50, "tasks_50"), (100, "tasks_100"),
            (500, "tasks_500"), (1000, "tasks_1000"),
        ]
        for (count, id) in milestones {
            if state.totalTasksCompleted >= count { awardBadge(id) }
        }

        // Speed Demon — finished before estimate
        if let task, let endTime = task.suggestedEndTime, completionTime < endTime {
            awardBadge("speed_demon")
        }
    }

    private func checkDayBadges(plan: DailyPlan) {
        // Perfect Day
        if plan.completionRate >= 1.0 && !plan.tasks.isEmpty {
            awardBadge("perfect_day")
            awardBadge("first_perfect_day")
        }

        // Marathon — 5+ tasks in a day
        if plan.completedCount >= 5 {
            awardBadge("marathon")
        }

        // Perfect Week
        if state.currentStreak >= 7 {
            awardBadge("perfect_week")
        }

        // Zero Inbox — all tasks completed
        if !plan.tasks.isEmpty && plan.tasks.allSatisfy({ $0.status == .completed }) {
            awardBadge("zero_inbox")
        }
    }

    func recordAccurateEstimate() {
        awardBadge("estimator")
    }

    private func awardBadge(_ badgeID: String) {
        guard let index = state.earnedBadges.firstIndex(where: { $0.id == badgeID }),
              !state.earnedBadges[index].isEarned else { return }

        state.earnedBadges[index].earnedAt = Date()

        let badge = state.earnedBadges[index]
        lastAchievement = AchievementEvent(
            type: .badge(badge),
            title: badge.name,
            description: badge.description,
            iconName: badge.iconName
        )

        saveState()
    }

    private func checkLevelUp(oldLevel: Int) {
        if state.currentLevel > oldLevel {
            let title = state.currentTitle
            lastAchievement = AchievementEvent(
                type: .levelUp(newLevel: state.currentLevel, title: title),
                title: "Level Up!",
                description: title,
                iconName: "arrow.up.circle.fill"
            )
        }
    }

    // MARK: - Daily Challenges

    func selectDailyChallenge() {
        // If already selected today, skip
        if let date = state.challengeDate, Calendar.current.isDateInToday(date) { return }

        // Deterministic selection based on date so reopening app gives same challenge
        let daysSinceEpoch = Int(Date().timeIntervalSince1970 / 86400)
        let index = daysSinceEpoch % DailyChallenge.catalog.count
        var challenge = DailyChallenge.catalog[index]
        challenge.isCompleted = false
        state.currentChallenge = challenge
        state.challengeDate = Date()
        saveState()
    }

    func checkChallengeProgress(plan: DailyPlan) {
        guard var challenge = state.currentChallenge, !challenge.isCompleted else { return }

        let completed: Bool
        switch challenge.type {
        case .completeCount(let target):
            completed = plan.completedCount >= target
        case .completeBeforeTime(let hour):
            completed = plan.tasks.contains { task in
                task.status == .completed &&
                    (task.completedAt.map { Calendar.current.component(.hour, from: $0) < hour } ?? false)
            }
        case .completeAllHighPriority:
            let highPriority = plan.tasks.filter { $0.priority == .high }
            completed = !highPriority.isEmpty && highPriority.allSatisfy { $0.status == .completed }
        case .perfectDay:
            completed = plan.completionRate >= 1.0 && !plan.tasks.isEmpty
        case .noReschedules:
            completed = !plan.tasks.isEmpty &&
                plan.tasks.filter({ $0.status == .completed }).count > 0 &&
                plan.tasks.allSatisfy({ $0.rescheduleCount == 0 })
        }

        if completed {
            challenge.isCompleted = true
            state.currentChallenge = challenge
            state.awardXP(challenge.xpReward)
            state.challengeStreak += 1
            lastXPGain = challenge.xpReward

            lastAchievement = AchievementEvent(
                type: .challengeComplete,
                title: "Challenge Complete!",
                description: challenge.title,
                iconName: challenge.iconName
            )
            saveState()
        }
    }

    // MARK: - Persistence

    private func loadState() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<GamificationRecord>()
        if let record = try? context.fetch(descriptor).first {
            state = record.toState()
        } else {
            // Initialize with all badges (unearned)
            state.earnedBadges = Badge.allBadges
        }
    }

    private func saveState() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<GamificationRecord>()
        let record: GamificationRecord
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = GamificationRecord()
            context.insert(record)
        }
        record.update(from: state)
        try? context.save()
    }

    // MARK: - Display Helpers

    var levelProgress: Double {
        let currentLevelIndex = state.currentLevel - 1
        guard currentLevelIndex < GamificationState.levels.count - 1 else { return 1.0 }

        let current = GamificationState.levels[currentLevelIndex]
        let next = GamificationState.levels[currentLevelIndex + 1]

        let taskProgress = Double(state.totalTasksCompleted - current.tasksRequired) /
            Double(max(1, next.tasksRequired - current.tasksRequired))

        return min(1.0, max(0.0, taskProgress))
    }

    var nextLevelTitle: String? {
        let nextIndex = state.currentLevel
        guard nextIndex < GamificationState.levels.count else { return nil }
        return GamificationState.levels[nextIndex].title
    }

    var earnedBadgeCount: Int {
        state.earnedBadges.filter { $0.isEarned }.count
    }
}

// MARK: - Achievement Event

struct AchievementEvent: Identifiable {
    let id = UUID()
    let type: AchievementType
    let title: String
    let description: String
    let iconName: String

    enum AchievementType {
        case badge(Badge)
        case levelUp(newLevel: Int, title: String)
        case challengeComplete
    }
}
