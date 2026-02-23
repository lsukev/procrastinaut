import AppKit

/// Plays system sounds for task events
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let settings = UserSettings.shared

    func playTaskComplete() {
        guard settings.enableCompletionSounds else { return }
        NSSound(named: "Glass")?.play()
    }

    func playMilestone() {
        guard settings.enableCompletionSounds else { return }
        NSSound(named: "Hero")?.play()
    }

    func playWarning() {
        NSSound(named: "Basso")?.play()
    }

    func playTimerEnd() {
        guard settings.enableCompletionSounds else { return }
        NSSound(named: "Purr")?.play()
    }
}
