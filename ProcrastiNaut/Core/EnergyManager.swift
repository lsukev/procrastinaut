import Foundation

@MainActor
final class EnergyManager {
    private let settings = UserSettings.shared

    /// Returns the energy level at a given time based on user-configured energy blocks
    func energyLevel(at date: Date) -> EnergyLevel {
        let secondsFromMidnight = date.secondsFromMidnight

        for block in settings.energyBlocks {
            if secondsFromMidnight >= block.startTime && secondsFromMidnight < block.endTime {
                return block.level
            }
        }

        return .medium // Default if no block covers this time
    }

    /// Annotate time slots with their energy levels
    func annotateSlots(_ slots: [TimeSlot]) -> [TimeSlot] {
        slots.map { slot in
            // Use the energy level at the midpoint of the slot
            let midpoint = slot.start.addingTimeInterval(slot.duration / 2)
            var annotated = slot
            annotated.energyLevel = energyLevel(at: midpoint)
            return annotated
        }
    }

    /// Find the best slot for a task considering energy level matching
    func findBestEnergyMatch(
        taskEnergy: EnergyLevel,
        slots: [TimeSlot],
        duration: TimeInterval,
        preference: UserSettings.SlotPreference
    ) -> (index: Int, startTime: Date)? {
        // First try to find a slot with matching energy
        let annotated = annotateSlots(slots)

        // Priority: exact match > adjacent level > any level
        for targetLevel in energyPriorityOrder(for: taskEnergy) {
            let matching = annotated.enumerated().filter { $0.element.energyLevel == targetLevel && $0.element.duration >= duration }

            if !matching.isEmpty {
                switch preference {
                case .morningFirst:
                    if let first = matching.first {
                        return (first.offset, first.element.start)
                    }
                case .afternoonFirst:
                    if let last = matching.last {
                        let startTime = last.element.end.addingTimeInterval(-duration)
                        return (last.offset, startTime)
                    }
                case .spreadEvenly:
                    // Pick the middle one
                    let mid = matching[matching.count / 2]
                    return (mid.offset, mid.element.start)
                }
            }
        }

        return nil
    }

    /// Returns energy levels in priority order for matching
    private func energyPriorityOrder(for target: EnergyLevel) -> [EnergyLevel] {
        switch target {
        case .highFocus: [.highFocus, .medium, .low]
        case .medium: [.medium, .highFocus, .low]
        case .low: [.low, .medium, .highFocus]
        }
    }
}
