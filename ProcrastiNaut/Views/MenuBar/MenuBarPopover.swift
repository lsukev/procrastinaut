import SwiftUI
import SwiftData
import EventKit

@MainActor
@Observable
final class PopoverViewModel {
    var dailyPlan: DailyPlan?
    var pendingSuggestions: [ProcrastiNautTask] = []
    var isScanning = false
    var showingSuggestions = false
    var errorMessage: String?
    var permissionState: PermissionState = .notDetermined

    private let eventKitManager = EventKitManager.shared
    private let suggestionEngine: SuggestionEngine
    private let settings = UserSettings.shared
    nonisolated(unsafe) private var changeObserver: NSObjectProtocol?

    init() {
        suggestionEngine = SuggestionEngine()
        suggestionEngine.rescheduleLearning = AppDelegate.shared?.getRescheduleLearning()
        permissionState = eventKitManager.checkPermissions()
        startObservingChanges()
        loadCalendarTasks()
    }

    deinit {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - EventKit Observation

    private func startObservingChanges() {
        changeObserver = eventKitManager.observeChanges { [weak self] in
            Task { @MainActor in
                self?.loadCalendarTasks()
            }
        }
    }

    /// Syncs ProcrastiNaut calendar events into the daily plan so tasks
    /// created via the Planner window (or any other source) appear here.
    /// Also removes tasks whose calendar events have been deleted.
    func loadCalendarTasks() {
        guard permissionState == .allGranted else { return }

        let today = Date()
        let calendars = monitoredCalendars()
        let events = eventKitManager.fetchEvents(
            from: calendars,
            start: today.startOfDay,
            end: today.endOfDay
        )

        // Find ProcrastiNaut-created events
        let pnEvents = events.filter { $0.notes?.contains("Created by ProcrastiNaut") ?? false }
        let liveEventIDs = Set(pnEvents.map(\.calendarItemIdentifier))

        // Remove tasks whose calendar events no longer exist
        if dailyPlan != nil {
            dailyPlan?.tasks.removeAll { task in
                guard let eventID = task.calendarEventIdentifier else { return false }
                return !liveEventIDs.contains(eventID)
            }
        }

        guard !pnEvents.isEmpty else { return }

        // Ensure we have a daily plan
        if dailyPlan == nil {
            dailyPlan = DailyPlan(date: today, scanType: .manual)
        }

        for event in pnEvents {
            let eventID = event.calendarItemIdentifier

            // If task already tracked, update its times if changed
            if let existingIndex = dailyPlan?.tasks.firstIndex(where: { $0.calendarEventIdentifier == eventID }) {
                let existing = dailyPlan!.tasks[existingIndex]
                if existing.suggestedStartTime != event.startDate || existing.suggestedEndTime != event.endDate {
                    dailyPlan!.tasks[existingIndex].suggestedStartTime = event.startDate
                    dailyPlan!.tasks[existingIndex].suggestedEndTime = event.endDate
                    dailyPlan!.tasks[existingIndex].suggestedDuration = event.endDate.timeIntervalSince(event.startDate)

                    // Reschedule follow-up for the new end time
                    let notifManager = AppDelegate.shared?.getNotificationManager()
                    notifManager?.cancelFollowUp(for: existing.id)
                    notifManager?.scheduleFollowUp(for: dailyPlan!.tasks[existingIndex])
                }
                continue
            }

            // New event — extract reminder identifier from notes
            var reminderID = ""
            if let notes = event.notes,
               let range = notes.range(of: #"Reminder: (.+)"#, options: .regularExpression) {
                let match = String(notes[range])
                reminderID = String(match.dropFirst("Reminder: ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n").first ?? ""
            }

            // Strip the ProcrastiNaut emoji prefix from title
            var title = event.title ?? "Untitled"
            if title.hasPrefix("\u{1F4CB} ") {
                title = String(title.dropFirst(3))
            }

            let task = ProcrastiNautTask(
                id: UUID(),
                reminderIdentifier: reminderID,
                reminderTitle: title,
                reminderListName: "",
                priority: .none,
                dueDate: nil,
                reminderNotes: nil,
                reminderURL: nil,
                energyRequirement: .medium,
                suggestedStartTime: event.startDate,
                suggestedEndTime: event.endDate,
                suggestedDuration: event.endDate.timeIntervalSince(event.startDate),
                status: .approved,
                calendarEventIdentifier: eventID,
                createdAt: Date()
            )

            dailyPlan?.tasks.append(task)

            // Schedule follow-up notification for when the task block ends
            AppDelegate.shared?.getNotificationManager()?.scheduleFollowUp(for: task)
        }
    }

    func performScan() async {
        guard permissionState == .allGranted else {
            errorMessage = "Please grant Calendar and Reminders access first."
            return
        }

        isScanning = true
        errorMessage = nil

        let reminderLists = monitoredReminderLists()
        let reminders = await eventKitManager.fetchOpenReminders(from: reminderLists)

        let today = Date()
        let calendars = monitoredCalendars()
        let events = eventKitManager.fetchEvents(from: calendars, start: today.startOfDay, end: today.endOfDay)

        let freeSlots = suggestionEngine.findAvailableSlots(date: today, events: events)
        let suggestions = suggestionEngine.generateSuggestions(reminders: reminders, freeSlots: freeSlots)

        if suggestions.isEmpty && reminders.isEmpty {
            errorMessage = "No open reminders found."
        } else if suggestions.isEmpty {
            errorMessage = "No available time slots found for today."
        }

        pendingSuggestions = suggestions
        showingSuggestions = !suggestions.isEmpty

        if dailyPlan == nil {
            dailyPlan = DailyPlan(date: today, scanType: .manual)
        }
        dailyPlan?.scanCompletedAt = Date()

        isScanning = false
    }

    func approveTask(_ task: ProcrastiNautTask) {
        guard let calendar = targetCalendar() else {
            errorMessage = "No target calendar configured."
            return
        }

        do {
            let event = try eventKitManager.createVerifiedTimeBlock(
                for: task,
                on: calendar,
                monitoredCalendars: monitoredCalendars()
            )

            if let index = pendingSuggestions.firstIndex(where: { $0.id == task.id }) {
                var approvedTask = pendingSuggestions[index]
                approvedTask.status = .approved
                approvedTask.calendarEventIdentifier = event.calendarItemIdentifier
                pendingSuggestions.remove(at: index)
                dailyPlan?.tasks.append(approvedTask)

                // Schedule follow-up notification for when the task block ends
                AppDelegate.shared?.getNotificationManager()?.scheduleFollowUp(for: approvedTask)
            }

            if pendingSuggestions.isEmpty {
                showingSuggestions = false
            }
        } catch let error as ProcrastiNautError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
    }

    func approveAll() {
        let tasks = pendingSuggestions
        for task in tasks {
            approveTask(task)
        }
    }

    func skipTask(_ task: ProcrastiNautTask) {
        pendingSuggestions.removeAll { $0.id == task.id }
        if pendingSuggestions.isEmpty {
            showingSuggestions = false
        }
    }

    func changeDuration(for task: ProcrastiNautTask, newMinutes: Int) {
        guard let index = pendingSuggestions.firstIndex(where: { $0.id == task.id }) else { return }
        let newDuration = TimeInterval(newMinutes * 60)
        pendingSuggestions[index].suggestedDuration = newDuration
        if let start = pendingSuggestions[index].suggestedStartTime {
            pendingSuggestions[index].suggestedEndTime = start.addingTimeInterval(newDuration)
        }
    }

    func refreshPermissions() {
        permissionState = eventKitManager.checkPermissions()
    }

    /// Load heatmap data from SwiftData
    var heatmapData: [Date: Int] {
        guard let context = AppDelegate.shared?.modelContainer?.mainContext else { return [:] }
        let descriptor = FetchDescriptor<DailyStats>()
        guard let records = try? context.fetch(descriptor) else { return [:] }

        var data: [Date: Int] = [:]
        for record in records {
            let day = Calendar.current.startOfDay(for: record.date)
            data[day] = record.totalCompleted
        }
        return data
    }

    private func monitoredCalendars() -> [EKCalendar]? {
        let ids = settings.monitoredCalendarIDs
        guard !ids.isEmpty else { return nil }
        return ids.compactMap { eventKitManager.calendar(withIdentifier: $0) }
    }

    private func monitoredReminderLists() -> [EKCalendar]? {
        let ids = settings.monitoredReminderListIDs
        guard !ids.isEmpty else { return nil }
        return eventKitManager.getAvailableReminderLists().filter { ids.contains($0.calendarIdentifier) }
    }

    private func targetCalendar() -> EKCalendar? {
        if !settings.blockingCalendarID.isEmpty,
           let cal = eventKitManager.calendar(withIdentifier: settings.blockingCalendarID) {
            return cal
        }
        return eventKitManager.getOrCreateProcrastiNautCalendar()
    }
}

// MARK: - Main Popover

struct MenuBarPopover: View {
    @State var viewModel: PopoverViewModel
    var notificationManager: CustomNotificationManager?
    @State private var showConfetti = false
    @State private var showTimeline = false
    @State private var achievementToast: AchievementEvent?
    @State private var xpGainAmount: Int?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                if let notifManager = notificationManager,
                   let followUpTask = notifManager.currentFollowUp {
                    // Follow-up takes priority over everything
                    followUpContent(manager: notifManager, task: followUpTask)
                } else if viewModel.permissionState != .allGranted {
                    ScrollView {
                        PermissionBanner(
                            permissionState: viewModel.permissionState,
                            onPermissionsChanged: { viewModel.refreshPermissions() }
                        )
                        .padding(16)
                    }
                } else if viewModel.showingSuggestions {
                    SuggestionListView(
                        suggestions: $viewModel.pendingSuggestions,
                        onApprove: { viewModel.approveTask($0) },
                        onApproveAll: { viewModel.approveAll() },
                        onSkip: { viewModel.skipTask($0) },
                        onDismiss: { viewModel.showingSuggestions = false },
                        onChangeDuration: { task, mins in viewModel.changeDuration(for: task, newMinutes: mins) }
                    )
                } else {
                    mainContent
                }

                bottomBar
            }

            // Confetti overlay
            if UserSettings.shared.enableConfetti {
                ConfettiView(isActive: $showConfetti)
                    .allowsHitTesting(false)
            }

            // Achievement toast overlay
            if let toast = achievementToast {
                VStack {
                    AchievementToastView(event: toast) {
                        withAnimation { achievementToast = nil }
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }

            // XP gain overlay
            if let xp = xpGainAmount {
                XPGainView(amount: xp) {
                    xpGainAmount = nil
                }
                .zIndex(11)
            }
        }
        .frame(width: 380, height: 520)
        .onAppear {
            viewModel.refreshPermissions()
            viewModel.loadCalendarTasks()
        }
        .onChange(of: AppDelegate.shared?.getGamificationEngine()?.lastAchievement?.id) { _, newValue in
            guard newValue != nil,
                  let engine = AppDelegate.shared?.getGamificationEngine(),
                  let achievement = engine.lastAchievement else { return }
            withAnimation(.spring(duration: 0.4)) {
                achievementToast = achievement
            }
            if UserSettings.shared.enableConfetti {
                showConfetti = true
            }
            SoundManager.shared.playMilestone()
            engine.lastAchievement = nil
        }
        .onChange(of: AppDelegate.shared?.getGamificationEngine()?.lastXPGain) { _, newValue in
            guard let xp = newValue, xp > 0,
                  let engine = AppDelegate.shared?.getGamificationEngine() else { return }
            xpGainAmount = xp
            engine.lastXPGain = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ProcrastiNaut")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Text(todayString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Timeline toggle
            Button(action: { showTimeline.toggle() }) {
                Image(systemName: showTimeline ? "timeline.selection" : "list.bullet")
                    .font(.system(size: 12))
                    .foregroundStyle(showTimeline ? .purple : .secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle timeline view")

            Button(action: {
                AppDelegate.shared?.openPlanner()
            }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open Planner")

            Button(action: {
                AppDelegate.shared?.openSettings()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Follow-Up Content

    private func followUpContent(manager: CustomNotificationManager, task: ProcrastiNautTask) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                CustomFollowUpView(
                    task: task,
                    onDone: { manager.markDone() },
                    onPartial: { manager.startPartialCompletion() },
                    onNotDone: { reason in manager.markNotDone(reason: reason) }
                )

                if manager.showingPartialCompletion {
                    partialCompletionPicker(manager: manager)
                }

                // Undo banner
                if let undo = manager.undoAction {
                    UndoBannerView(action: undo) {
                        manager.undo()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func partialCompletionPicker(manager: CustomNotificationManager) -> some View {
        VStack(spacing: 8) {
            Text("How much time remains?")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach([5, 10, 15, 30], id: \.self) { mins in
                    Button("\(mins)m") {
                        manager.completePartial(remainingMinutes: mins)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Button("Cancel") {
                manager.showingPartialCompletion = false
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Undo banner (shown after follow-up dismissal)
                if let manager = notificationManager,
                   let undo = manager.undoAction {
                    UndoBannerView(action: undo) {
                        manager.undo()
                    }
                }

                // Live timer (if task is active)
                liveTimerCard

                todaysPlanCard

                // Timeline toggle
                if showTimeline, let plan = viewModel.dailyPlan {
                    DayTimelineView(
                        tasks: plan.tasks,
                        workStart: UserSettings.shared.workingHoursStart,
                        workEnd: UserSettings.shared.workingHoursEnd
                    )
                    .frame(height: 200)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                }

                gamificationCard

                // Scheduling Insights
                insightsCard

                // Heatmap
                CalendarHeatmapView(dailyData: viewModel.heatmapData)

                errorBanner
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Live Timer Card

    @ViewBuilder
    private var liveTimerCard: some View {
        if let timer = AppDelegate.shared?.getLiveTimer(),
           timer.isRunning, let task = timer.activeTask {
            LiveTimerView(
                task: task,
                remainingTime: timer.formattedTime,
                progress: timer.progress,
                onStop: {
                    timer.stopTimer()
                    FocusModeManager.shared.disableFocus()
                }
            )
        }
    }

    // MARK: - Today's Plan Card

    private var todaysPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("Today's Plan")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if let plan = viewModel.dailyPlan, !plan.tasks.isEmpty {
                    Text("\(plan.completedCount)/\(plan.tasks.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Capsule())
                }
            }

            if let plan = viewModel.dailyPlan, !plan.tasks.isEmpty {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * plan.completionRate, height: 6)
                    }
                }
                .frame(height: 6)

                // Task list with drag reorder
                ForEach(plan.tasks) { task in
                    taskRow(task)
                        .draggable(task.id.uuidString) {
                            Text(task.reminderTitle)
                                .font(.caption)
                                .padding(4)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedID = items.first,
                                  let fromIndex = viewModel.dailyPlan?.tasks.firstIndex(where: { $0.id.uuidString == draggedID }),
                                  let toIndex = viewModel.dailyPlan?.tasks.firstIndex(where: { $0.id == task.id }) else {
                                return false
                            }
                            withAnimation {
                                viewModel.dailyPlan?.tasks.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                            }
                            return true
                        }
                }
            } else {
                emptyPlanView
            }

            if !viewModel.pendingSuggestions.isEmpty {
                Divider()

                Button(action: { viewModel.showingSuggestions = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                        Text("\(viewModel.pendingSuggestions.count) suggestions ready")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private var emptyPlanView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("No tasks scheduled")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Tap Scan Now to find open reminders")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func taskRow(_ task: ProcrastiNautTask) -> some View {
        HStack(spacing: 10) {
            statusIcon(task.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.reminderTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if let start = task.suggestedStartTime, let end = task.suggestedEndTime {
                    Text(formatTimeRange(start: start, end: end))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Start button for approved tasks
            if task.status == .approved {
                Button(action: { startTask(task) }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.green)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Start task")
            }

            priorityPill(task.priority)
        }
        .padding(.vertical, 4)
    }

    private func startTask(_ task: ProcrastiNautTask) {
        guard let timer = AppDelegate.shared?.getLiveTimer() else { return }

        // Mark task as in progress
        if let index = viewModel.dailyPlan?.tasks.firstIndex(where: { $0.id == task.id }) {
            viewModel.dailyPlan?.tasks[index].status = .inProgress
        }

        timer.startTimer(for: task)
        AppDelegate.shared?.menuBarController?.updateIcon(.active)
        FocusModeManager.shared.enableFocus()
    }

    private func statusIcon(_ status: TaskStatus) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .approved:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
            case .inProgress:
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.orange)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(.quaternary)
            default:
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.quaternary)
            }
        }
        .font(.system(size: 14))
    }

    private func priorityPill(_ priority: TaskPriority) -> some View {
        let (color, label): (Color, String) = switch priority {
        case .high: (.red, "High")
        case .medium: (.orange, "Med")
        case .low: (.blue, "Low")
        case .none: (.gray, "")
        }

        return Group {
            if priority != .none {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Gamification Card

    @ViewBuilder
    private var gamificationCard: some View {
        if UserSettings.shared.enableStreaks || UserSettings.shared.enableBadges,
           let engine = AppDelegate.shared?.getGamificationEngine() {
            VStack(alignment: .leading, spacing: 10) {
                if UserSettings.shared.enableStreaks {
                    StreakView(
                        currentStreak: engine.state.currentStreak,
                        longestStreak: engine.state.longestStreak,
                        currentTitle: engine.state.currentTitle,
                        levelProgress: engine.levelProgress,
                        nextLevelTitle: engine.nextLevelTitle,
                        totalXP: engine.state.totalXP,
                        todayXP: engine.state.todayXP,
                        streakFreezesAvailable: engine.state.streakFreezesAvailable,
                        freezeEnabled: UserSettings.shared.enableStreakFreeze
                    )
                }

                // Daily Challenge
                if let challenge = engine.state.currentChallenge {
                    DailyChallengeView(challenge: challenge)
                }

                if UserSettings.shared.enableBadges {
                    BadgesView(badges: engine.state.earnedBadges)
                }
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Insights Card

    @ViewBuilder
    private var insightsCard: some View {
        if let engine = AppDelegate.shared?.getRescheduleLearning() {
            let insights = engine.generateInsights()
            if !insights.isEmpty {
                InsightsView(insights: insights)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)

                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button(action: { viewModel.errorMessage = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Quick Add
            QuickAddView { task in
                viewModel.dailyPlan?.tasks.append(task)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Action buttons
            HStack(spacing: 10) {
                Button(action: {
                    Task { await viewModel.performScan() }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text("Scan Now")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)

                Button(action: {
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Text("Dismiss")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.5))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}
