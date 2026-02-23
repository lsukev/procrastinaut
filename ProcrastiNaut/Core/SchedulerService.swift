import Foundation
import AppKit

@MainActor
@Observable
final class SchedulerService {
    private var scanTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var hasScanRunToday = false
    private var lastScanDate: Date?

    var onScanTriggered: ((ScanType) -> Void)?
    var onDayEndTriggered: (() -> Void)?

    private var dayEndTimer: Timer?
    private var hasDayEndRunToday = false
    private var lastDayEndDate: Date?
    private let settings = UserSettings.shared

    func start() {
        scheduleDailyScan()
        scheduleDayEndTimer()
        observeWakeFromSleep()
        checkForMissedScan()
    }

    func stop() {
        scanTimer?.invalidate()
        scanTimer = nil
        dayEndTimer?.invalidate()
        dayEndTimer = nil
        if let observer = wakeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Daily Scan Timer

    private func scheduleDailyScan() {
        scanTimer?.invalidate()

        let now = Date()
        let scanTimeToday = now.startOfDay.atTimeOfDay(settings.morningScanTime)

        var nextScan: Date
        if scanTimeToday > now {
            nextScan = scanTimeToday
        } else {
            // Already past today's scan time, schedule for tomorrow
            nextScan = Calendar.current.date(byAdding: .day, value: 1, to: scanTimeToday) ?? scanTimeToday
        }

        let delay = nextScan.timeIntervalSinceNow
        scanTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performScheduledScan()
            }
        }
    }

    private func performScheduledScan() {
        guard !hasScanAlreadyRunToday() else { return }
        markScanRun()
        onScanTriggered?(.scheduled)
        scheduleDailyScan() // Reschedule for tomorrow
    }

    // MARK: - Day End Timer

    private func scheduleDayEndTimer() {
        dayEndTimer?.invalidate()

        let now = Date()
        let dayEndToday = now.startOfDay.atTimeOfDay(settings.workingHoursEnd)

        var nextDayEnd: Date
        if dayEndToday > now {
            nextDayEnd = dayEndToday
        } else {
            nextDayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayEndToday) ?? dayEndToday
        }

        let delay = nextDayEnd.timeIntervalSinceNow
        dayEndTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performDayEnd()
            }
        }
    }

    private func performDayEnd() {
        guard !hasDayEndAlreadyRunToday() else { return }
        lastDayEndDate = Date()
        hasDayEndRunToday = true
        onDayEndTriggered?()
        scheduleDayEndTimer() // Reschedule for tomorrow
    }

    private func hasDayEndAlreadyRunToday() -> Bool {
        guard let lastDate = lastDayEndDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    // MARK: - Wake from Sleep

    private func observeWakeFromSleep() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWakeFromSleep()
            }
        }
    }

    private func handleWakeFromSleep() {
        guard !hasScanAlreadyRunToday() else { return }

        let now = Date()
        let scanTime = now.startOfDay.atTimeOfDay(settings.morningScanTime)

        // If we're past the scan time, trigger a wake-from-sleep scan
        if now > scanTime {
            markScanRun()
            onScanTriggered?(.wakeFromSleep)
        }

        // Re-schedule in case the timer was lost during sleep
        scheduleDailyScan()
    }

    // MARK: - Late Day Check

    func checkForMissedScan() {
        guard !hasScanAlreadyRunToday() else { return }

        let now = Date()
        let scanTime = now.startOfDay.atTimeOfDay(settings.morningScanTime)
        let workEnd = now.startOfDay.atTimeOfDay(settings.workingHoursEnd)

        // If we're past scan time but still within working hours
        if now > scanTime && now < workEnd {
            markScanRun()
            onScanTriggered?(.lateDay)
        }
    }

    // MARK: - Tracking

    private func hasScanAlreadyRunToday() -> Bool {
        guard let lastDate = lastScanDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    private func markScanRun() {
        lastScanDate = Date()
        hasScanRunToday = true
    }

    func resetDailyState() {
        hasScanRunToday = false
    }
}
