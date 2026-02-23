import AppKit

/// Handles keyboard shortcuts within the popover
enum PopoverShortcut: String {
    case approveAll = "a"
    case skip = "s"
    case startNow = "n"
    case quickAdd = "q"

    static func from(event: NSEvent) -> PopoverShortcut? {
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              !event.modifierFlags.contains(.command) else { return nil }
        return PopoverShortcut(rawValue: chars)
    }
}
