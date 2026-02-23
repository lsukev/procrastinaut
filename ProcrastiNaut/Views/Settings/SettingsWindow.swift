import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case calendars = "Calendars"
    case reminders = "Reminders"
    case schedule = "Schedule"
    case energy = "Energy"
    case notifications = "Notifications"
    case ai = "AI"
    case outlook = "Outlook"
    case gamification = "Gamification"
    case data = "Data"
    case advanced = "Advanced"

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .calendars: "calendar"
        case .reminders: "list.bullet"
        case .schedule: "clock"
        case .energy: "bolt.fill"
        case .notifications: "bell.fill"
        case .ai: "sparkles"
        case .outlook: "envelope.fill"
        case .gamification: "star.fill"
        case .data: "externaldrive"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}

struct SettingsWindow: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 160, max: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .calendars:
                    CalendarSettingsView()
                case .reminders:
                    ReminderSettingsView()
                case .schedule:
                    ScheduleSettingsView()
                case .energy:
                    EnergySettingsView()
                case .notifications:
                    NotificationSettingsView()
                case .ai:
                    AISettingsView()
                case .outlook:
                    OutlookSettingsView()
                case .gamification:
                    GamificationSettingsView()
                case .data:
                    DataSettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .frame(minWidth: 400)
            .padding()
        }
        .frame(minWidth: 550, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .preferredColorScheme(AppTheme.shared.preferredColorScheme)
    }
}
