import SwiftUI

struct UndoBannerView: View {
    let action: UndoableAction
    let onUndo: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(action.expiresAt.timeIntervalSince(context.date)))

            HStack {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(.blue)

                Text(actionText)
                    .font(.caption)

                Spacer()

                if remaining > 0 {
                    Button("Undo (\(remaining)s)") {
                        onUndo()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(8)
            .background(.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var actionText: String {
        switch action.action {
        case .completed:
            "Marked \"\(action.task.reminderTitle)\" as done"
        case .skipped:
            "Skipped \"\(action.task.reminderTitle)\""
        case .notDone(let reason):
            "Marked \"\(action.task.reminderTitle)\" not done — \(reason.displayName)"
        }
    }
}
