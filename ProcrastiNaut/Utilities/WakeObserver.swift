import AppKit

/// Observes system sleep/wake events and provides callbacks.
/// Used by SchedulerService for wake-from-sleep scan fallback.
@MainActor
final class WakeObserver {
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var lastSleepTime: Date?

    var onWake: ((TimeInterval) -> Void)?  // Passes duration of sleep

    func start() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastSleepTime = Date()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                let sleepDuration = self?.lastSleepTime.map { Date().timeIntervalSince($0) } ?? 0
                self?.onWake?(sleepDuration)
            }
        }
    }

    func stop() {
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
