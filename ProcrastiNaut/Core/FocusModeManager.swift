import AppKit

/// Integrates with macOS Focus modes by toggling Do Not Disturb during active tasks
@MainActor
final class FocusModeManager {
    static let shared = FocusModeManager()

    private let settings = UserSettings.shared
    private var wasActivatedByUs = false

    /// Enable Focus (Do Not Disturb) when a task starts
    func enableFocus() {
        guard settings.enableFocusMode else { return }

        // Uses Apple Shortcuts — user should create shortcuts named
        // "ProcrastiNaut Focus On" and "ProcrastiNaut Focus Off"
        runShortcut("ProcrastiNaut Focus On")
        wasActivatedByUs = true
    }

    /// Disable Focus when a task completes
    func disableFocus() {
        guard settings.enableFocusMode, wasActivatedByUs else { return }

        runShortcut("ProcrastiNaut Focus Off")
        wasActivatedByUs = false
    }

    private func runShortcut(_ name: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]

        do {
            try task.run()
        } catch {
            print("Failed to run shortcut '\(name)': \(error)")
        }
    }
}
