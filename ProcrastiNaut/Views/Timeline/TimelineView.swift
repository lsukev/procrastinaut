import SwiftUI

/// A visual vertical timeline showing the day's schedule as blocks
struct DayTimelineView: View {
    let tasks: [ProcrastiNautTask]
    let workStart: Double  // seconds from midnight
    let workEnd: Double

    @State private var now = Date()

    private let hourHeight: CGFloat = 50
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "timeline.selection")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("Timeline")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(todayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Hour grid
                        hourGrid

                        // Task blocks
                        ForEach(tasks.filter { $0.suggestedStartTime != nil }) { task in
                            taskBlock(task)
                        }

                        // Current time indicator
                        currentTimeIndicator
                            .id("now")
                    }
                    .frame(height: totalHeight)
                }
                .onAppear {
                    proxy.scrollTo("now", anchor: .center)
                }
            }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        ForEach(startHour..<endHour, id: \.self) { hour in
            HStack(alignment: .top, spacing: 8) {
                Text(hourLabel(hour))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)

                VStack(spacing: 0) {
                    Divider()
                    Spacer()
                }
            }
            .frame(height: hourHeight)
            .offset(y: yOffset(forHour: hour))
        }
    }

    // MARK: - Task Blocks

    private func taskBlock(_ task: ProcrastiNautTask) -> some View {
        let y = yPosition(for: task.suggestedStartTime!)
        let height = max(20, blockHeight(for: task))

        return HStack(spacing: 0) {
            Spacer().frame(width: 48)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(taskColor(task).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(taskColor(task).opacity(0.4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(taskColor(task))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(task.reminderTitle)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)

                            if let start = task.suggestedStartTime {
                                Text(timeString(start))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: height)
        }
        .offset(y: y)
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        let y = yPosition(for: now)

        return HStack(spacing: 0) {
            Spacer().frame(width: 36)

            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(.red.opacity(0.6))
                .frame(height: 1)
        }
        .offset(y: y - 4)
    }

    // MARK: - Helpers

    private var startHour: Int {
        max(0, Int(workStart / 3600))
    }

    private var endHour: Int {
        min(24, Int(workEnd / 3600) + 1)
    }

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    private func yOffset(forHour hour: Int) -> CGFloat {
        CGFloat(hour - startHour) * hourHeight
    }

    private func yPosition(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let totalMinutes = CGFloat(hour * 60 + minute)
        let startMinutes = CGFloat(startHour * 60)
        return (totalMinutes - startMinutes) / 60 * hourHeight
    }

    private func blockHeight(for task: ProcrastiNautTask) -> CGFloat {
        let duration = task.suggestedDuration / 60  // minutes
        return CGFloat(duration) / 60 * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func taskColor(_ task: ProcrastiNautTask) -> Color {
        switch task.status {
        case .completed: .green
        case .inProgress: .orange
        case .approved: .blue
        default: .gray
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }
}
