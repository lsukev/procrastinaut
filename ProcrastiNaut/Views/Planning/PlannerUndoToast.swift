import SwiftUI

// MARK: - Undo Action Model

struct PlannerUndoAction: Sendable {
    let id: UUID
    let description: String
    let undoClosure: @Sendable () async -> Void
    let createdAt: Date
    let duration: TimeInterval  // auto-dismiss duration

    init(description: String, duration: TimeInterval = 8.0, undo: @escaping @Sendable () async -> Void) {
        self.id = UUID()
        self.description = description
        self.undoClosure = undo
        self.createdAt = Date()
        self.duration = duration
    }

    var remainingTime: TimeInterval {
        max(0, duration - Date().timeIntervalSince(createdAt))
    }

    var progress: Double {
        1.0 - (remainingTime / duration)
    }
}

// MARK: - Undo Toast View

struct PlannerUndoToast: View {
    let action: PlannerUndoAction
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)

                    Text(action.description)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        onUndo()
                    } label: {
                        Text("Undo")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // Progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(.blue.opacity(0.3))
                        .frame(width: geo.size.width * (1.0 - action.progress), height: 2)
                }
                .frame(height: 2)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .frame(maxWidth: 420)
    }
}
