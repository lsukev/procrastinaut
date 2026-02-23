import Foundation

struct DailyPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    var tasks: [ProcrastiNautTask]
    var scanCompletedAt: Date?
    var scanType: ScanType

    var completionRate: Double {
        let completed = tasks.filter { $0.status == .completed }.count
        return tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count)
    }

    var approvedCount: Int {
        tasks.filter { $0.status == .approved || $0.status == .inProgress }.count
    }

    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    var pendingCount: Int {
        tasks.filter { $0.status == .pending }.count
    }

    init(date: Date, scanType: ScanType = .manual) {
        self.id = UUID()
        self.date = date
        self.tasks = []
        self.scanCompletedAt = nil
        self.scanType = scanType
    }
}

enum ScanType: String, Codable, Sendable {
    case scheduled
    case wakeFromSleep
    case manual
    case lateDay
}
