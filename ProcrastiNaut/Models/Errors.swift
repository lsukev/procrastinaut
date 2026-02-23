import Foundation

enum ProcrastiNautError: LocalizedError {
    case reminderNotFound
    case calendarAccessDenied
    case remindersAccessDenied
    case eventCreationFailed
    case conflictDetected(details: String)
    case noAvailableSlots
    case calendarNotFound
    case calendarReadOnly(name: String)
    case eventNotFound
    case aiAPIKeyMissing
    case aiRequestFailed(String)
    case aiResponseInvalid

    var errorDescription: String? {
        switch self {
        case .reminderNotFound:
            "The reminder could not be found. It may have been deleted."
        case .calendarAccessDenied:
            "Calendar access is required. Please grant access in System Settings."
        case .remindersAccessDenied:
            "Reminders access is required. Please grant access in System Settings."
        case .eventCreationFailed:
            "Failed to create the calendar event."
        case .conflictDetected(let details):
            "A scheduling conflict was detected: \(details)"
        case .noAvailableSlots:
            "No available time slots were found for today."
        case .calendarNotFound:
            "The target calendar could not be found."
        case .calendarReadOnly(let name):
            "Cannot modify events on \"\(name)\" — it is a read-only calendar."
        case .eventNotFound:
            "The event could not be found. It may have been deleted."
        case .aiAPIKeyMissing:
            "Please add your Claude API key in Settings > AI."
        case .aiRequestFailed(let details):
            "AI scheduling failed: \(details)"
        case .aiResponseInvalid:
            "Could not parse AI scheduling response."
        }
    }
}
