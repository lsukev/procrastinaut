import EventKit
import Foundation

@MainActor
@Observable
final class OverrunMonitor {
    var showingWarning = false
    var warningTask: ProcrastiNautTask?
    var nextEventTitle: String?
    var minutesRemaining: Int = 0

    private var warningTimer: Timer?
    private let eventKitManager = EventKitManager.shared

    var onOverrunWarning: ((ProcrastiNautTask, String?, Int) -> Void)?

    func startMonitoring(task: ProcrastiNautTask, monitoredCalendars: [EKCalendar]?) {
        stopMonitoring()

        guard let endTime = task.suggestedEndTime else { return }

        // Schedule 5-minute warning
        let warningTime = endTime.addingTimeInterval(-300)
        let delay = warningTime.timeIntervalSinceNow

        guard delay > 0 else { return }

        // Capture calendar identifiers (Sendable) instead of EKCalendar objects
        let calendarIDs = monitoredCalendars?.map { $0.calendarIdentifier }

        warningTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                let calendars = calendarIDs?.compactMap { id in
                    EventKitManager.shared.calendar(withIdentifier: id)
                }
                self?.triggerWarning(task: task, calendars: calendars)
            }
        }
    }

    func stopMonitoring() {
        warningTimer?.invalidate()
        warningTimer = nil
        showingWarning = false
        warningTask = nil
    }

    private func triggerWarning(task: ProcrastiNautTask, calendars: [EKCalendar]?) {
        guard let endTime = task.suggestedEndTime else { return }

        // Find the next event after this task
        let searchEnd = endTime.addingTimeInterval(3600) // Look 1 hour ahead
        let events = eventKitManager.fetchEvents(from: calendars, start: endTime, end: searchEnd)
        let nextEvent = events
            .filter { !($0.notes?.contains("Created by ProcrastiNaut") ?? false) }
            .sorted { $0.startDate < $1.startDate }
            .first

        warningTask = task
        nextEventTitle = nextEvent?.title
        minutesRemaining = max(0, Int(endTime.timeIntervalSinceNow / 60))
        showingWarning = true

        onOverrunWarning?(task, nextEvent?.title, minutesRemaining)
    }

    func dismissWarning() {
        showingWarning = false
        warningTask = nil
    }
}
