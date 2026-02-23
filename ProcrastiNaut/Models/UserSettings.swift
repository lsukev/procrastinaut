import SwiftUI

@MainActor
final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    // MARK: - Timing (stored as TimeInterval = seconds from midnight)

    @AppStorage("morningScanTime") var morningScanTime: Double = 27000              // 7:30 AM
    @AppStorage("workingHoursStart") var workingHoursStart: Double = 28800           // 8:00 AM
    @AppStorage("workingHoursEnd") var workingHoursEnd: Double = 64800               // 6:00 PM
    @AppStorage("weeklyPlanningTime") var weeklyPlanningTime: Double = 64800         // 6:00 PM

    // MARK: - Task Scheduling

    @AppStorage("defaultTaskDuration") var defaultTaskDuration: Int = 30              // minutes
    @AppStorage("minimumSlotSize") var minimumSlotSize: Int = 15                      // minutes
    @AppStorage("bufferBetweenBlocks") var bufferBetweenBlocks: Int = 10              // minutes
    @AppStorage("followUpDelay") var followUpDelay: Int = 5                            // minutes
    @AppStorage("maxSuggestionsPerDay") var maxSuggestionsPerDay: Int = 10
    @AppStorage("prioritySorting") var prioritySorting: Bool = true
    @AppStorage("preferredSlotTimes") var preferredSlotTimes: String = "morning_first"
    @AppStorage("autoApproveRecurring") var autoApproveRecurring: Bool = false

    // MARK: - Energy & Focus

    @AppStorage("matchEnergyToTasks") var matchEnergyToTasks: Bool = true

    // MARK: - Gamification

    @AppStorage("showCompletionStats") var showCompletionStats: Bool = true
    @AppStorage("enableStreaks") var enableStreaks: Bool = true
    @AppStorage("streakThreshold") var streakThreshold: Double = 0.8
    @AppStorage("enableBadges") var enableBadges: Bool = true
    @AppStorage("enableStreakFreeze") var enableStreakFreeze: Bool = false
    @AppStorage("maxFreezesPerWeek") var maxFreezesPerWeek: Int = 1

    // MARK: - Duration Learning

    @AppStorage("enableDurationLearning") var enableDurationLearning: Bool = true

    // MARK: - Data Management

    @AppStorage("archiveAfterDays") var archiveAfterDays: Int = 90
    @AppStorage("deleteArchivedAfterDays") var deleteArchivedAfterDays: Int = 365

    // MARK: - Notifications (In-App Follow-Ups)

    @AppStorage("followUpRateLimit") var followUpRateLimit: Int = 120                 // seconds
    @AppStorage("undoWindowDuration") var undoWindowDuration: Int = 30                // seconds

    // MARK: - System Notifications

    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("notifyEventReminders") var notifyEventReminders: Bool = true
    @AppStorage("eventReminderMinutes") var eventReminderMinutes: Int = 15            // minutes before
    @AppStorage("notifyOverdueReminders") var notifyOverdueReminders: Bool = true
    @AppStorage("notifyDailySummary") var notifyDailySummary: Bool = true
    @AppStorage("notifyFocusTimerEnd") var notifyFocusTimerEnd: Bool = true
    @AppStorage("notifyConflicts") var notifyConflicts: Bool = true
    @AppStorage("notifyInvitations") var notifyInvitations: Bool = true
    @AppStorage("quietHoursEnabled") var quietHoursEnabled: Bool = false
    @AppStorage("quietHoursStart") var quietHoursStart: Double = 79200                // 10:00 PM
    @AppStorage("quietHoursEnd") var quietHoursEnd: Double = 25200                    // 7:00 AM
    @AppStorage("notificationSound") var notificationSound: String = "default"

    // MARK: - Weekly Planning

    @AppStorage("weeklyPlanningEnabled") var weeklyPlanningEnabled: Bool = false
    @AppStorage("weeklyPlanningDay") var weeklyPlanningDay: Int = 1                   // 1=Sunday

    // MARK: - Calendar Display

    @AppStorage("eventColorMode") var eventColorMode: String = "priority"

    // MARK: - Weather

    @AppStorage("temperatureUnit") var temperatureUnit: String = "fahrenheit"
    @AppStorage("showWeatherInMonthView") var showWeatherInMonthView: Bool = true
    @AppStorage("cachedLatitude") var cachedLatitude: Double = 0.0
    @AppStorage("cachedLongitude") var cachedLongitude: Double = 0.0

    // MARK: - Sounds & Effects

    @AppStorage("enableCompletionSounds") var enableCompletionSounds: Bool = true
    @AppStorage("enableConfetti") var enableConfetti: Bool = true

    // MARK: - Appearance

    @AppStorage("accentColorName") var accentColorName: String = "blue"
    @AppStorage("fontSizeTier") var fontSizeTier: String = "standard"       // small, standard, large
    @AppStorage("calendarDensity") var calendarDensity: String = "comfortable"  // comfortable, compact
    @AppStorage("nowLineColorName") var nowLineColorName: String = "red"
    @AppStorage("animationsEnabled") var animationsEnabled: Bool = true
    @AppStorage("appearanceMode") var appearanceMode: String = "system"     // system, light, dark

    // MARK: - Focus Mode

    @AppStorage("enableFocusMode") var enableFocusMode: Bool = false

    // MARK: - AI Scheduling

    @AppStorage("claudeAPIKey") var claudeAPIKey: String = ""
    @AppStorage("claudeModel") var claudeModel: String = "claude-sonnet-4-20250514"
    @AppStorage("aiLookAheadDays") var aiLookAheadDays: Int = 5
    @AppStorage("aiEnabled") var aiEnabled: Bool = true

    // MARK: - Outlook Integration

    @AppStorage("outlookClientID") var outlookClientID: String = ""
    @AppStorage("outlookSyncEnabled") var outlookSyncEnabled: Bool = false
    @AppStorage("outlookSyncInterval") var outlookSyncInterval: Int = 15          // minutes
    @AppStorage("outlookReminderListID") var outlookReminderListID: String = ""

    // MARK: - Quick Chat

    @AppStorage("quickChatKeyCode") var quickChatKeyCode: Int = 45        // 'N' key
    @AppStorage("quickChatModifiers") var quickChatModifiers: Int = 0x0108 // cmdKey | shiftKey
    @AppStorage("quickChatDefaultAIMode") var quickChatDefaultAIMode: Bool = false

    // MARK: - System

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    // MARK: - JSON-encoded Data

    @AppStorage("monitoredCalendarIDs") var monitoredCalendarIDsData: Data = Data()
    @AppStorage("viewableCalendarIDs") var viewableCalendarIDsData: Data = Data()
    @AppStorage("hasRunViewableMigration") var hasRunViewableMigration: Bool = false
    @AppStorage("monitoredReminderListIDs") var monitoredReminderListIDsData: Data = Data()
    @AppStorage("defaultReminderListID") var defaultReminderListID: String = ""
    @AppStorage("blockingCalendarID") var blockingCalendarID: String = ""
    @AppStorage("workingDaysData") var workingDaysData: Data = {
        // Default: Mon-Fri (2-6 in Calendar weekday, but we use 0=Sun..6=Sat)
        let defaultDays: Set<Int> = [1, 2, 3, 4, 5]  // Mon-Fri
        return (try? JSONEncoder().encode(defaultDays)) ?? Data()
    }()
    @AppStorage("energyBlocksData") var energyBlocksData: Data = {
        (try? JSONEncoder().encode(EnergyBlock.defaults)) ?? Data()
    }()
    @AppStorage("focusTimeBlocksData") var focusTimeBlocksData: Data = Data()
    @AppStorage("listEnergyDefaultsData") var listEnergyDefaultsData: Data = Data()
    @AppStorage("eventTemplatesData") var eventTemplatesData: Data = {
        (try? JSONEncoder().encode(EventTemplate.defaults)) ?? Data()
    }()

    // MARK: - Decoded Accessors

    var monitoredCalendarIDs: [String] {
        get { (try? JSONDecoder().decode([String].self, from: monitoredCalendarIDsData)) ?? [] }
        set { monitoredCalendarIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var viewableCalendarIDs: [String] {
        get { (try? JSONDecoder().decode([String].self, from: viewableCalendarIDsData)) ?? [] }
        set { viewableCalendarIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// One-time migration: copy monitoredCalendarIDs → viewableCalendarIDs so existing users
    /// don't lose their visible calendars when upgrading.
    func migrateViewableCalendarsIfNeeded() {
        guard !hasRunViewableMigration else { return }
        hasRunViewableMigration = true
        let existing = monitoredCalendarIDs
        if !existing.isEmpty && viewableCalendarIDs.isEmpty {
            viewableCalendarIDs = existing
        }
    }

    var monitoredReminderListIDs: [String] {
        get { (try? JSONDecoder().decode([String].self, from: monitoredReminderListIDsData)) ?? [] }
        set { monitoredReminderListIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var workingDays: Set<Int> {
        get { (try? JSONDecoder().decode(Set<Int>.self, from: workingDaysData)) ?? [1, 2, 3, 4, 5] }
        set { workingDaysData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var energyBlocks: [EnergyBlock] {
        get { (try? JSONDecoder().decode([EnergyBlock].self, from: energyBlocksData)) ?? EnergyBlock.defaults }
        set { energyBlocksData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var listEnergyDefaults: [String: EnergyLevel] {
        get { (try? JSONDecoder().decode([String: EnergyLevel].self, from: listEnergyDefaultsData)) ?? [:] }
        set { listEnergyDefaultsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var eventTemplates: [EventTemplate] {
        get { (try? JSONDecoder().decode([EventTemplate].self, from: eventTemplatesData)) ?? EventTemplate.defaults }
        set { eventTemplatesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // MARK: - Slot Preference

    enum SlotPreference: String, CaseIterable, Sendable {
        case morningFirst = "morning_first"
        case afternoonFirst = "afternoon_first"
        case spreadEvenly = "spread_evenly"

        var displayName: String {
            switch self {
            case .morningFirst: "Morning first"
            case .afternoonFirst: "Afternoon first"
            case .spreadEvenly: "Spread evenly"
            }
        }
    }

    var slotPreference: SlotPreference {
        get { SlotPreference(rawValue: preferredSlotTimes) ?? .morningFirst }
        set { preferredSlotTimes = newValue.rawValue }
    }
}
