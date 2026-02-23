import Foundation

struct GamificationState: Codable, Sendable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalTasksCompleted: Int = 0
    var currentLevel: Int = 1
    var lastStreakDate: Date?
    var earnedBadges: [Badge] = []

    // XP
    var totalXP: Int = 0
    var todayXP: Int = 0
    var todayXPResetDate: Date?

    // Daily Challenge
    var currentChallenge: DailyChallenge?
    var challengeDate: Date?
    var challengeStreak: Int = 0

    // Streak Freeze
    var streakFreezesAvailable: Int = 0
    var streakFreezesUsedThisWeek: Int = 0
    var lastFreezeResetDate: Date?

    var currentTitle: String {
        Self.levels[min(currentLevel - 1, Self.levels.count - 1)].title
    }

    mutating func awardXP(_ amount: Int) {
        if let resetDate = todayXPResetDate, !Calendar.current.isDateInToday(resetDate) {
            todayXP = 0
        }
        totalXP += amount
        todayXP += amount
        todayXPResetDate = Date()
    }

    mutating func recordDayCompletion(dailyRate: Double, threshold: Double, freezeEnabled: Bool = false, maxFreezes: Int = 1) {
        // Reset weekly freeze count on new week
        if freezeEnabled {
            if let lastReset = lastFreezeResetDate,
               !Calendar.current.isDate(lastReset, equalTo: Date(), toGranularity: .weekOfYear) {
                streakFreezesUsedThisWeek = 0
                streakFreezesAvailable = maxFreezes
                lastFreezeResetDate = Date()
            } else if lastFreezeResetDate == nil {
                streakFreezesAvailable = maxFreezes
                lastFreezeResetDate = Date()
            }
        }

        if dailyRate >= threshold {
            if let lastDate = lastStreakDate,
               Calendar.current.isDateInYesterday(lastDate) {
                currentStreak += 1
            } else if let lastDate = lastStreakDate,
                      Calendar.current.isDateInToday(lastDate) {
                // Already counted today
            } else {
                currentStreak = 1
            }
            lastStreakDate = Date()
            longestStreak = max(longestStreak, currentStreak)
        } else if freezeEnabled && streakFreezesAvailable > 0 {
            // Use a freeze — maintain streak but don't increment
            streakFreezesAvailable -= 1
            streakFreezesUsedThisWeek += 1
            lastStreakDate = Date()
        } else {
            currentStreak = 0
        }
        updateLevel()
    }

    mutating func recordTaskCompletion() {
        totalTasksCompleted += 1
        updateLevel()
    }

    private mutating func updateLevel() {
        for (index, level) in Self.levels.enumerated().reversed() {
            if totalTasksCompleted >= level.tasksRequired ||
                currentStreak >= level.streakRequired ||
                totalXP >= level.xpRequired {
                currentLevel = index + 1
                break
            }
        }
    }

    // MARK: - Level Definitions

    struct LevelDef: Sendable {
        let title: String
        let tasksRequired: Int
        let streakRequired: Int
        let xpRequired: Int
    }

    static let levels: [LevelDef] = [
        LevelDef(title: "Ground Control", tasksRequired: 0, streakRequired: 0, xpRequired: 0),
        LevelDef(title: "Launchpad Cadet", tasksRequired: 5, streakRequired: 0, xpRequired: 50),
        LevelDef(title: "Orbital Cadet", tasksRequired: 10, streakRequired: 3, xpRequired: 150),
        LevelDef(title: "Space Explorer", tasksRequired: 25, streakRequired: 7, xpRequired: 400),
        LevelDef(title: "Lunar Navigator", tasksRequired: 50, streakRequired: 10, xpRequired: 800),
        LevelDef(title: "Mars Voyager", tasksRequired: 100, streakRequired: 14, xpRequired: 1500),
        LevelDef(title: "Asteroid Miner", tasksRequired: 200, streakRequired: 21, xpRequired: 3000),
        LevelDef(title: "Galaxy Commander", tasksRequired: 350, streakRequired: 30, xpRequired: 5000),
        LevelDef(title: "Nebula Architect", tasksRequired: 500, streakRequired: 60, xpRequired: 8000),
        LevelDef(title: "ProcrastiNaut Legend", tasksRequired: 1000, streakRequired: 100, xpRequired: 15000),
    ]
}

// MARK: - Badge

struct Badge: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let category: BadgeCategory
    var earnedAt: Date?

    var isEarned: Bool { earnedAt != nil }

    enum BadgeCategory: String, CaseIterable, Codable, Sendable {
        case gettingStarted = "Getting Started"
        case consistency = "Consistency"
        case productivity = "Productivity"
        case mastery = "Mastery"
        case milestones = "Milestones"
    }

    static let allBadges: [Badge] = [
        // Getting Started
        Badge(id: "first_launch", name: "First Launch", description: "Complete your first task", iconName: "rocket", category: .gettingStarted),
        Badge(id: "first_perfect_day", name: "First Perfect Day", description: "Achieve 100% completion in a day", iconName: "sparkles", category: .gettingStarted),
        Badge(id: "first_week_streak", name: "First Week Streak", description: "Maintain a 7-day streak", iconName: "calendar.badge.checkmark", category: .gettingStarted),

        // Consistency
        Badge(id: "streak_saver", name: "Streak Saver", description: "Maintain a 30-day streak", iconName: "flame.fill", category: .consistency),
        Badge(id: "streak_master", name: "Streak Master", description: "Maintain a 60-day streak", iconName: "flame.circle.fill", category: .consistency),
        Badge(id: "streak_legend", name: "Streak Legend", description: "Maintain a 100-day streak", iconName: "flame.circle", category: .consistency),
        Badge(id: "perfect_week", name: "Perfect Week", description: "80%+ every day for a week", iconName: "star.circle.fill", category: .consistency),

        // Productivity
        Badge(id: "early_bird", name: "Early Bird", description: "Complete a task before 9 AM", iconName: "sunrise", category: .productivity),
        Badge(id: "night_owl", name: "Night Owl", description: "Complete a task after 5 PM", iconName: "moon.stars", category: .productivity),
        Badge(id: "marathon", name: "Marathon Runner", description: "Complete 5+ tasks in a single day", iconName: "figure.run", category: .productivity),
        Badge(id: "speed_demon", name: "Speed Demon", description: "Finish a task under its estimate", iconName: "hare", category: .productivity),

        // Mastery
        Badge(id: "estimator", name: "Estimator", description: "10 tasks within 5 min of estimate", iconName: "clock.badge.checkmark", category: .mastery),
        Badge(id: "splitter", name: "Splitter", description: "Complete a multi-block task", iconName: "rectangle.split.3x1", category: .mastery),
        Badge(id: "planner", name: "Mission Planner", description: "Use AI to schedule your tasks", iconName: "cpu", category: .mastery),
        Badge(id: "zero_inbox", name: "Zero Inbox", description: "Clear all reminders in a day", iconName: "tray", category: .mastery),

        // Milestones
        Badge(id: "tasks_10", name: "10 Tasks", description: "Complete 10 tasks total", iconName: "10.circle.fill", category: .milestones),
        Badge(id: "tasks_50", name: "50 Tasks", description: "Complete 50 tasks total", iconName: "50.circle.fill", category: .milestones),
        Badge(id: "tasks_100", name: "Centurion", description: "Complete 100 tasks total", iconName: "seal.fill", category: .milestones),
        Badge(id: "tasks_500", name: "Half Millennium", description: "Complete 500 tasks total", iconName: "medal.fill", category: .milestones),
        Badge(id: "tasks_1000", name: "Grand Master", description: "Complete 1000 tasks total", iconName: "crown.fill", category: .milestones),
    ]
}
