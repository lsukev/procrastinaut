import Foundation
import SwiftData

struct SchedulingInsight: Identifiable, Sendable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let category: InsightCategory

    enum InsightCategory: String, Sendable {
        case duration, timing, priority, interruption
    }
}

@MainActor
@Observable
final class RescheduleLearningEngine {
    private var modelContext: ModelContext?
    var latestInsight: SchedulingInsight?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Recording

    func recordReschedule(task: ProcrastiNautTask, reason: RescheduleReason) {
        guard let modelContext else { return }

        let cal = Calendar.current
        let hour = task.suggestedStartTime.map { cal.component(.hour, from: $0) } ?? 12
        let dayOfWeek = cal.component(.weekday, from: Date())

        let event = RescheduleEvent(
            taskID: task.id,
            reminderTitle: task.reminderTitle,
            reminderListName: task.reminderListName,
            reason: reason,
            scheduledStart: task.suggestedStartTime ?? Date(),
            scheduledEnd: task.suggestedEndTime ?? Date(),
            scheduledDuration: task.suggestedDuration,
            hourOfDay: hour,
            dayOfWeek: dayOfWeek
        )
        modelContext.insert(event)

        // Update time-of-day preferences
        if reason == .badTime {
            let pref = findOrCreatePreference(
                listName: task.reminderListName,
                title: task.reminderTitle
            )
            pref.recordFailure(hour: hour, reason: reason)
        }

        try? modelContext.save()
    }

    func recordCompletion(task: ProcrastiNautTask) {
        guard let modelContext else { return }

        let cal = Calendar.current
        let hour = task.suggestedStartTime.map { cal.component(.hour, from: $0) } ?? 12

        let pref = findOrCreatePreference(
            listName: task.reminderListName,
            title: task.reminderTitle
        )
        pref.recordSuccess(hour: hour)

        try? modelContext.save()
    }

    // MARK: - Query Methods (for SuggestionEngine)

    /// Returns adjusted duration based on "too long" history
    func durationAdjustment(listName: String, title: String, baseDuration: TimeInterval) -> TimeInterval {
        let count = countEvents(listName: listName, title: title, reason: .tooLong)

        if count >= 3 {
            return min(baseDuration * 1.5, baseDuration * 2) // 50% increase, capped at 2x
        } else if count >= 2 {
            return baseDuration * 1.25 // 25% increase
        }
        return baseDuration
    }

    /// Returns time-of-day score for a given hour — higher means better fit
    func timeOfDayScore(listName: String, title: String, hour: Int) -> Double {
        let keywords = extractKeywords(from: title)

        // Try keyword-specific preference first
        if let pref = findPreference(listName: listName, keywords: keywords),
           pref.sampleCount >= 3 {
            return pref.score(forHour: hour)
        }

        // Fall back to list-level preference
        if let pref = findPreference(listName: listName, keywords: nil),
           pref.sampleCount >= 3 {
            return pref.score(forHour: hour)
        }

        return 0 // No data
    }

    /// Whether this task should be split into smaller blocks
    func shouldSplit(listName: String, title: String, duration: TimeInterval) -> Bool {
        guard duration > 30 * 60 else { return false } // Only split if > 30 min
        let count = countEvents(listName: listName, title: title, reason: .interrupted)
        return count >= 2
    }

    /// Priority penalty for tasks frequently marked "not important"
    func priorityPenalty(listName: String, title: String) -> Double {
        let count = countEvents(listName: listName, title: title, reason: .notImportant)
        if count >= 3 { return -0.5 }
        return 0
    }

    /// Extra buffer recommendation for frequently interrupted tasks
    func bufferRecommendation(listName: String, title: String) -> TimeInterval {
        let count = countEvents(listName: listName, title: title, reason: .interrupted)
        if count >= 3 { return 10 * 60 } // +10 min
        if count >= 2 { return 5 * 60 }  // +5 min
        return 0
    }

    // MARK: - Insights

    func generateInsights(listName: String? = nil, limit: Int = 3) -> [SchedulingInsight] {
        guard let modelContext else { return [] }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let descriptor: FetchDescriptor<RescheduleEvent>
        if let listName {
            descriptor = FetchDescriptor<RescheduleEvent>(
                predicate: #Predicate { $0.occurredAt >= thirtyDaysAgo && $0.reminderListName == listName },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<RescheduleEvent>(
                predicate: #Predicate { $0.occurredAt >= thirtyDaysAgo },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        }

        guard let events = try? modelContext.fetch(descriptor), !events.isEmpty else { return [] }

        var insights: [SchedulingInsight] = []

        // Group by reason
        let reasonCounts = Dictionary(grouping: events) { $0.rescheduleReason }

        // Too Long insight
        if let tooLongEvents = reasonCounts[.tooLong], tooLongEvents.count >= 2 {
            let titles = Set(tooLongEvents.map { $0.reminderTitle })
            let topTitle = titles.count == 1
                ? "\"\(titles.first!)\""
                : "\(titles.count) different tasks"
            insights.append(SchedulingInsight(
                id: UUID(),
                icon: "clock.badge.exclamationmark",
                title: "Duration Underestimates",
                description: "\(topTitle) marked 'Too Long' \(tooLongEvents.count) times. Duration estimates have been increased.",
                category: .duration
            ))
        }

        // Bad Time insight
        if let badTimeEvents = reasonCounts[.badTime], badTimeEvents.count >= 2 {
            let avgHour = badTimeEvents.map(\.hourOfDay).reduce(0, +) / badTimeEvents.count
            let period = avgHour < 12 ? "morning" : (avgHour < 17 ? "afternoon" : "evening")
            insights.append(SchedulingInsight(
                id: UUID(),
                icon: "clock.arrow.circlepath",
                title: "Timing Patterns",
                description: "Tasks in the \(period) are often marked 'Bad Time'. Scheduling is adjusting to preferred times.",
                category: .timing
            ))
        }

        // Interrupted insight
        if let interruptedEvents = reasonCounts[.interrupted], interruptedEvents.count >= 2 {
            let longTasks = interruptedEvents.filter { $0.scheduledDuration > 30 * 60 }
            if !longTasks.isEmpty {
                insights.append(SchedulingInsight(
                    id: UUID(),
                    icon: "hand.raised",
                    title: "Interruption Prone",
                    description: "Longer tasks are frequently interrupted. Consider splitting them into smaller blocks.",
                    category: .interruption
                ))
            }
        }

        // Not Important insight
        if let notImportantEvents = reasonCounts[.notImportant], notImportantEvents.count >= 3 {
            insights.append(SchedulingInsight(
                id: UUID(),
                icon: "arrow.down.circle",
                title: "Low Priority Tasks",
                description: "\(notImportantEvents.count) tasks marked 'Not Important'. These are being deprioritized.",
                category: .priority
            ))
        }

        return Array(insights.prefix(limit))
    }

    // MARK: - Private Helpers

    private func countEvents(listName: String, title: String, reason: RescheduleReason) -> Int {
        guard let modelContext else { return 0 }

        let keywords = extractKeywords(from: title)
        let reasonStr = reason.rawValue
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // Count events matching this list + similar title keywords + reason in last 30 days
        let descriptor = FetchDescriptor<RescheduleEvent>(
            predicate: #Predicate {
                $0.reminderListName == listName &&
                $0.reason == reasonStr &&
                $0.occurredAt >= thirtyDaysAgo
            }
        )

        guard let events = try? modelContext.fetch(descriptor) else { return 0 }

        // Filter by keyword similarity
        return events.filter { event in
            let eventKeywords = extractKeywords(from: event.reminderTitle)
            return eventKeywords == keywords || event.reminderTitle == title
        }.count
    }

    private func findOrCreatePreference(listName: String, title: String) -> TimeOfDayPreference {
        let keywords = extractKeywords(from: title)

        if let existing = findPreference(listName: listName, keywords: keywords) {
            return existing
        }

        let pref = TimeOfDayPreference(listName: listName, titleKeywords: keywords)
        modelContext?.insert(pref)
        return pref
    }

    private func findPreference(listName: String, keywords: String?) -> TimeOfDayPreference? {
        guard let modelContext else { return nil }

        let descriptor: FetchDescriptor<TimeOfDayPreference>
        if let keywords {
            descriptor = FetchDescriptor<TimeOfDayPreference>(
                predicate: #Predicate { $0.listName == listName && $0.titleKeywords == keywords }
            )
        } else {
            descriptor = FetchDescriptor<TimeOfDayPreference>(
                predicate: #Predicate { $0.listName == listName && $0.titleKeywords == nil }
            )
        }

        return try? modelContext.fetch(descriptor).first
    }

    /// Extract significant words from title (same pattern as DurationLearningService)
    private func extractKeywords(from title: String) -> String {
        let words = title
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 3 }
            .map { $0.lowercased() }
            .sorted()
        return words.joined(separator: " ")
    }
}
