import Foundation
import SwiftData

enum RescheduleReason: String, Codable, CaseIterable, Sendable {
    case tooLong = "too_long"
    case badTime = "bad_time"
    case interrupted = "interrupted"
    case notImportant = "not_important"

    var displayName: String {
        switch self {
        case .tooLong: "Too Long"
        case .badTime: "Bad Time"
        case .interrupted: "Interrupted"
        case .notImportant: "Not Important"
        }
    }

    var icon: String {
        switch self {
        case .tooLong: "clock.badge.exclamationmark"
        case .badTime: "clock.arrow.circlepath"
        case .interrupted: "hand.raised"
        case .notImportant: "arrow.down.circle"
        }
    }

    var learningAction: String {
        switch self {
        case .tooLong: "Increase duration estimate"
        case .badTime: "Schedule at a different time"
        case .interrupted: "Add buffer or split task"
        case .notImportant: "Deprioritize in scheduling"
        }
    }
}

@Model
final class RescheduleEvent {
    var eventID: UUID
    var taskID: UUID
    var reminderTitle: String
    var reminderListName: String
    var reason: String
    var scheduledStart: Date
    var scheduledEnd: Date
    var scheduledDuration: Double
    var hourOfDay: Int
    var dayOfWeek: Int
    var occurredAt: Date

    init(
        taskID: UUID,
        reminderTitle: String,
        reminderListName: String,
        reason: RescheduleReason,
        scheduledStart: Date,
        scheduledEnd: Date,
        scheduledDuration: Double,
        hourOfDay: Int,
        dayOfWeek: Int
    ) {
        self.eventID = UUID()
        self.taskID = taskID
        self.reminderTitle = reminderTitle
        self.reminderListName = reminderListName
        self.reason = reason.rawValue
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.scheduledDuration = scheduledDuration
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
        self.occurredAt = Date()
    }

    var rescheduleReason: RescheduleReason {
        get { RescheduleReason(rawValue: reason) ?? .notImportant }
        set { reason = newValue.rawValue }
    }
}
