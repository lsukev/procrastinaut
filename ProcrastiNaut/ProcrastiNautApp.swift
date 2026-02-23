import SwiftUI
import SwiftData
import Sparkle

@main
struct ProcrastiNautApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Dummy Settings scene needed for SwiftUI App protocol; the app is driven by AppDelegate
        Settings {
            Text("")
                .frame(width: 0, height: 0)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings\u{2026}") {
                    AppDelegate.shared?.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menuBarController: MenuBarController?
    let updaterController: SPUStandardUpdaterController
    private var schedulerService: SchedulerService?
    private var notificationManager: CustomNotificationManager?
    private var conflictMonitor: ConflictMonitor?
    private var overrunMonitor: OverrunMonitor?
    private var gamificationEngine: GamificationEngine?
    private var durationLearning: DurationLearningService?
    private var archiveManager: ArchiveManager?
    private var liveTimerManager: LiveTimerManager?
    private var globalHotkeyManager: GlobalHotkeyManager?
    private var outlookSyncManager: OutlookSyncManager?
    private var rescheduleLearning: RescheduleLearningEngine?
    private var quickChatController: QuickChatPanelController?
    private var mouseActivationMonitor: Any?
    private var midnightTimer: Timer?
    var modelContainer: ModelContainer?

    static var shared: AppDelegate?

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Set the app icon with day number overlay for LSUIElement apps
        updateDockIcon()
        scheduleMidnightIconRefresh()

        // Migrate viewable calendar IDs from monitored for existing users
        UserSettings.shared.migrateViewableCalendarsIfNeeded()

        setupModelContainer()
        setupPostMVPServices()
        setupNotificationManager()
        setupSystemNotifications()
        setupSchedulerService()
        setupArchiveObservers()
        setupGlobalHotkey()
        setupLiveTimer()
        setupOutlookSync()
        setupMouseActivationMonitor()

        menuBarController = MenuBarController()

        // Open planner after launch completes so the window doesn't get buried
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.openPlanner()
        }
    }

    private func setupModelContainer() {
        do {
            let schema = Schema([
                TaskRecord.self,
                DailyStats.self,
                DurationEstimate.self,
                TrackedEvent.self,
                GamificationRecord.self,
                RescheduleEvent.self,
                TimeOfDayPreference.self,
            ])
            let configuration = ModelConfiguration(
                "ProcrastiNaut",
                schema: schema
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
    }

    private func setupPostMVPServices() {
        conflictMonitor = ConflictMonitor()
        overrunMonitor = OverrunMonitor()

        let engine = GamificationEngine()
        if let context = modelContainer?.mainContext {
            engine.configure(modelContext: context)
        }
        gamificationEngine = engine

        let learning = DurationLearningService()
        if let context = modelContainer?.mainContext {
            learning.configure(modelContext: context)
        }
        durationLearning = learning

        let rescheduleEngine = RescheduleLearningEngine()
        if let context = modelContainer?.mainContext {
            rescheduleEngine.configure(modelContext: context)
        }
        rescheduleLearning = rescheduleEngine

        archiveManager = ArchiveManager()
    }

    private func setupSchedulerService() {
        let scheduler = SchedulerService()
        scheduler.onScanTriggered = { [weak self] scanType in
            // Only show the popover if the app is already active; never steal focus
            if NSApp.isActive {
                self?.menuBarController?.showPopover()
            }
            self?.triggerDailySummaryNotification()
        }
        scheduler.onDayEndTriggered = { [weak self] in
            self?.handleDayEnd()
        }
        scheduler.start()
        self.schedulerService = scheduler
    }

    private func triggerDailySummaryNotification() {
        Task {
            let ekManager = EventKitManager.shared
            let settings = UserSettings.shared
            let today = Date()
            let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today

            // Count today's events
            let events = ekManager.fetchEvents(from: nil, start: today, end: dayEnd)
            let eventCount = events.filter { !$0.isAllDay }.count

            // Count open tasks from monitored reminder lists
            let reminderLists = settings.monitoredReminderListIDs.compactMap {
                ekManager.calendar(withIdentifier: $0)
            }
            let reminders = await ekManager.fetchOpenReminders(from: reminderLists.isEmpty ? nil : reminderLists)
            let taskCount = reminders.count

            // Estimate free hours during working hours
            let workStart = today.startOfDay.addingTimeInterval(settings.workingHoursStart)
            let workEnd = today.startOfDay.addingTimeInterval(settings.workingHoursEnd)
            let totalWorkHours = settings.workingHoursEnd - settings.workingHoursStart
            let busySeconds = events.filter { !$0.isAllDay }
                .reduce(0.0) { sum, event in
                    let effectiveStart = max(event.startDate, workStart)
                    let effectiveEnd = min(event.endDate, workEnd)
                    return sum + max(0, effectiveEnd.timeIntervalSince(effectiveStart))
                }
            let freeHours = max(0, (totalWorkHours - busySeconds) / 3600)

            SystemNotificationService.shared.scheduleDailySummary(
                eventCount: eventCount, taskCount: taskCount, freeHours: freeHours
            )
        }
    }

    private func handleDayEnd() {
        guard let engine = gamificationEngine else { return }
        // Get current daily plan from the popover viewmodel
        let plan = menuBarController?.getCurrentDailyPlan()
            ?? DailyPlan(date: Date(), scanType: .scheduled)
        engine.recordDayEnd(plan: plan)
    }

    private func setupSystemNotifications() {
        SystemNotificationService.shared.setup()
        Task { await SystemNotificationService.shared.requestPermission() }
    }

    private func setupNotificationManager() {
        let manager = CustomNotificationManager()
        manager.onShowPopover = { [weak self] in
            // Only show the popover if the app is already active; never steal focus
            if NSApp.isActive {
                self?.menuBarController?.showPopover()
            }
        }
        manager.onTaskCompleted = { [weak self] task in
            try? EventKitManager.shared.completeReminder(identifier: task.reminderIdentifier)
            self?.gamificationEngine?.recordTaskCompleted(at: Date(), task: task)
            self?.durationLearning?.recordCompletion(task: task)
            self?.rescheduleLearning?.recordCompletion(task: task)
            SoundManager.shared.playTaskComplete()

            // Update task status in daily plan
            if let plan = self?.menuBarController?.popoverViewModel.dailyPlan,
               let index = plan.tasks.firstIndex(where: { $0.id == task.id }) {
                self?.menuBarController?.popoverViewModel.dailyPlan?.tasks[index].status = .completed
                self?.menuBarController?.popoverViewModel.dailyPlan?.tasks[index].completedAt = Date()
            }
        }
        manager.onTaskSkipped = { [weak self] task in
            // Update task status in daily plan
            if let plan = self?.menuBarController?.popoverViewModel.dailyPlan,
               let index = plan.tasks.firstIndex(where: { $0.id == task.id }) {
                self?.menuBarController?.popoverViewModel.dailyPlan?.tasks[index].status = .skipped
            }
        }
        manager.onTaskNotDone = { [weak self] task, reason in
            self?.rescheduleLearning?.recordReschedule(task: task, reason: reason)

            // Remove the task from daily plan since it wasn't done
            self?.menuBarController?.popoverViewModel.dailyPlan?.tasks.removeAll { $0.id == task.id }

            // Delete the calendar event so it's removed from the Planner view too
            if let eventID = task.calendarEventIdentifier,
               let startTime = task.suggestedStartTime {
                try? EventKitManager.shared.deleteEvent(identifier: eventID, occurrenceDate: startTime)
            }
        }
        self.notificationManager = manager
    }

    private func setupArchiveObservers() {
        NotificationCenter.default.addObserver(
            forName: .procrastiNautArchiveRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let context = self?.modelContainer?.mainContext else { return }
                self?.archiveManager?.performArchive(modelContext: context)
            }
        }
    }

    private func setupGlobalHotkey() {
        let hotkey = GlobalHotkeyManager()
        GlobalHotkeyManager.shared = hotkey
        hotkey.onHotkeyPressed = { [weak self] in
            if self?.menuBarController?.isPopoverShown == true {
                self?.menuBarController?.closePopover()
            } else {
                self?.menuBarController?.showPopover()
            }
        }
        hotkey.onQuickChatHotkeyPressed = { [weak self] in
            self?.toggleQuickChat()
        }
        hotkey.register()
        self.globalHotkeyManager = hotkey

        // Initialize Quick Chat panel controller
        quickChatController = QuickChatPanelController()
    }

    private func toggleQuickChat() {
        quickChatController?.togglePanel()
    }

    private func setupLiveTimer() {
        let timer = LiveTimerManager()
        timer.onTimerTick = { [weak self] timeString in
            if timeString.isEmpty {
                self?.menuBarController?.updateIcon(.normal)
                self?.menuBarController?.updateTimerText(nil)
            } else {
                self?.menuBarController?.updateTimerText(timeString)
            }
        }
        timer.onTimerComplete = { [weak self] task in
            SoundManager.shared.playTimerEnd()
            FocusModeManager.shared.disableFocus()
            self?.menuBarController?.updateIcon(.normal)
            self?.menuBarController?.updateTimerText(nil)
        }
        self.liveTimerManager = timer
    }

    private var settingsWindow: NSWindow?

    func openSettings() {
        menuBarController?.closePopover()

        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(rootView: SettingsWindow())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ProcrastiNaut Settings"
        window.setContentSize(NSSize(width: 750, height: 550))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.settingsWindow = window
        updateActivationPolicy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.level = .normal
        }
    }

    private var plannerWindow: NSWindow?

    func openPlanner() {
        // Close the popover first so it doesn't steal focus
        menuBarController?.closePopover()

        if let existing = plannerWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(rootView: PlannerWindow())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ProcrastiNaut Planner"
        window.setContentSize(NSSize(width: 1100, height: 750))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.plannerWindow = window
        updateActivationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        // Drop back to normal level after showing so it doesn't stay always-on-top
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            window.level = .normal
        }
    }

    // MARK: - Activation Policy (Dock icon)

    /// Shows the Dock icon when a window is visible, hides it when all windows close.
    private func updateActivationPolicy() {
        let hasVisibleWindow = (settingsWindow?.isVisible == true) || (plannerWindow?.isVisible == true)
        let targetPolicy: NSApplication.ActivationPolicy = hasVisibleWindow ? .regular : .accessory
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
            if targetPolicy == .regular {
                // LSUIElement apps need the icon set explicitly when switching to .regular
                updateDockIcon()
                // Don't call NSApp.activate() here — let the mouse monitor or
                // explicit user actions (openPlanner/openSettings) handle activation
                // so we never steal focus from other apps.
            }
        }
    }

    /// LSUIElement apps don't auto-activate (show their menu bar) when the user
    /// clicks their windows. This global + local event monitor catches mouse-downs
    /// and forces activation so the ProcrastiNaut menu bar appears.
    private func setupMouseActivationMonitor() {
        // Local monitor: fires for clicks already delivered to our windows
        mouseActivationMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { event in
            self.forceActivateIfNeeded(clickedWindow: event.window)
            return event
        }

        // Global monitor: fires for clicks outside our app — we check if the
        // click landed on one of our windows (handles the case where macOS
        // routes the click globally because the app isn't active yet).
        NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, !NSApp.isActive else { return }
            let clickLocation = NSEvent.mouseLocation
            if let planner = self.plannerWindow, planner.isVisible,
               planner.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.forceActivateIfNeeded(clickedWindow: planner)
                }
            } else if let settings = self.settingsWindow, settings.isVisible,
                      settings.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.forceActivateIfNeeded(clickedWindow: settings)
                }
            }
        }
    }

    private func forceActivateIfNeeded(clickedWindow: NSWindow?) {
        guard clickedWindow == plannerWindow || clickedWindow == settingsWindow else { return }
        NSApp.setActivationPolicy(.regular)
        updateDockIcon()
        clickedWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Delay slightly so isVisible updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateActivationPolicy()
            }
        }
    }

    // MARK: - Dock Icon with Day Number

    private func updateDockIcon() {
        guard let baseIcon = NSImage(named: "AppIcon") else { return }
        let size = NSSize(width: 128, height: 128)
        let dayString = "\(Calendar.current.component(.day, from: Date()))"

        let composited = NSImage(size: size)
        composited.lockFocus()

        // Draw the base icon
        baseIcon.draw(in: NSRect(origin: .zero, size: size),
                      from: .zero, operation: .sourceOver, fraction: 1.0)

        // Configure the day number text
        let fontSize: CGFloat = dayString.count == 1 ? 40 : 36
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (dayString as NSString).size(withAttributes: attrs)

        // Draw a background pill behind the number
        let pillPadding: CGFloat = 6
        let pillWidth = textSize.width + pillPadding * 2
        let pillHeight = textSize.height + pillPadding
        let pillX = (size.width - pillWidth) / 2
        let pillY: CGFloat = 4
        let pillRect = NSRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)

        NSColor(white: 0, alpha: 0.65).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

        // Draw the day number centered in the pill
        let textX = pillX + (pillWidth - textSize.width) / 2
        let textY = pillY + (pillHeight - textSize.height) / 2
        (dayString as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

        composited.unlockFocus()
        composited.isTemplate = false

        NSApp.applicationIconImage = composited
    }

    private func scheduleMidnightIconRefresh() {
        midnightTimer?.invalidate()
        guard let midnight = Calendar.current.date(byAdding: .day, value: 1,
                to: Calendar.current.startOfDay(for: Date())) else { return }
        let interval = midnight.timeIntervalSinceNow + 1 // 1 second past midnight
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateDockIcon()
                self?.scheduleMidnightIconRefresh()
            }
        }
    }

    // MARK: - Outlook Sync

    private func setupOutlookSync() {
        let manager = OutlookSyncManager()
        self.outlookSyncManager = manager
        if UserSettings.shared.outlookSyncEnabled {
            manager.startAutoSync()
        }
    }

    // MARK: - Service Accessors

    func getConflictMonitor() -> ConflictMonitor? { conflictMonitor }
    func getOverrunMonitor() -> OverrunMonitor? { overrunMonitor }
    func getGamificationEngine() -> GamificationEngine? { gamificationEngine }
    func getDurationLearning() -> DurationLearningService? { durationLearning }
    func getLiveTimer() -> LiveTimerManager? { liveTimerManager }
    func getOutlookSyncManager() -> OutlookSyncManager? { outlookSyncManager }
    func getRescheduleLearning() -> RescheduleLearningEngine? { rescheduleLearning }
    func getNotificationManager() -> CustomNotificationManager? { notificationManager }
}
