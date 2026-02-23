import Foundation
import SwiftData

@Model
final class TrackedEvent {
    var eventIdentifier: String
    var taskID: UUID
    var originalStart: Date
    var originalEnd: Date
    var isActive: Bool

    init(eventIdentifier: String, taskID: UUID, originalStart: Date, originalEnd: Date) {
        self.eventIdentifier = eventIdentifier
        self.taskID = taskID
        self.originalStart = originalStart
        self.originalEnd = originalEnd
        self.isActive = true
    }
}
