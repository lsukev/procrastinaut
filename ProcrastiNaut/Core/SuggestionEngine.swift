import EventKit
import Foundation

struct TimeSlot: Sendable {
    let start: Date
    let end: Date
    var energyLevel: EnergyLevel?

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

@MainActor
final class SuggestionEngine {
    private let eventKitManager: EventKitManager
    private let settings: UserSettings
    var rescheduleLearning: RescheduleLearningEngine?

    init(eventKitManager: EventKitManager = .shared, settings: UserSettings = .shared) {
        self.eventKitManager = eventKitManager
        self.settings = settings
    }

    // MARK: - Slot Finding

    func findAvailableSlots(date: Date, events: [EKEvent], fromTime: Date? = nil) -> [TimeSlot] {
        let dayStart = date.startOfDay
        let workStart = fromTime ?? dayStart.atTimeOfDay(settings.workingHoursStart)
        let workEnd = dayStart.atTimeOfDay(settings.workingHoursEnd)

        // If we're past working hours, no slots
        let effectiveStart = max(workStart, Date())
        guard effectiveStart < workEnd else { return [] }

        // Build busy blocks from events (merge overlapping)
        let busyBlocks = mergeOverlappingBlocks(events.map { ($0.startDate!, $0.endDate!) })

        // Subtract busy blocks from available window
        var freeSlots = subtractBusyBlocks(
            availableStart: effectiveStart,
            availableEnd: workEnd,
            busyBlocks: busyBlocks
        )

        // Apply buffer between any event and a task block
        let buffer = TimeInterval(settings.bufferBetweenBlocks * 60)
        freeSlots = applyBuffer(slots: freeSlots, busyBlocks: busyBlocks, buffer: buffer)

        // Filter out slots smaller than minimum
        let minSize = TimeInterval(settings.minimumSlotSize * 60)
        freeSlots = freeSlots.filter { $0.duration >= minSize }

        return freeSlots
    }

    // MARK: - Suggestion Generation

    func generateSuggestions(
        reminders: [EKReminder],
        freeSlots: [TimeSlot]
    ) -> [ProcrastiNautTask] {
        var availableSlots = freeSlots
        var suggestions: [ProcrastiNautTask] = []

        // Sort reminders by priority
        let sorted = sortReminders(reminders)

        for reminder in sorted.prefix(settings.maxSuggestionsPerDay) {
            let baseDuration = determineDuration(for: reminder)
            let listName = reminder.calendar?.title ?? "Unknown"
            let title = reminder.title ?? "Untitled"

            // Apply learned duration adjustment
            let duration = rescheduleLearning?.durationAdjustment(
                listName: listName,
                title: title,
                baseDuration: baseDuration
            ) ?? baseDuration

            // Check if task should be split
            let shouldSplit = rescheduleLearning?.shouldSplit(
                listName: listName,
                title: title,
                duration: duration
            ) ?? false

            let blockDurations: [TimeInterval]
            if shouldSplit {
                let half = duration / 2
                blockDurations = [half, half]
            } else {
                blockDurations = [duration]
            }

            let totalBlocks = blockDurations.count
            let extraBuffer = rescheduleLearning?.bufferRecommendation(
                listName: listName,
                title: title
            ) ?? 0

            for (blockIdx, blockDuration) in blockDurations.enumerated() {
                // Find best matching slot, considering learned time preferences
                guard let (slotIndex, startTime) = findBestSlot(
                    duration: blockDuration,
                    in: availableSlots,
                    listName: listName,
                    title: title
                ) else {
                    continue
                }

                let endTime = startTime.addingTimeInterval(blockDuration)
                let energyReq = determineEnergyRequirement(for: reminder)

                var task = ProcrastiNautTask(
                    id: UUID(),
                    reminderIdentifier: reminder.calendarItemIdentifier,
                    reminderTitle: title,
                    reminderListName: listName,
                    priority: TaskPriority.from(ekPriority: reminder.priority),
                    dueDate: reminder.dueDateComponents?.date,
                    reminderNotes: reminder.notes,
                    reminderURL: reminder.url,
                    energyRequirement: energyReq,
                    suggestedStartTime: startTime,
                    suggestedEndTime: endTime,
                    suggestedDuration: blockDuration,
                    status: .pending,
                    createdAt: Date()
                )

                if totalBlocks > 1 {
                    task.blockIndex = blockIdx + 1
                    task.totalBlocks = totalBlocks
                }

                suggestions.append(task)

                // Remove used time from available slots (with extra learned buffer)
                let totalBuffer = TimeInterval(settings.bufferBetweenBlocks * 60) + extraBuffer
                availableSlots = consumeSlotTime(
                    slots: availableSlots,
                    slotIndex: slotIndex,
                    usedStart: startTime,
                    usedEnd: endTime,
                    buffer: totalBuffer
                )
            }
        }

        return suggestions
    }

    // MARK: - Private Helpers

    private func sortReminders(_ reminders: [EKReminder]) -> [EKReminder] {
        reminders.sorted { reminderSortScore($0) < reminderSortScore($1) }
    }

    private func reminderSortScore(_ reminder: EKReminder) -> Double {
        let dueDate = reminder.dueDateComponents?.date
        let priority = TaskPriority.from(ekPriority: reminder.priority)
        let now = Date()
        let listName = reminder.calendar?.title ?? "Unknown"
        let title = reminder.title ?? "Untitled"

        var baseScore: Double

        // Overdue tasks first (lower score = higher priority)
        if let due = dueDate, due < now {
            let daysOverdue = Calendar.current.dateComponents([.day], from: due, to: now).day ?? 0
            baseScore = Double(-1000 + max(-daysOverdue, -999))
        } else if let due = dueDate, Calendar.current.isDateInToday(due) {
            // Due today
            baseScore = Double(priority.rawValue)
        } else if let due = dueDate, Calendar.current.isDate(due, equalTo: now, toGranularity: .weekOfYear) {
            // Due this week
            baseScore = 100 + Double(priority.rawValue)
        } else if dueDate != nil {
            // Has due date (future)
            baseScore = 200 + Double(priority.rawValue)
        } else {
            // No due date, sorted by priority
            baseScore = 300 + Double(priority.rawValue)
        }

        // Apply learned priority penalty (deprioritize "not important" tasks)
        let penalty = rescheduleLearning?.priorityPenalty(listName: listName, title: title) ?? 0
        if penalty < 0 {
            // Move deprioritized tasks further down the list
            baseScore += abs(penalty) * 100
        }

        return baseScore
    }

    private func determineDuration(for reminder: EKReminder) -> TimeInterval {
        // Check for duration hint in notes
        if let parsed = DurationParser.parse(reminder.notes) {
            return parsed
        }

        // Fall back to default
        return TimeInterval(settings.defaultTaskDuration * 60)
    }

    private func determineEnergyRequirement(for reminder: EKReminder) -> EnergyLevel {
        // Check list-based defaults
        if let listName = reminder.calendar?.title,
           let level = settings.listEnergyDefaults[listName] {
            return level
        }

        // Map priority to energy
        let priority = TaskPriority.from(ekPriority: reminder.priority)
        switch priority {
        case .high: return .highFocus
        case .medium: return .medium
        case .low, .none: return .low
        }
    }

    private func findBestSlot(
        duration: TimeInterval,
        in slots: [TimeSlot],
        listName: String? = nil,
        title: String? = nil
    ) -> (index: Int, startTime: Date)? {
        // If we have learning data, score slots by time-of-day preference
        if let listName, let title, let learning = rescheduleLearning {
            let scoredSlots = slots.enumerated().compactMap { (index, slot) -> (Int, Date, Double)? in
                guard slot.duration >= duration else { return nil }
                let hour = Calendar.current.component(.hour, from: slot.start)
                let score = learning.timeOfDayScore(listName: listName, title: title, hour: hour)
                let startTime: Date
                switch settings.slotPreference {
                case .morningFirst, .spreadEvenly:
                    startTime = slot.start
                case .afternoonFirst:
                    startTime = slot.end.addingTimeInterval(-duration)
                }
                return (index, startTime, score)
            }

            // If any slot has a non-zero score, pick the best
            if let best = scoredSlots.filter({ $0.2 > 0 }).max(by: { $0.2 < $1.2 }) {
                return (best.0, best.1)
            }

            // Fall through to default if no learned preferences
            if let first = scoredSlots.first {
                return (first.0, first.1)
            }
            return nil
        }

        // Default behavior without learning
        switch settings.slotPreference {
        case .morningFirst:
            return findFirstFittingSlot(duration: duration, in: slots)
        case .afternoonFirst:
            return findLastFittingSlot(duration: duration, in: slots)
        case .spreadEvenly:
            return findFirstFittingSlot(duration: duration, in: slots)
        }
    }

    private func findFirstFittingSlot(
        duration: TimeInterval,
        in slots: [TimeSlot]
    ) -> (index: Int, startTime: Date)? {
        for (index, slot) in slots.enumerated() {
            if slot.duration >= duration {
                return (index, slot.start)
            }
        }
        return nil
    }

    private func findLastFittingSlot(
        duration: TimeInterval,
        in slots: [TimeSlot]
    ) -> (index: Int, startTime: Date)? {
        for (index, slot) in slots.enumerated().reversed() {
            if slot.duration >= duration {
                // Place at the end of the slot
                let startTime = slot.end.addingTimeInterval(-duration)
                return (index, startTime)
            }
        }
        return nil
    }

    // MARK: - Slot Manipulation

    private func mergeOverlappingBlocks(_ blocks: [(Date, Date)]) -> [(Date, Date)] {
        guard !blocks.isEmpty else { return [] }

        let sorted = blocks.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = [sorted[0]]

        for block in sorted.dropFirst() {
            if block.0 <= merged[merged.count - 1].1 {
                merged[merged.count - 1].1 = max(merged[merged.count - 1].1, block.1)
            } else {
                merged.append(block)
            }
        }

        return merged
    }

    private func subtractBusyBlocks(
        availableStart: Date,
        availableEnd: Date,
        busyBlocks: [(Date, Date)]
    ) -> [TimeSlot] {
        var freeSlots: [TimeSlot] = []
        var currentStart = availableStart

        for busy in busyBlocks {
            let busyStart = busy.0
            let busyEnd = busy.1

            if busyStart > currentStart && busyStart < availableEnd {
                let slotEnd = min(busyStart, availableEnd)
                if slotEnd > currentStart {
                    freeSlots.append(TimeSlot(start: currentStart, end: slotEnd))
                }
            }

            currentStart = max(currentStart, busyEnd)
        }

        // Remaining time after last busy block
        if currentStart < availableEnd {
            freeSlots.append(TimeSlot(start: currentStart, end: availableEnd))
        }

        return freeSlots
    }

    private func applyBuffer(
        slots: [TimeSlot],
        busyBlocks: [(Date, Date)],
        buffer: TimeInterval
    ) -> [TimeSlot] {
        guard buffer > 0 else { return slots }

        return slots.compactMap { slot in
            var adjustedStart = slot.start
            var adjustedEnd = slot.end

            // If a busy block ends right at slot start, add buffer
            for busy in busyBlocks {
                if abs(busy.1.timeIntervalSince(slot.start)) < 1 {
                    adjustedStart = slot.start.addingTimeInterval(buffer)
                }
                if abs(busy.0.timeIntervalSince(slot.end)) < 1 {
                    adjustedEnd = slot.end.addingTimeInterval(-buffer)
                }
            }

            guard adjustedEnd > adjustedStart else { return nil }
            return TimeSlot(start: adjustedStart, end: adjustedEnd)
        }
    }

    private func consumeSlotTime(
        slots: [TimeSlot],
        slotIndex: Int,
        usedStart: Date,
        usedEnd: Date,
        buffer: TimeInterval
    ) -> [TimeSlot] {
        var result: [TimeSlot] = []

        for (index, slot) in slots.enumerated() {
            if index == slotIndex {
                // Split the slot around the used time
                let beforeEnd = usedStart.addingTimeInterval(-buffer)
                if beforeEnd > slot.start {
                    result.append(TimeSlot(start: slot.start, end: beforeEnd))
                }
                let afterStart = usedEnd.addingTimeInterval(buffer)
                if afterStart < slot.end {
                    result.append(TimeSlot(start: afterStart, end: slot.end))
                }
            } else {
                result.append(slot)
            }
        }

        return result
    }
}
