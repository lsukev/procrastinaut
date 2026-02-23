import Foundation
import AppKit

struct FollowUpItem: Sendable {
    let task: ProcrastiNautTask
    let fireAt: Date
}

struct UndoableAction: Identifiable, Sendable {
    let id = UUID()
    let task: ProcrastiNautTask
    let action: UndoActionType
    let expiresAt: Date

    enum UndoActionType: Sendable {
        case completed
        case skipped
        case notDone(RescheduleReason)
    }
}

@MainActor
@Observable
final class CustomNotificationManager {
    var currentFollowUp: ProcrastiNautTask?
    var undoAction: UndoableAction?
    var showingReschedule = false
    var showingPartialCompletion = false

    private var followUpQueue: [FollowUpItem] = []
    private var lastFollowUpTime: Date?
    private var queueTimer: Timer?
    private var undoTimer: Timer?

    var settings: UserSettings { UserSettings.shared }

    var onTaskCompleted: ((ProcrastiNautTask) -> Void)?
    var onTaskRescheduled: ((ProcrastiNautTask, TimeInterval) -> Void)?
    var onTaskSkipped: ((ProcrastiNautTask) -> Void)?
    var onTaskPartial: ((ProcrastiNautTask, TimeInterval) -> Void)?
    var onTaskNotDone: ((ProcrastiNautTask, RescheduleReason) -> Void)?
    var onShowPopover: (() -> Void)?

    // MARK: - Scheduling Follow-Ups

    func scheduleFollowUp(for task: ProcrastiNautTask) {
        guard let endTime = task.suggestedEndTime else { return }

        // If the task's end time has already passed, fire immediately
        let fireAt: Date
        if endTime <= Date() {
            fireAt = Date()
        } else {
            let delay = TimeInterval(settings.followUpDelay * 60)
            fireAt = endTime.addingTimeInterval(delay)
        }

        let item = FollowUpItem(task: task, fireAt: fireAt)
        followUpQueue.append(item)
        followUpQueue.sort { $0.fireAt < $1.fireAt }
        scheduleNextProcessing()
    }

    func cancelFollowUp(for taskID: UUID) {
        followUpQueue.removeAll { $0.task.id == taskID }
    }

    // MARK: - Processing Queue

    private func scheduleNextProcessing() {
        queueTimer?.invalidate()

        guard let next = followUpQueue.first else { return }

        let delay = max(0, next.fireAt.timeIntervalSinceNow)
        queueTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processQueue()
            }
        }
    }

    private func processQueue() {
        guard currentFollowUp == nil else {
            // Wait until current follow-up is dismissed
            return
        }

        guard let next = followUpQueue.first else { return }

        // Rate limiting
        if let lastTime = lastFollowUpTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            let rateLimit = TimeInterval(settings.followUpRateLimit)
            if elapsed < rateLimit {
                let retryDelay = rateLimit - elapsed
                queueTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.processQueue()
                    }
                }
                return
            }
        }

        // Fire if it's time
        if Date() >= next.fireAt {
            followUpQueue.removeFirst()
            currentFollowUp = next.task
            lastFollowUpTime = Date()
            onShowPopover?()
        } else {
            scheduleNextProcessing()
        }
    }

    // MARK: - User Actions

    func markDone() {
        guard let task = currentFollowUp else { return }

        let action = UndoableAction(
            task: task,
            action: .completed,
            expiresAt: Date().addingTimeInterval(TimeInterval(settings.undoWindowDuration))
        )
        undoAction = action
        currentFollowUp = nil

        // Delay actual completion by undo window
        let duration = TimeInterval(settings.undoWindowDuration)
        undoTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.undoAction?.id == action.id else { return }
                self.commitAction(action)
                self.undoAction = nil
            }
        }

        processQueue()
    }

    func markSkipped() {
        guard let task = currentFollowUp else { return }

        let action = UndoableAction(
            task: task,
            action: .skipped,
            expiresAt: Date().addingTimeInterval(TimeInterval(settings.undoWindowDuration))
        )
        undoAction = action
        currentFollowUp = nil

        let duration = TimeInterval(settings.undoWindowDuration)
        undoTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.undoAction?.id == action.id else { return }
                self.commitAction(action)
                self.undoAction = nil
            }
        }

        processQueue()
    }

    func markNotDone(reason: RescheduleReason) {
        guard let task = currentFollowUp else { return }

        let action = UndoableAction(
            task: task,
            action: .notDone(reason),
            expiresAt: Date().addingTimeInterval(TimeInterval(settings.undoWindowDuration))
        )
        undoAction = action
        currentFollowUp = nil

        let duration = TimeInterval(settings.undoWindowDuration)
        undoTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.undoAction?.id == action.id else { return }
                self.commitAction(action)
                self.undoAction = nil
            }
        }

        processQueue()
    }

    func startReschedule() {
        showingReschedule = true
    }

    func reschedule(delay: TimeInterval) {
        guard let task = currentFollowUp else { return }
        showingReschedule = false
        currentFollowUp = nil
        onTaskRescheduled?(task, delay)
        processQueue()
    }

    func startPartialCompletion() {
        showingPartialCompletion = true
    }

    func completePartial(remainingMinutes: Int) {
        guard let task = currentFollowUp else { return }
        showingPartialCompletion = false
        currentFollowUp = nil
        let remaining = TimeInterval(remainingMinutes * 60)
        onTaskPartial?(task, remaining)
        processQueue()
    }

    func undo() {
        undoTimer?.invalidate()
        undoAction = nil
    }

    // MARK: - Commit

    private func commitAction(_ action: UndoableAction) {
        switch action.action {
        case .completed:
            onTaskCompleted?(action.task)
        case .skipped:
            onTaskSkipped?(action.task)
        case .notDone(let reason):
            onTaskNotDone?(action.task, reason)
        }
    }
}
