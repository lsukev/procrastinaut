import Foundation
import SwiftData

@MainActor
final class DurationLearningService {
    private var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Record the actual duration of a completed task
    func recordCompletion(task: ProcrastiNautTask) {
        guard let modelContext,
              let actualDuration = task.actualDuration,
              actualDuration > 0 else { return }

        // Try to find existing estimate for this list + title keywords
        let listName = task.reminderListName
        let keywords = extractKeywords(from: task.reminderTitle)

        if let existing = findEstimate(listName: listName, keywords: keywords) {
            existing.addSample(actualDuration)
        } else {
            let estimate = DurationEstimate(listName: listName, titleKeywords: keywords)
            estimate.addSample(actualDuration)
            modelContext.insert(estimate)
        }

        // Also update list-level estimate
        if let listEstimate = findEstimate(listName: listName, keywords: nil) {
            listEstimate.addSample(actualDuration)
        } else {
            let estimate = DurationEstimate(listName: listName)
            estimate.addSample(actualDuration)
            modelContext.insert(estimate)
        }

        try? modelContext.save()
    }

    /// Get estimated duration for a task based on history
    func estimateDuration(listName: String, title: String, defaultDuration: TimeInterval) -> (duration: TimeInterval, isLearned: Bool) {
        let keywords = extractKeywords(from: title)

        // Try title-keyword match first
        if let estimate = findEstimate(listName: listName, keywords: keywords),
           estimate.recentDurations.count >= 3 {
            return (estimate.averageDuration, true)
        }

        // Fall back to list-level average
        if let estimate = findEstimate(listName: listName, keywords: nil),
           estimate.recentDurations.count >= 3 {
            return (estimate.averageDuration, true)
        }

        return (defaultDuration, false)
    }

    // MARK: - Private

    private func findEstimate(listName: String, keywords: String?) -> DurationEstimate? {
        guard let modelContext else { return nil }

        let descriptor: FetchDescriptor<DurationEstimate>
        if let keywords {
            descriptor = FetchDescriptor<DurationEstimate>(
                predicate: #Predicate { $0.listName == listName && $0.titleKeywords == keywords }
            )
        } else {
            descriptor = FetchDescriptor<DurationEstimate>(
                predicate: #Predicate { $0.listName == listName && $0.titleKeywords == nil }
            )
        }

        return try? modelContext.fetch(descriptor).first
    }

    private func extractKeywords(from title: String) -> String {
        // Extract significant words (3+ characters, lowercased, sorted)
        let words = title
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 3 }
            .map { $0.lowercased() }
            .sorted()
        return words.joined(separator: " ")
    }
}
