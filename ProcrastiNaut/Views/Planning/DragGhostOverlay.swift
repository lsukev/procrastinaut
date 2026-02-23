import SwiftUI
import UniformTypeIdentifiers

struct DragGhostOverlay: View {
    @Bindable var viewModel: PlannerViewModel
    let hourHeight: CGFloat
    let timeGutterWidth: CGFloat

    var body: some View {
        if let ghostTime = viewModel.dragGhostTime {
            let title = viewModel.dragGhostTitle ?? "New Event"
            let y = CalendarLayoutHelpers.yPosition(for: ghostTime, hourHeight: hourHeight)
            let height = max(24, CGFloat(viewModel.dragGhostDuration / 60) / 60 * hourHeight)
            let ghostPurple = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6

            GeometryReader { geo in
                let availableWidth = geo.size.width - timeGutterWidth - 12
                let xOffset = timeGutterWidth + 8

                ZStack(alignment: .topLeading) {
                    // Ghost block
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(ghostPurple.opacity(0.15))
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ghostPurple.opacity(0.6))
                                    .frame(width: 4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(ghostPurple.opacity(0.9))
                                        .lineLimit(1)

                                    Text(ghostTimeString(ghostTime))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(ghostPurple.opacity(0.7))
                                }
                                .padding(.leading, 6)
                                .padding(.vertical, 4)

                                Spacer()
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(
                                    ghostPurple.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                                )
                        )
                        .frame(width: availableWidth - 3, height: height)
                        .position(x: xOffset + (availableWidth - 3) / 2, y: y + height / 2)

                    // Time label on the left gutter
                    Text(ghostTimeString(ghostTime))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ghostPurple)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(ghostPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        .position(x: timeGutterWidth / 2, y: y)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func ghostTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Week Drag Ghost Overlay

struct WeekDragGhostOverlay: View {
    @Bindable var viewModel: PlannerViewModel
    let hourHeight: CGFloat
    let timeGutterWidth: CGFloat
    let columnWidth: CGFloat
    let dayIndex: Int

    var body: some View {
        if let ghostTime = viewModel.dragGhostTime {
            let title = viewModel.dragGhostTitle ?? "New Event"
            let y = CalendarLayoutHelpers.yPosition(for: ghostTime, hourHeight: hourHeight)
            let height = max(20, CGFloat(viewModel.dragGhostDuration / 60) / 60 * hourHeight)
            let ghostPurple = Color(red: 0.545, green: 0.361, blue: 0.965)

            let dayXOffset = timeGutterWidth + 8 + columnWidth * CGFloat(dayIndex)
            let blockWidth = columnWidth - 4
            let xPos = dayXOffset + blockWidth / 2

            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ghostPurple.opacity(0.15))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(ghostPurple.opacity(0.6))
                                .frame(width: 3)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(title)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(ghostPurple.opacity(0.9))
                                    .lineLimit(1)

                                Text(weekGhostTimeString(ghostTime))
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(ghostPurple.opacity(0.7))
                            }
                            .padding(.leading, 3)
                            .padding(.vertical, 2)

                            Spacer(minLength: 0)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                ghostPurple.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                            )
                    )
                    .frame(width: blockWidth, height: height)
                    .position(x: xPos, y: y + height / 2)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func weekGhostTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Day Calendar Drop Delegate

@MainActor
struct DayCalendarDropDelegate: DropDelegate {
    let viewModel: PlannerViewModel
    let hourHeight: CGFloat
    let selectedDate: Date

    nonisolated func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    nonisolated func dropUpdated(info: DropInfo) -> DropProposal? {
        let locationY = info.location.y
        var needsLoad = false
        MainActor.assumeIsolated {
            let rawTime = CalendarLayoutHelpers.timeFromYPosition(
                locationY, hourHeight: hourHeight, on: selectedDate
            )
            viewModel.dragGhostTime = viewModel.snapToGrid(rawTime)

            // Eagerly resolve drag item identity on first call
            if viewModel.dragGhostTitle == nil {
                needsLoad = true
                // Fallback title while async load completes
                viewModel.dragGhostTitle = "New Event"
            }
        }
        if needsLoad {
            loadDragItemID(from: info)
        }
        return DropProposal(operation: .move)
    }

    nonisolated func performDrop(info: DropInfo) -> Bool {
        let locationY = info.location.y
        let capturedHourHeight = hourHeight
        let capturedDate = selectedDate

        var dropped = false
        for provider in info.itemProviders(for: [.plainText]) {
            dropped = true
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let itemID = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    let dropTime = CalendarLayoutHelpers.timeFromYPosition(
                        locationY, hourHeight: capturedHourHeight, on: capturedDate
                    )
                    viewModel.clearDragGhost()
                    viewModel.handleDrop(itemID: itemID, atTime: dropTime)
                }
            }
        }
        return dropped
    }

    nonisolated func dropExited(info: DropInfo) {
        Task { @MainActor in
            viewModel.clearDragGhost()
        }
    }

    /// Eagerly load the dragged item ID so we can show proper ghost title & duration.
    private nonisolated func loadDragItemID(from info: DropInfo) {
        for provider in info.itemProviders(for: [.plainText]) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let itemID = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    viewModel.updateDragGhost(
                        itemID: itemID,
                        at: 0, // position doesn't matter, just need to set title/duration
                        hourHeight: 60,
                        on: Date()
                    )
                }
            }
        }
    }
}

// MARK: - Week Calendar Drop Delegate

@MainActor
struct WeekCalendarDropDelegate: DropDelegate {
    let viewModel: PlannerViewModel
    let hourHeight: CGFloat
    let timeGutterWidth: CGFloat
    let computedColumnWidth: CGFloat

    nonisolated func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    nonisolated func dropUpdated(info: DropInfo) -> DropProposal? {
        let locationX = info.location.x
        let locationY = info.location.y
        var needsLoad = false

        MainActor.assumeIsolated {
            let dates = viewModel.weekDates
            guard !dates.isEmpty else { return }

            let adjustedX = locationX - timeGutterWidth - 8
            let dayIndex = min(6, max(0, Int(adjustedX / computedColumnWidth)))
            let date = dates[dayIndex]

            let rawTime = CalendarLayoutHelpers.timeFromYPosition(
                locationY, hourHeight: hourHeight, on: date
            )
            viewModel.dragGhostTime = viewModel.snapToGrid(rawTime)

            // Eagerly resolve drag item identity on first call
            if viewModel.dragGhostTitle == nil {
                needsLoad = true
                viewModel.dragGhostTitle = "New Event"
            }
        }
        if needsLoad {
            loadDragItemID(from: info)
        }
        return DropProposal(operation: .move)
    }

    nonisolated func performDrop(info: DropInfo) -> Bool {
        let locationX = info.location.x
        let locationY = info.location.y
        let capturedHourHeight = hourHeight
        let capturedGutterWidth = timeGutterWidth
        let capturedColumnWidth = computedColumnWidth

        var dropped = false
        for provider in info.itemProviders(for: [.plainText]) {
            dropped = true
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let itemID = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    let dates = viewModel.weekDates
                    guard !dates.isEmpty else { return }

                    let adjustedX = locationX - capturedGutterWidth - 8
                    let dayIndex = min(6, max(0, Int(adjustedX / capturedColumnWidth)))
                    let date = dates[dayIndex]

                    let dropTime = CalendarLayoutHelpers.timeFromYPosition(
                        locationY, hourHeight: capturedHourHeight, on: date
                    )
                    viewModel.clearDragGhost()
                    viewModel.handleDrop(itemID: itemID, atTime: dropTime)
                }
            }
        }
        return dropped
    }

    nonisolated func dropExited(info: DropInfo) {
        Task { @MainActor in
            viewModel.clearDragGhost()
        }
    }

    /// Eagerly load the dragged item ID so we can show proper ghost title & duration.
    private nonisolated func loadDragItemID(from info: DropInfo) {
        for provider in info.itemProviders(for: [.plainText]) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let itemID = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    viewModel.updateDragGhost(
                        itemID: itemID,
                        at: 0,
                        hourHeight: 60,
                        on: Date()
                    )
                }
            }
        }
    }
}
