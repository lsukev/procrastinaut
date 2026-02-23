import Foundation

struct ProcrastiNautTask: Identifiable, Codable, Sendable {
    let id: UUID
    let reminderIdentifier: String
    let reminderTitle: String
    let reminderListName: String
    let priority: TaskPriority
    let dueDate: Date?
    let reminderNotes: String?
    let reminderURL: URL?
    let energyRequirement: EnergyLevel

    var suggestedStartTime: Date?
    var suggestedEndTime: Date?
    var suggestedDuration: TimeInterval
    var blockIndex: Int?
    var totalBlocks: Int?

    var status: TaskStatus
    var calendarEventIdentifier: String?

    var rescheduleCount: Int = 0
    var lastRescheduleReason: RescheduleReason?
    var remainingDuration: TimeInterval?
    var createdAt: Date
    var completedAt: Date?
    var actualDuration: TimeInterval?
}

enum TaskStatus: String, Codable, Sendable {
    case pending
    case approved
    case inProgress
    case awaitingReview
    case completed
    case partiallyDone
    case rescheduled
    case skipped
    case cancelled
    case conflicted
}

enum TaskPriority: Int, Codable, Comparable, Sendable {
    case high = 1
    case medium = 5
    case low = 9
    case none = 99

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Convert from EKReminder priority (0=none, 1-4=high, 5=medium, 6-9=low)
    static func from(ekPriority: Int) -> TaskPriority {
        switch ekPriority {
        case 1...4: return .high
        case 5: return .medium
        case 6...9: return .low
        default: return .none
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable, Sendable {
    case highFocus = "high_focus"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .highFocus: "High Focus"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    var symbol: String {
        switch self {
        case .highFocus: "bolt.fill"
        case .medium: "bolt"
        case .low: "bolt.slash"
        }
    }
}
