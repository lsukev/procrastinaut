import EventKit
import Foundation

@MainActor
@Observable
final class ConflictMonitor {
    var detectedConflicts: [ConflictInfo] = []
    var currentConflict: ConflictInfo?

    private var changeObserver: NSObjectProtocol?
    private let eventKitManager = EventKitManager.shared

    struct ConflictInfo: Identifiable, Sendable {
        let id = UUID()
        let task: ProcrastiNautTask
        let conflictingEventTitle: String
        let conflictingEventStart: Date
        let conflictingEventEnd: Date
        let type: ConflictType
    }

    enum ConflictType: Sendable {
        case newOverlap        // A new event overlaps with a task block
        case eventMoved        // The ProcrastiNaut event was moved externally
        case eventDeleted      // The ProcrastiNaut event was deleted externally
    }

    var onConflictDetected: ((ConflictInfo) -> Void)?
    var onEventMoved: ((UUID, Date, Date) -> Void)?
    var onEventDeleted: ((UUID) -> Void)?

    func startMonitoring(tasks: [ProcrastiNautTask], monitoredCalendars: [EKCalendar]?) {
        stopMonitoring()

        // Capture calendar identifiers (Sendable) instead of EKCalendar objects
        let calendarIDs = monitoredCalendars?.map { $0.calendarIdentifier }

        changeObserver = eventKitManager.observeChanges { [weak self] in
            Task { @MainActor in
                // Re-fetch calendars from IDs on the main actor
                let calendars = calendarIDs?.compactMap { id in
                    EventKitManager.shared.calendar(withIdentifier: id)
                }
                self?.checkForConflicts(tasks: tasks, calendars: calendars)
            }
        }
    }

    func stopMonitoring() {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
            changeObserver = nil
        }
    }

    func checkForConflicts(tasks: [ProcrastiNautTask], calendars: [EKCalendar]?) {
        let approvedTasks = tasks.filter { $0.status == .approved || $0.status == .inProgress }

        for task in approvedTasks {
            guard let start = task.suggestedStartTime,
                  let end = task.suggestedEndTime else { continue }

            // Check for new overlapping events
            let overlaps = eventKitManager.checkForConflicts(start: start, end: end, calendars: calendars)
            for overlap in overlaps {
                let conflict = ConflictInfo(
                    task: task,
                    conflictingEventTitle: overlap.title ?? "Unknown Event",
                    conflictingEventStart: overlap.startDate,
                    conflictingEventEnd: overlap.endDate,
                    type: .newOverlap
                )
                if !detectedConflicts.contains(where: { $0.task.id == task.id }) {
                    detectedConflicts.append(conflict)
                    onConflictDetected?(conflict)
                    SystemNotificationService.shared.scheduleConflictAlert(
                        event1Title: task.reminderTitle,
                        event2Title: conflict.conflictingEventTitle,
                        overlapTime: conflict.conflictingEventStart
                    )
                }
            }

            // Check if our event was moved or deleted
            if let eventID = task.calendarEventIdentifier {
                if let event = eventKitManager.event(withIdentifier: eventID) {
                    // Event still exists — check if moved
                    if event.startDate != start || event.endDate != end {
                        onEventMoved?(task.id, event.startDate, event.endDate)
                    }
                } else {
                    // Event was deleted externally
                    onEventDeleted?(task.id)
                }
            }
        }
    }

    func dismissConflict(_ conflictID: UUID) {
        detectedConflicts.removeAll { $0.id == conflictID }
        if currentConflict?.id == conflictID {
            currentConflict = nil
        }
    }
}
