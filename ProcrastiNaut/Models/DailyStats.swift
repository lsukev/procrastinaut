import Foundation
import SwiftData

@Model
final class DailyStats {
    var date: Date
    var totalSuggested: Int
    var totalApproved: Int
    var totalCompleted: Int
    var totalRescheduled: Int
    var totalSkipped: Int
    var totalPartial: Int
    var completionRate: Double
    var scanTypeRaw: String
    var isArchived: Bool
    var archivedAt: Date?

    init(
        date: Date,
        totalSuggested: Int = 0,
        totalApproved: Int = 0,
        totalCompleted: Int = 0,
        totalRescheduled: Int = 0,
        totalSkipped: Int = 0,
        totalPartial: Int = 0,
        completionRate: Double = 0,
        scanType: ScanType = .manual
    ) {
        self.date = date
        self.totalSuggested = totalSuggested
        self.totalApproved = totalApproved
        self.totalCompleted = totalCompleted
        self.totalRescheduled = totalRescheduled
        self.totalSkipped = totalSkipped
        self.totalPartial = totalPartial
        self.completionRate = completionRate
        self.scanTypeRaw = scanType.rawValue
        self.isArchived = false
        self.archivedAt = nil
    }

    var scanType: ScanType {
        get { ScanType(rawValue: scanTypeRaw) ?? .manual }
        set { scanTypeRaw = newValue.rawValue }
    }
}
