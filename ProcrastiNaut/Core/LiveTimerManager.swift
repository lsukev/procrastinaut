import AppKit
import Foundation

/// Manages a live countdown timer displayed in the menu bar during active tasks
@MainActor
@Observable
final class LiveTimerManager {
    var isRunning = false
    var activeTask: ProcrastiNautTask?
    var remainingSeconds: Int = 0
    var formattedTime: String = ""

    var onTimerTick: ((String) -> Void)?
    var onTimerComplete: ((ProcrastiNautTask) -> Void)?

    private var timer: Timer?

    func startTimer(for task: ProcrastiNautTask) {
        stopTimer()

        guard let endTime = task.suggestedEndTime else { return }

        activeTask = task
        isRunning = true
        updateRemaining(endTime: endTime)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateRemaining(endTime: endTime)

                if self.remainingSeconds <= 0 {
                    self.onTimerComplete?(task)
                    self.stopTimer()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        activeTask = nil
        remainingSeconds = 0
        formattedTime = ""
        onTimerTick?("")
    }

    private func updateRemaining(endTime: Date) {
        remainingSeconds = max(0, Int(endTime.timeIntervalSinceNow))

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            formattedTime = String(format: "%d:%02d:%02d", hours, mins, seconds)
        } else {
            formattedTime = String(format: "%d:%02d", minutes, seconds)
        }

        onTimerTick?(formattedTime)
    }

    var progress: Double {
        guard let task = activeTask,
              let start = task.suggestedStartTime,
              let end = task.suggestedEndTime else { return 0 }

        let total = end.timeIntervalSince(start)
        let elapsed = Date().timeIntervalSince(start)
        return min(1.0, max(0.0, elapsed / total))
    }
}
