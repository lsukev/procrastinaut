import Foundation
import SwiftData

@Model
final class TimeOfDayPreference {
    var listName: String
    var titleKeywords: String?
    var morningScore: Double
    var afternoonScore: Double
    var eveningScore: Double
    var sampleCount: Int
    var lastUpdated: Date

    init(listName: String, titleKeywords: String? = nil) {
        self.listName = listName
        self.titleKeywords = titleKeywords
        self.morningScore = 0
        self.afternoonScore = 0
        self.eveningScore = 0
        self.sampleCount = 0
        self.lastUpdated = Date()
    }

    /// Record a successful completion at the given hour
    func recordSuccess(hour: Int) {
        let period = timePeriod(for: hour)
        switch period {
        case .morning: morningScore += 1
        case .afternoon: afternoonScore += 1
        case .evening: eveningScore += 1
        }
        sampleCount += 1
        lastUpdated = Date()
    }

    /// Record a failure at the given hour — penalize this period, boost others
    func recordFailure(hour: Int, reason: RescheduleReason) {
        let period = timePeriod(for: hour)
        switch period {
        case .morning:
            morningScore -= 1
            afternoonScore += 0.5
            eveningScore += 0.5
        case .afternoon:
            afternoonScore -= 1
            morningScore += 0.5
            eveningScore += 0.5
        case .evening:
            eveningScore -= 1
            morningScore += 0.5
            afternoonScore += 0.5
        }
        sampleCount += 1
        lastUpdated = Date()
    }

    /// Returns the best time period as an hour range, or nil if insufficient data
    func bestPeriod() -> (start: Int, end: Int)? {
        guard sampleCount >= 3 else { return nil }

        let scores = [
            (morningScore, 6, 12),
            (afternoonScore, 12, 17),
            (eveningScore, 17, 21),
        ]
        guard let best = scores.max(by: { $0.0 < $1.0 }) else { return nil }
        return (start: best.1, end: best.2)
    }

    /// Score for a specific hour — higher means better fit
    func score(forHour hour: Int) -> Double {
        let period = timePeriod(for: hour)
        switch period {
        case .morning: return morningScore
        case .afternoon: return afternoonScore
        case .evening: return eveningScore
        }
    }

    // MARK: - Private

    private enum TimePeriod {
        case morning, afternoon, evening
    }

    private func timePeriod(for hour: Int) -> TimePeriod {
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }
}
