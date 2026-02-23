import Foundation

struct EventTemplate: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var duration: TimeInterval   // seconds
    var color: String            // system color name
    var icon: String             // SF Symbol name

    var durationMinutes: Int {
        Int(duration / 60)
    }

    static let defaults: [EventTemplate] = [
        EventTemplate(
            id: UUID(),
            name: "Focus Block",
            duration: 5400,  // 90 min
            color: "purple",
            icon: "brain"
        ),
        EventTemplate(
            id: UUID(),
            name: "Meeting",
            duration: 1800,  // 30 min
            color: "blue",
            icon: "person.2"
        ),
        EventTemplate(
            id: UUID(),
            name: "Break",
            duration: 900,   // 15 min
            color: "green",
            icon: "cup.and.saucer"
        ),
        EventTemplate(
            id: UUID(),
            name: "Deep Work",
            duration: 7200,  // 120 min
            color: "indigo",
            icon: "laptopcomputer"
        ),
    ]
}
