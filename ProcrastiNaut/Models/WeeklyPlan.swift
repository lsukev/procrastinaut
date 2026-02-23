import Foundation

struct WeeklyPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let weekStartDate: Date
    var dayPlans: [DailyPlan]
    var unassignedTasks: [ProcrastiNautTask]
    var createdAt: Date

    init(weekStartDate: Date) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.dayPlans = []
        self.unassignedTasks = []
        self.createdAt = Date()
    }
}
