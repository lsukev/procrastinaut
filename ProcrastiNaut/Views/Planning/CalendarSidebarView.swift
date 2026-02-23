import SwiftUI
import EventKit

struct CalendarSidebarView: View {
    @Bindable var viewModel: PlannerViewModel

    @State private var availableCalendars: [EKCalendar] = []
    @State private var viewableIDs: Set<String> = []
    @State private var monitoredIDs: Set<String> = []

    private let settings = UserSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Calendars")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showCalendarSidebar = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Column labels
            HStack(spacing: 0) {
                Spacer()
                Image(systemName: "eye")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .help("View — show events on calendar")
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .help("Monitor — use for busy-time detection")
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Calendar list grouped by source
            ScrollView {
                let grouped = groupedCalendars
                let sortedKeys = grouped.keys.sorted()

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedKeys, id: \.self) { source in
                        if let calendars = grouped[source] {
                            calendarSection(source: source, calendars: calendars)
                        }
                    }
                }
                .padding(12)
            }

            Divider()

            // Quick actions
            HStack(spacing: 12) {
                Button("All") {
                    let allIDs = Set(availableCalendars.map(\.calendarIdentifier))
                    viewableIDs = allIDs
                    monitoredIDs = allIDs
                    saveAndReload()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button("None") {
                    viewableIDs.removeAll()
                    monitoredIDs.removeAll()
                    saveAndReload()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
        .onAppear {
            loadCalendars()
        }
    }

    // MARK: - Calendar Section

    private func calendarSection(source: String, calendars: [EKCalendar]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                calendarRow(calendar)
            }
        }
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let calID = calendar.calendarIdentifier
        let isViewable = viewableIDs.contains(calID)
        let isMonitored = monitoredIDs.contains(calID)

        return HStack(spacing: 6) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 8, height: 8)

            Text(calendar.title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // View toggle (eye)
            Button {
                if isViewable {
                    viewableIDs.remove(calID)
                } else {
                    viewableIDs.insert(calID)
                }
                saveAndReload()
            } label: {
                Image(systemName: isViewable ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(isViewable ? Color(cgColor: calendar.cgColor) : .secondary.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("View — show on calendar")

            // Monitor toggle (antenna)
            Button {
                if isMonitored {
                    monitoredIDs.remove(calID)
                } else {
                    monitoredIDs.insert(calID)
                }
                saveAndReload()
            } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11))
                    .foregroundStyle(isMonitored ? .orange : .secondary.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Monitor — busy-time detection")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var groupedCalendars: [String: [EKCalendar]] {
        Dictionary(grouping: availableCalendars) { $0.source.title }
    }

    private func loadCalendars() {
        availableCalendars = EventKitManager.shared.getAvailableCalendars()
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        viewableIDs = Set(settings.viewableCalendarIDs)
        monitoredIDs = Set(settings.monitoredCalendarIDs)
    }

    private func saveAndReload() {
        settings.viewableCalendarIDs = Array(viewableIDs)
        settings.monitoredCalendarIDs = Array(monitoredIDs)
        Task { await viewModel.loadData() }
    }
}
