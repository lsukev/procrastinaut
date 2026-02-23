import Foundation

struct EnergyBlock: Identifiable, Codable, Sendable {
    let id: UUID
    var startTime: TimeInterval  // Seconds from midnight
    var endTime: TimeInterval    // Seconds from midnight
    var level: EnergyLevel

    init(startTime: TimeInterval, endTime: TimeInterval, level: EnergyLevel) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.level = level
    }

    /// Default energy blocks as described in the spec
    static let defaults: [EnergyBlock] = [
        EnergyBlock(startTime: 9 * 3600, endTime: 11 * 3600, level: .highFocus),     // 9-11 AM
        EnergyBlock(startTime: 11 * 3600, endTime: 12 * 3600, level: .medium),        // 11 AM-12 PM
        EnergyBlock(startTime: 13 * 3600, endTime: 14 * 3600, level: .low),           // 1-2 PM
        EnergyBlock(startTime: 14 * 3600, endTime: 16 * 3600, level: .medium),        // 2-4 PM
        EnergyBlock(startTime: 16 * 3600, endTime: 18 * 3600, level: .low),           // 4-6 PM
    ]
}
