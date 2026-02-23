import Foundation
import SwiftData

@Model
final class TaskRecord {
    var taskID: UUID
    var reminderTitle: String
    var reminderListName: String
    var scheduledDate: Date
    var scheduledStart: Date
    var scheduledEnd: Date
    var status: String
    var rescheduleCount: Int
    var completedAt: Date?
    var actualDuration: Double?
    var blockIndex: Int?
    var totalBlocks: Int?
    var rescheduleReason: String?
    var isArchived: Bool
    var archivedAt: Date?

    init(
        taskID: UUID,
        reminderTitle: String,
        reminderListName: String,
        scheduledDate: Date,
        scheduledStart: Date,
        scheduledEnd: Date,
        status: TaskStatus,
        rescheduleCount: Int = 0,
        completedAt: Date? = nil,
        actualDuration: Double? = nil,
        blockIndex: Int? = nil,
        totalBlocks: Int? = nil
    ) {
        self.taskID = taskID
        self.reminderTitle = reminderTitle
        self.reminderListName = reminderListName
        self.scheduledDate = scheduledDate
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.status = status.rawValue
        self.rescheduleCount = rescheduleCount
        self.completedAt = completedAt
        self.actualDuration = actualDuration
        self.blockIndex = blockIndex
        self.totalBlocks = totalBlocks
        self.isArchived = false
        self.archivedAt = nil
    }

    var taskStatus: TaskStatus {
        get { TaskStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
}
