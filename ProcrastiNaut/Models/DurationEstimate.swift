import Foundation
import SwiftData

@Model
final class DurationEstimate {
    var listName: String
    var titleKeywords: String?
    var recentDurations: [Double]
    var averageDuration: Double
    var lastUpdated: Date

    init(listName: String, titleKeywords: String? = nil) {
        self.listName = listName
        self.titleKeywords = titleKeywords
        self.recentDurations = []
        self.averageDuration = 0
        self.lastUpdated = Date()
    }

    func addSample(_ duration: Double) {
        recentDurations.append(duration)
        if recentDurations.count > 20 {
            recentDurations.removeFirst()
        }
        averageDuration = recentDurations.reduce(0, +) / Double(recentDurations.count)
        lastUpdated = Date()
    }
}
