import SwiftUI

struct PlannerCalendarContainer: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var deleteKeyMonitor: Any?
    private let theme = AppTheme.shared

    /// True when a text field (NSTextView) is the current first responder.
    private var isTextFieldFocused: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                calendarHeader
                    .background(.regularMaterial)

                PlannerChatBar(viewModel: viewModel)

                // Error banner
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Mode-specific content
                switch viewModel.calendarViewMode {
                case .day:
                    PlannerCalendarView(viewModel: viewModel)
                case .week:
                    WeekCalendarView(viewModel: viewModel)
                case .month:
                    MonthCalendarView(viewModel: viewModel)
                case .year:
                    YearCalendarView(viewModel: viewModel)
                }
            }

            // Command palette overlay
            if viewModel.showCommandPalette {
                CommandPaletteView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.showCommandPalette)
        .confirmationDialog(
            "This is a recurring event. Which events do you want to move?",
            isPresented: $viewModel.showMoveRecurrenceChoice,
            titleVisibility: .visible
        ) {
            Button("This Event Only") {
                viewModel.confirmMoveRecurrenceAction(span: .thisEvent)
            }
            Button("All Future Events") {
                viewModel.confirmMoveRecurrenceAction(span: .futureEvents)
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingMoveEventID = nil
                viewModel.pendingMoveOccurrenceDate = nil
                viewModel.pendingMoveNewStart = nil
                viewModel.pendingMoveNewEnd = nil
            }
        }
        .sheet(isPresented: $viewModel.showCreateEvent) {
            CreateEventView(viewModel: viewModel)
        }
        .onAppear { installDeleteKeyMonitor() }
        .onDisappear { removeDeleteKeyMonitor() }
        // Force text fields to resign first responder when an event is selected
        .onChange(of: viewModel.editingEvent?.id) { _, newValue in
            if newValue != nil {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        // Keyboard shortcuts
        .onKeyPress(.escape) {
            if viewModel.showCommandPalette {
                viewModel.showCommandPalette = false
                return .handled
            }
            if viewModel.editingEvent != nil {
                viewModel.cancelEdit()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("t") {
            guard !viewModel.showCommandPalette,
                  !isTextFieldFocused else { return .ignored }
            viewModel.goToToday()
            return .handled
        }
        .onKeyPress("d") {
            guard !viewModel.showCommandPalette,
                  !isTextFieldFocused else { return .ignored }
            viewModel.calendarViewMode = .day
            Task { await viewModel.loadData() }
            return .handled
        }
        .onKeyPress("w") {
            guard !viewModel.showCommandPalette,
                  !isTextFieldFocused else { return .ignored }
            viewModel.calendarViewMode = .week
            Task { await viewModel.loadData() }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard !viewModel.showCommandPalette,
                  !isTextFieldFocused else { return .ignored }
            viewModel.navigate(offset: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !viewModel.showCommandPalette,
                  !isTextFieldFocused else { return .ignored }
            viewModel.navigate(offset: 1)
            return .handled
        }
        .background {
            // Hidden buttons for ⌘ keyboard shortcuts
            VStack {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.showCommandPalette.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)

                Button("") {
                    if viewModel.undoableAction != nil {
                        viewModel.executeUndo()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        }
    }

    // MARK: - Header

    private var calendarHeader: some View {
        VStack(spacing: 0) {
            // Date title row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.viewTitle)
                    .font(theme.scaledFont(size: 22, weight: .bold))

                if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Button {
                        viewModel.goToToday()
                    } label: {
                        Text("Today")
                            .font(theme.scaledFont(size: 12, weight: .medium))
                            .foregroundStyle(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Navigation controls row
            HStack(spacing: 8) {
                // Left nav
                Button {
                    viewModel.navigate(offset: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // View mode picker
                Picker("View", selection: $viewModel.calendarViewMode) {
                    ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .onChange(of: viewModel.calendarViewMode) { _, _ in
                    Task { await viewModel.loadData() }
                }

                // Right nav
                Button {
                    viewModel.navigate(offset: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Create new event
                Button {
                    viewModel.showCreateEvent = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Create new event")

                Spacer()

                // Left sidebar toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showTaskSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.showTaskSidebar ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(viewModel.showTaskSidebar
                                      ? AnyShapeStyle(theme.accentColor)
                                      : AnyShapeStyle(.quaternary.opacity(0.5)))
                        }
                }
                .buttonStyle(.plain)
                .help("Show/hide task sidebar")

                // Calendars toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showCalendarSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.showCalendarSidebar ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(viewModel.showCalendarSidebar
                                      ? AnyShapeStyle(theme.accentColor)
                                      : AnyShapeStyle(.quaternary.opacity(0.5)))
                        }
                }
                .buttonStyle(.plain)
                .help("Show/hide calendars")

                // AI suggestions button
                Button {
                    if viewModel.showAISuggestions {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.showAISuggestions = false
                        }
                    } else {
                        Task { await viewModel.requestAISuggestions() }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(viewModel.showAISuggestions ? .white : .purple)
                            .frame(width: 32, height: 32)
                            .background {
                                Circle()
                                    .fill(viewModel.showAISuggestions
                                          ? AnyShapeStyle(Color.purple)
                                          : AnyShapeStyle(.quaternary.opacity(0.5)))
                            }

                        if !viewModel.aiService.suggestions.isEmpty && !viewModel.showAISuggestions {
                            Text("\(viewModel.aiService.suggestions.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(.purple)
                                .clipShape(Circle())
                                .offset(x: 4, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.aiService.isProcessing && !viewModel.showAISuggestions)
                .help("AI Schedule suggestions")

                // Settings
                Button {
                    AppDelegate.shared?.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Delete Key Monitor

    /// Install a local event monitor that catches Delete/Backspace (keyCode 51)
    /// and Forward Delete (keyCode 117) to delete the selected event.
    /// Skips the shortcut when a text field is the first responder.
    private func installDeleteKeyMonitor() {
        deleteKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle Delete (51) and Forward Delete (117)
            guard event.keyCode == 51 || event.keyCode == 117 else { return event }

            // Don't intercept if the user is typing in a text field
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
                return event
            }

            guard let editingEvent = viewModel.editingEvent else { return event }

            withAnimation { viewModel.deleteEvent(id: editingEvent.id) }
            return nil // consume the event
        }
    }

    private func removeDeleteKeyMonitor() {
        if let monitor = deleteKeyMonitor {
            NSEvent.removeMonitor(monitor)
            deleteKeyMonitor = nil
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))

            Text(message)
                .font(.system(size: 11))
                .lineLimit(2)

            Spacer()

            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.orange.opacity(0.1))
    }

}
