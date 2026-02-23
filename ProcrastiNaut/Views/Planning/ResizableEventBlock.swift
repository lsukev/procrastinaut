import SwiftUI

/// A wrapper for event blocks that adds a drag-to-resize handle at the bottom edge.
struct ResizableEventBlock: View {
    @Bindable var viewModel: PlannerViewModel
    let event: CalendarEventItem
    let hourHeight: CGFloat
    let baseHeight: CGFloat

    @State private var dragDeltaY: CGFloat = 0
    @State private var isDraggingResize = false
    @State private var isHoveringHandle = false

    private let handleHeight: CGFloat = 6
    private let minDurationMinutes: CGFloat = 15

    private var currentHeight: CGFloat {
        let h = baseHeight + dragDeltaY
        let minHeight = minDurationMinutes / 60 * hourHeight
        return max(minHeight, h)
    }

    /// The new end time based on current drag delta
    private var previewEndTime: Date {
        let deltaMinutes = Double(dragDeltaY) / Double(hourHeight) * 60
        let newDuration = event.endDate.timeIntervalSince(event.startDate) + (deltaMinutes * 60)
        let clampedDuration = max(Double(minDurationMinutes) * 60, newDuration)
        let rawEnd = event.startDate.addingTimeInterval(clampedDuration)
        return viewModel.snapToGrid(rawEnd)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The content slot will be overlaid by the caller
            Color.clear
                .frame(height: currentHeight)

            // Resize handle zone at bottom
            VStack(spacing: 0) {
                Spacer()
                resizeHandle
            }
        }
        .frame(height: currentHeight)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: handleHeight)
            .contentShape(Rectangle())
            .overlay {
                if isHoveringHandle || isDraggingResize {
                    Capsule()
                        .fill(.white.opacity(0.6))
                        .frame(width: 20, height: 3)
                        .transition(.opacity)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHoveringHandle = hovering
                }
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else if !isDraggingResize {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDraggingResize = true
                        dragDeltaY = value.translation.height
                    }
                    .onEnded { _ in
                        isDraggingResize = false
                        let newEnd = previewEndTime
                        viewModel.resizeEvent(event, newEndDate: newEnd)
                        dragDeltaY = 0
                        NSCursor.pop()
                    }
            )
    }
}

// MARK: - Resize Time Label

struct ResizeTimeLabel: View {
    let time: Date

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.black.opacity(0.5), in: Capsule())
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: time)
    }
}
