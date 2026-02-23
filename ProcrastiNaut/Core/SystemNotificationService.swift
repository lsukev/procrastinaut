import Foundation
import UserNotifications
import AppKit

@MainActor
@Observable
final class SystemNotificationService: NSObject, @unchecked Sendable {
    static let shared = SystemNotificationService()

    var permissionGranted = false

    private let center = UNUserNotificationCenter.current()
    private var settings: UserSettings { UserSettings.shared }

    // Track which invitation IDs we've already notified about (to avoid re-notifying on reload)
    private var notifiedInvitationIDs: Set<String> = []

    // MARK: - Category IDs

    enum Category: String {
        case eventReminder
        case overdueReminder
        case dailySummary
        case focusTimerEnd
        case conflictAlert
        case invitationReceived
    }

    // MARK: - Action IDs

    private enum Action: String {
        case snooze5  = "SNOOZE_5"
        case snooze60 = "SNOOZE_60"
        case open     = "OPEN"
    }

    // MARK: - Setup

    override private init() {
        super.init()
    }

    func setup() {
        center.delegate = self
        registerCategories()
        Task { await checkPermission() }
    }

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            // If still not granted, the system prompt was already shown once.
            // Open System Settings so the user can enable notifications manually.
            if !granted {
                openNotificationSettings()
            }
        } catch {
            print("[Notifications] Permission error: \(error)")
            permissionGranted = false
            openNotificationSettings()
        }
    }

    /// Opens System Settings > Notifications for this app.
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func recheckPermission() async {
        let settings = await center.notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    private func checkPermission() async {
        await recheckPermission()
    }

    private func registerCategories() {
        let snooze5 = UNNotificationAction(
            identifier: Action.snooze5.rawValue,
            title: "Snooze 5 min",
            options: []
        )
        let snooze60 = UNNotificationAction(
            identifier: Action.snooze60.rawValue,
            title: "Snooze 1 hour",
            options: []
        )
        let open = UNNotificationAction(
            identifier: Action.open.rawValue,
            title: "Open",
            options: [.foreground]
        )

        let eventCategory = UNNotificationCategory(
            identifier: Category.eventReminder.rawValue,
            actions: [open, snooze5],
            intentIdentifiers: []
        )
        let overdueCategory = UNNotificationCategory(
            identifier: Category.overdueReminder.rawValue,
            actions: [open, snooze60],
            intentIdentifiers: []
        )
        let dailyCategory = UNNotificationCategory(
            identifier: Category.dailySummary.rawValue,
            actions: [open],
            intentIdentifiers: []
        )
        let timerCategory = UNNotificationCategory(
            identifier: Category.focusTimerEnd.rawValue,
            actions: [open],
            intentIdentifiers: []
        )
        let conflictCategory = UNNotificationCategory(
            identifier: Category.conflictAlert.rawValue,
            actions: [open],
            intentIdentifiers: []
        )
        let inviteCategory = UNNotificationCategory(
            identifier: Category.invitationReceived.rawValue,
            actions: [open],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            eventCategory, overdueCategory, dailyCategory,
            timerCategory, conflictCategory, inviteCategory
        ])
    }

    // MARK: - Guards

    private func isEnabled(category: Category) -> Bool {
        guard settings.notificationsEnabled else { return false }
        switch category {
        case .eventReminder:      return settings.notifyEventReminders
        case .overdueReminder:    return settings.notifyOverdueReminders
        case .dailySummary:       return settings.notifyDailySummary
        case .focusTimerEnd:      return settings.notifyFocusTimerEnd
        case .conflictAlert:      return settings.notifyConflicts
        case .invitationReceived: return settings.notifyInvitations
        }
    }

    private func isInQuietHours() -> Bool {
        guard settings.quietHoursEnabled else { return false }
        let now = Date()
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: now)
        let secondsSinceMidnight = now.timeIntervalSince(midnight)

        let start = settings.quietHoursStart
        let end = settings.quietHoursEnd

        if start < end {
            // e.g. 1 AM to 7 AM
            return secondsSinceMidnight >= start && secondsSinceMidnight < end
        } else {
            // e.g. 10 PM to 7 AM (wraps midnight)
            return secondsSinceMidnight >= start || secondsSinceMidnight < end
        }
    }

    private func canSend(category: Category) -> Bool {
        guard permissionGranted else { return false }
        guard isEnabled(category: category) else { return false }
        // Daily summary ignores quiet hours
        if category != .dailySummary && isInQuietHours() { return false }
        return true
    }

    // MARK: - Scheduling

    func scheduleEventReminder(id: String, title: String, startDate: Date, calendarName: String) {
        guard canSend(category: .eventReminder) else { return }

        let minutesBefore = TimeInterval(settings.eventReminderMinutes * 60)
        let fireDate = startDate.addingTimeInterval(-minutesBefore)

        // Don't schedule if fire date already passed
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = minutesLabel(settings.eventReminderMinutes)
        content.body = title
        content.categoryIdentifier = Category.eventReminder.rawValue
        content.userInfo = ["eventID": id]
        applySound(to: content)

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Category.eventReminder.rawValue)-\(id)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Event reminder error: \(error)") }
        }
    }

    func scheduleOverdueReminder(id: String, title: String, dueDate: Date) {
        guard canSend(category: .overdueReminder) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Overdue"
        content.body = title
        content.subtitle = overdueLabel(since: dueDate)
        content.categoryIdentifier = Category.overdueReminder.rawValue
        content.userInfo = ["reminderID": id]
        applySound(to: content)

        // Fire immediately (1 second delay minimum for UNTimeIntervalNotificationTrigger)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Category.overdueReminder.rawValue)-\(id)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Overdue reminder error: \(error)") }
        }
    }

    func scheduleDailySummary(eventCount: Int, taskCount: Int, freeHours: Double) {
        guard canSend(category: .dailySummary) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Today's Schedule"
        content.body = "\(eventCount) event\(eventCount == 1 ? "" : "s"), \(taskCount) task\(taskCount == 1 ? "" : "s"), \(String(format: "%.1f", freeHours)) free hours"
        content.categoryIdentifier = Category.dailySummary.rawValue
        applySound(to: content)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Category.dailySummary.rawValue)-\(dateKey())",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Daily summary error: \(error)") }
        }
    }

    func scheduleFocusTimerEnd(title: String) {
        guard canSend(category: .focusTimerEnd) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete"
        content.body = title
        content.categoryIdentifier = Category.focusTimerEnd.rawValue
        applySound(to: content)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Category.focusTimerEnd.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Focus timer error: \(error)") }
        }
    }

    func scheduleConflictAlert(event1Title: String, event2Title: String, overlapTime: Date) {
        guard canSend(category: .conflictAlert) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Schedule Conflict"
        content.body = "\"\(event1Title)\" overlaps with \"\(event2Title)\""
        content.categoryIdentifier = Category.conflictAlert.rawValue
        applySound(to: content)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        // Deduplicate by both event titles
        let key = "\(event1Title)-\(event2Title)".hashValue
        let request = UNNotificationRequest(
            identifier: "\(Category.conflictAlert.rawValue)-\(key)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Conflict alert error: \(error)") }
        }
    }

    func scheduleInvitationAlert(id: String, title: String, organizer: String, startDate: Date) {
        guard canSend(category: .invitationReceived) else { return }
        // Only notify once per invitation
        guard !notifiedInvitationIDs.contains(id) else { return }
        notifiedInvitationIDs.insert(id)

        let content = UNMutableNotificationContent()
        content.title = "Meeting Invitation"
        content.body = title
        content.subtitle = "From \(organizer)"
        content.categoryIdentifier = Category.invitationReceived.rawValue
        content.userInfo = ["invitationID": id]
        applySound(to: content)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Category.invitationReceived.rawValue)-\(id)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error { print("[Notifications] Invitation alert error: \(error)") }
        }
    }

    // MARK: - Batch Scheduling

    /// Replaces all event reminders with fresh ones for the given events.
    /// Uses async/await to avoid the race condition where an async cancel
    /// could remove freshly-added requests.
    func rescheduleAllEventReminders(for events: [CalendarEventItem]) async {
        // Always recheck permission before scheduling
        await recheckPermission()
        guard permissionGranted else { return }
        guard settings.notificationsEnabled, settings.notifyEventReminders else { return }

        var activeIDs: Set<String> = []

        for event in events where !event.isAllDay {
            let identifier = "\(Category.eventReminder.rawValue)-\(event.id)"
            let minutesBefore = TimeInterval(settings.eventReminderMinutes * 60)
            let fireDate = event.startDate.addingTimeInterval(-minutesBefore)

            // Don't schedule if fire date already passed
            guard fireDate > Date() else { continue }

            activeIDs.insert(identifier)

            let content = UNMutableNotificationContent()
            content.title = minutesLabel(settings.eventReminderMinutes)
            content.body = event.title
            content.categoryIdentifier = Category.eventReminder.rawValue
            content.userInfo = ["eventID": event.id]
            applySound(to: content)

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("[Notifications] Event reminder error: \(error)")
            }
        }

        // Remove stale event reminders for events no longer in the list
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending
            .filter { $0.identifier.hasPrefix(Category.eventReminder.rawValue) && !activeIDs.contains($0.identifier) }
            .map(\.identifier)
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }
    }

    // MARK: - Cancellation

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelAllEventReminders() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Category.eventReminder.rawValue) }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    private func applySound(to content: UNMutableNotificationContent) {
        switch settings.notificationSound {
        case "subtle":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("subtle.aiff"))
        case "none":
            content.sound = nil
        default:
            content.sound = .default
        }
    }

    private func minutesLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "In \(minutes) minutes" }
        let hours = minutes / 60
        return "In \(hours) hour\(hours == 1 ? "" : "s")"
    }

    private func overdueLabel(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "Due \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Due \(hours)h ago" }
        let days = hours / 24
        return "Due \(days) day\(days == 1 ? "" : "s") ago"
    }

    private func dateKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Snooze

    private nonisolated func scheduleSnooze(originalContent: UNNotificationContent, minutes: Int) {
        let content = originalContent.mutableCopy() as! UNMutableNotificationContent
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "snooze-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SystemNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionID = response.actionIdentifier

        switch actionID {
        case Action.snooze5.rawValue:
            scheduleSnooze(originalContent: response.notification.request.content, minutes: 5)
        case Action.snooze60.rawValue:
            scheduleSnooze(originalContent: response.notification.request.content, minutes: 60)
        case Action.open.rawValue, UNNotificationDefaultActionIdentifier:
            // Bring app to front
            await MainActor.run {
                NSApp.activate()
            }
        default:
            break
        }
    }
}
