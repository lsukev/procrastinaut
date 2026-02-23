import EventKit
import Foundation

@MainActor
@Observable
final class OutlookSyncManager {
    let outlookService = OutlookService()

    var lastSyncDate: Date?
    var syncedCount: Int = 0
    var isSyncing = false

    private let eventKitManager = EventKitManager.shared
    private let settings = UserSettings.shared
    private var syncTimer: Timer?

    // Track which Outlook message IDs have already been synced
    private var syncedMessageIDs: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: "outlookSyncedMessageIDs") ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "outlookSyncedMessageIDs")
        }
    }

    // MARK: - Sync Lifecycle

    func startAutoSync() {
        guard settings.outlookSyncEnabled, outlookService.isAuthenticated else { return }
        stopAutoSync()

        let interval = TimeInterval(settings.outlookSyncInterval * 60)
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sync()
            }
        }

        // Initial sync
        Task { await sync() }
    }

    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Sync

    func sync() async {
        guard outlookService.isAuthenticated else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Fetch flagged emails from Outlook
        await outlookService.fetchFlaggedEmails()

        guard outlookService.errorMessage == nil else { return }

        let emails = outlookService.flaggedEmails
        var existingSyncedIDs = syncedMessageIDs
        var newCount = 0

        // Get or validate the target reminder list
        guard let targetList = getTargetReminderList() else {
            outlookService.errorMessage = "No reminder list configured for Outlook sync"
            return
        }

        for email in emails {
            // Skip already synced
            if existingSyncedIDs.contains(email.id) { continue }

            // Create reminder
            do {
                try createReminder(for: email, in: targetList)
                existingSyncedIDs.insert(email.id)
                newCount += 1
            } catch {
                print("Failed to create reminder for email \(email.subject ?? ""): \(error)")
            }
        }

        // Clean up: remove synced IDs for emails that are no longer flagged
        let currentFlaggedIDs = Set(emails.map(\.id))
        let staleIDs = existingSyncedIDs.subtracting(currentFlaggedIDs)
        existingSyncedIDs.subtract(staleIDs)

        syncedMessageIDs = existingSyncedIDs
        syncedCount = existingSyncedIDs.count
        lastSyncDate = Date()

        if newCount > 0 {
            // Trigger EventKit change notification so ProcrastiNaut picks up new reminders
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
        }
    }

    // MARK: - Reminder Creation

    private func createReminder(for email: OutlookFlaggedEmail, in list: EKCalendar) throws {
        let eventStore = EKEventStore()
        let reminder = EKReminder(eventStore: eventStore)

        // Title: email subject
        reminder.title = email.subject ?? "Flagged Email"
        reminder.calendar = list

        // Due date from flag
        if let dueDate = email.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        // Notes: sender, preview, and link
        var notes = "From: \(email.senderName)"
        if !email.senderAddress.isEmpty {
            notes += " <\(email.senderAddress)>"
        }
        if let preview = email.bodyPreview, !preview.isEmpty {
            notes += "\n\n\(preview)"
        }
        notes += "\n\n[Outlook Sync: \(email.id)]"

        reminder.notes = notes

        // URL: deep link to email
        if let webLink = email.webLink, let url = URL(string: webLink) {
            reminder.url = url
        }

        // Medium priority by default
        reminder.priority = 5

        try eventStore.save(reminder, commit: true)
    }

    // MARK: - Helpers

    private func getTargetReminderList() -> EKCalendar? {
        let listID = settings.outlookReminderListID

        // If a specific list is configured, use it
        if !listID.isEmpty, let cal = eventKitManager.calendar(withIdentifier: listID) {
            return cal
        }

        // Try to find or create an "Outlook" list
        let reminderLists = eventKitManager.getAvailableReminderLists()
        if let existing = reminderLists.first(where: { $0.title == "Outlook" }) {
            // Save for next time
            settings.outlookReminderListID = existing.calendarIdentifier
            return existing
        }

        // Create one
        let eventStore = EKEventStore()
        let newList = EKCalendar(for: .reminder, eventStore: eventStore)
        newList.title = "Outlook"

        if let source = eventStore.defaultCalendarForNewReminders()?.source {
            newList.source = source
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newList.source = localSource
        } else {
            return nil
        }

        do {
            try eventStore.saveCalendar(newList, commit: true)
            settings.outlookReminderListID = newList.calendarIdentifier
            return newList
        } catch {
            print("Failed to create Outlook reminder list: \(error)")
            return nil
        }
    }
}
