import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var commands: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = [
            CommandPaletteItem(title: "Go to Today", subtitle: "T", icon: "calendar.circle", iconColor: .blue) {
                viewModel.goToToday()
                dismiss()
            },
            CommandPaletteItem(title: "Day View", subtitle: "D", icon: "calendar.day.timeline.left", iconColor: .blue) {
                viewModel.calendarViewMode = .day
                Task { await viewModel.loadData() }
                dismiss()
            },
            CommandPaletteItem(title: "Week View", subtitle: "W", icon: "calendar.day.timeline.trailing", iconColor: .blue) {
                viewModel.calendarViewMode = .week
                Task { await viewModel.loadData() }
                dismiss()
            },
            CommandPaletteItem(title: "Toggle Sidebar", subtitle: "⌘S", icon: "sidebar.left", iconColor: .gray) {
                withAnimation { viewModel.showCalendarSidebar.toggle() }
                dismiss()
            },
            CommandPaletteItem(title: "Toggle AI Panel", subtitle: nil, icon: "sparkles", iconColor: .purple) {
                if viewModel.showAISuggestions {
                    withAnimation { viewModel.showAISuggestions = false }
                } else {
                    Task { await viewModel.requestAISuggestions() }
                }
                dismiss()
            },
            CommandPaletteItem(title: "Navigate Back", subtitle: "←", icon: "chevron.left", iconColor: .gray) {
                viewModel.navigate(offset: -1)
                dismiss()
            },
            CommandPaletteItem(title: "Navigate Forward", subtitle: "→", icon: "chevron.right", iconColor: .gray) {
                viewModel.navigate(offset: 1)
                dismiss()
            },
            CommandPaletteItem(title: "New Reminder", subtitle: nil, icon: "plus.circle", iconColor: .green) {
                viewModel.showCreateReminder = true
                dismiss()
            },
        ]

        // Add today's events as searchable items
        let todayEvents = viewModel.events(for: Date()).filter { !$0.isAllDay }
        for event in todayEvents.prefix(5) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            items.append(CommandPaletteItem(
                title: event.title,
                subtitle: f.string(from: event.startDate),
                icon: "calendar",
                iconColor: Color(cgColor: event.calendarColor)
            ) {
                viewModel.startEditing(event)
                dismiss()
            })
        }

        // Add reminders as searchable items
        for reminder in viewModel.reminders.prefix(5) {
            items.append(CommandPaletteItem(
                title: reminder.title,
                subtitle: reminder.listName,
                icon: "checklist",
                iconColor: .orange
            ) {
                dismiss()
            })
        }

        return items
    }

    private var filteredCommands: [CommandPaletteItem] {
        if searchText.isEmpty { return commands }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Palette card
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    TextField("Type a command or search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isSearchFocused)
                        .onSubmit {
                            executeSelected()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("esc")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                // Results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, item in
                            commandRow(item: item, isSelected: index == selectedIndex)
                                .onTapGesture {
                                    item.action()
                                }
                        }
                    }
                }
                .frame(maxHeight: 320)

                if filteredCommands.isEmpty {
                    VStack(spacing: 6) {
                        Text("No results")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 60)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .frame(width: 480)
            .offset(y: -60) // Position slightly above center
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func commandRow(item: CommandPaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(item.iconColor)
                .frame(width: 24, height: 24)
                .background(item.iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))

            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    private func executeSelected() {
        guard !filteredCommands.isEmpty else { return }
        let index = min(selectedIndex, filteredCommands.count - 1)
        filteredCommands[index].action()
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.showCommandPalette = false
        }
    }
}
