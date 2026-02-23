import SwiftUI

/// A compact live timer card shown in the popover during active tasks
struct LiveTimerView: View {
    let task: ProcrastiNautTask
    let remainingTime: String
    let progress: Double
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Task name
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)

                Text(task.reminderTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            // Timer display
            Text(remainingTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())

            // Circular progress
            ZStack {
                // Track
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 4)

                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .cyan, .blue],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: 60, height: 60)

            // Time range
            if let start = task.suggestedStartTime, let end = task.suggestedEndTime {
                Text("\(timeString(start)) - \(timeString(end))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var timerColor: Color {
        if let task = Optional(task), let end = task.suggestedEndTime {
            let remaining = end.timeIntervalSinceNow
            if remaining < 300 { return .red }     // < 5 min
            if remaining < 600 { return .orange }  // < 10 min
        }
        return .primary
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
