import SwiftUI

struct PlannerSidebar: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var showOverdue = true
    private let theme = AppTheme.shared

    var body: some View {
        VStack(spacing: 0) {
            // Inbox — pending meeting invitations
            InboxSection(viewModel: viewModel)

            Divider()

            // Header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentColor)

                    Text("Reminders")
                        .font(.system(size: 14, weight: .semibold))

                    if viewModel.overdueCount > 0 {
                        Text("\(viewModel.overdueCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.red, in: Capsule())
                    }

                    Spacer()

                    Button {
                        viewModel.showCreateReminder = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Create new reminder")

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("\(viewModel.unplannedCount) to plan")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                // List filter — browse any reminder list on the device
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Picker("List", selection: $viewModel.selectedListFilter) {
                        Text("Monitored Lists").tag(nil as String?)
                        Divider()
                        ForEach(viewModel.allReminderLists) { list in
                            HStack {
                                Text(list.name)
                                if list.isMonitored {
                                    Text("★")
                                }
                            }.tag(list.name as String?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: viewModel.selectedListFilter) { _, _ in
                        Task { await viewModel.loadData() }
                    }
                }

                // Sort and filter controls
                HStack(spacing: 8) {
                    Picker("Sort", selection: $viewModel.sortMode) {
                        ForEach(ReminderSortMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)

                    Button {
                        viewModel.hideAlreadyPlanned.toggle()
                    } label: {
                        Image(systemName: viewModel.hideAlreadyPlanned ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundStyle(viewModel.hideAlreadyPlanned ? theme.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.hideAlreadyPlanned ? "Show planned reminders" : "Hide planned reminders")
                }
            }
            .padding(12)
            .background(.regularMaterial)

            Divider()

            // Reminder cards
            if viewModel.sortedReminders.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: viewModel.hideAlreadyPlanned ? "checkmark.seal.fill" : "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)

                    Text(viewModel.hideAlreadyPlanned ? "All planned!" : "No reminders")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(viewModel.hideAlreadyPlanned
                         ? "Toggle the eye icon to see planned items"
                         : "Select reminder lists in Settings")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                        // Overdue section
                        if !viewModel.overdueReminders.isEmpty {
                            overdueSectionHeader
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))

                            if showOverdue {
                                ForEach(viewModel.overdueReminders) { reminder in
                                    ReminderDragCard(reminder: reminder, viewModel: viewModel)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.red.opacity(0.3), lineWidth: 1)
                                        )
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                viewModel.deleteReminder(reminder)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                viewModel.completeReminder(reminder)
                                            } label: {
                                                Label("Complete", systemImage: "checkmark.circle")
                                            }
                                            .tint(.green)
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                }
                            }
                        }

                        ForEach(viewModel.sortedReminders) { reminder in
                            ReminderDragCard(reminder: reminder, viewModel: viewModel)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteReminder(reminder)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        viewModel.completeReminder(reminder)
                                    } label: {
                                        Label("Complete", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
            }

            Divider()

            // Templates section
            templateSection

            Divider()

            // Footer
            HStack {
                Text("\(viewModel.plannedCount) of \(viewModel.reminders.count) planned")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    Task { await viewModel.loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $viewModel.showCreateReminder) {
            CreateReminderView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingReminder) { reminder in
            EditReminderView(viewModel: viewModel, reminder: reminder)
        }
        .sheet(isPresented: $viewModel.showTemplateEditor) {
            TemplateEditorView()
        }
    }

    // MARK: - Templates Section

    private var templateSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("Templates")
                    .font(.system(size: 11, weight: .semibold))

                Spacer()

                Button {
                    viewModel.showTemplateEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit templates")
            }

            let templates = UserSettings.shared.eventTemplates
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(templates) { template in
                    TemplateDragCard(template: template)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Overdue Section Header

    private var overdueSectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showOverdue.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showOverdue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 12)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)

                Text("Overdue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)

                Text("\(viewModel.overdueCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.red, in: Capsule())

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }
}
