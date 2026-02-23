import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ProcrastiNautEntry: TimelineEntry {
    let date: Date
    let nextTaskTitle: String?
    let nextTaskTime: String?
    let currentStreak: Int
    let tasksCompleted: Int
    let totalTasks: Int
}

// MARK: - Timeline Provider

struct ProcrastiNautProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProcrastiNautEntry {
        ProcrastiNautEntry(
            date: Date(),
            nextTaskTitle: "Write report",
            nextTaskTime: "2:30 PM",
            currentStreak: 5,
            tasksCompleted: 3,
            totalTasks: 7
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProcrastiNautEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProcrastiNautEntry>) -> Void) {
        // Read from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.procrastinaut.app") ?? .standard

        let entry = ProcrastiNautEntry(
            date: Date(),
            nextTaskTitle: defaults.string(forKey: "widget_nextTaskTitle"),
            nextTaskTime: defaults.string(forKey: "widget_nextTaskTime"),
            currentStreak: defaults.integer(forKey: "widget_currentStreak"),
            tasksCompleted: defaults.integer(forKey: "widget_tasksCompleted"),
            totalTasks: defaults.integer(forKey: "widget_totalTasks")
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct ProcrastiNautWidgetEntryView: View {
    var entry: ProcrastiNautEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("ProcrastiNaut")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            if let title = entry.nextTaskTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Up")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                    if let time = entry.nextTaskTime {
                        Text(time)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Text("No upcoming tasks")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                if entry.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(entry.currentStreak)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }

                Spacer()

                Text("\(entry.tasksCompleted)/\(entry.totalTasks)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: next task
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("ProcrastiNaut")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }

                if let title = entry.nextTaskTitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Up")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                        if let time = entry.nextTaskTime {
                            Text(time)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    Text("No upcoming tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Right: stats
            VStack(spacing: 8) {
                // Streak
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Streak")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                // Progress
                VStack(spacing: 2) {
                    Text("\(entry.tasksCompleted)/\(entry.totalTasks)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70)
        }
        .padding()
    }
}

// MARK: - Widget Declaration

struct ProcrastiNautWidget: Widget {
    let kind: String = "ProcrastiNautWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProcrastiNautProvider()) { entry in
            ProcrastiNautWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ProcrastiNaut")
        .description("See your next task and productivity streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct ProcrastiNautWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProcrastiNautWidget()
    }
}
