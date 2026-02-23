import SwiftUI

struct PlannerWindow: View {
    @State private var viewModel = PlannerViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PlannerSidebar(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    PlannerCalendarContainer(viewModel: viewModel)

                    if viewModel.calendarViewMode == .day {
                        Divider()
                        DayAgendaSidebar(viewModel: viewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    if viewModel.showCalendarSidebar {
                        Divider()
                        CalendarSidebarView(viewModel: viewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    if viewModel.showAISuggestions {
                        Divider()
                        AISuggestionsPanel(viewModel: viewModel)
                            .frame(width: 280)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    if viewModel.editingEvent != nil {
                        Divider()
                        EventContextPanel(viewModel: viewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.2) : nil, value: viewModel.calendarViewMode)
                .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.2) : nil, value: viewModel.showCalendarSidebar)
                .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.25) : nil, value: viewModel.showAISuggestions)
                .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.2) : nil, value: viewModel.editingEvent?.id)

                // Undo toast overlay
                if let undoAction = viewModel.undoableAction {
                    PlannerUndoToast(
                        action: undoAction,
                        onUndo: { viewModel.executeUndo() },
                        onDismiss: { viewModel.dismissUndo() }
                    )
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Focus timer mini widget - bottom right
                HStack {
                    Spacer()
                    PlannerMiniTimerView(viewModel: viewModel)
                        .padding(.trailing, 16)
                        .padding(.bottom, viewModel.undoableAction != nil ? 60 : 16)
                }
                .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.3) : nil, value: viewModel.focusTimerRunning)
            }
            .animation(AppTheme.shared.animationsEnabled ? .easeInOut(duration: 0.25) : nil, value: viewModel.undoableAction?.id)
        }
        .frame(minWidth: 900, idealWidth: 1400, minHeight: 650, idealHeight: 900)
        .preferredColorScheme(AppTheme.shared.preferredColorScheme)
        .onAppear {
            Task { await viewModel.loadData() }
            viewModel.startObservingChanges()
        }
        .onDisappear {
            viewModel.stopObservingChanges()
        }
        .onChange(of: viewModel.showTaskSidebar) { _, show in
            withAnimation(.easeInOut(duration: 0.2)) {
                columnVisibility = show ? .all : .detailOnly
            }
        }
    }
}
