# ProcrastiNaut — Technical Specification

## App Overview

**ProcrastiNaut** is a macOS menu bar application that intelligently bridges Apple Reminders and Apple Calendar. Each morning (or upon wake from sleep), it scans selected reminder lists for open tasks, analyzes free time across selected calendars, and suggests time blocks for completing those tasks — factoring in user energy levels, task priority, and learned duration patterns. Upon approval, it creates calendar events. It proactively detects conflicts when new meetings appear and offers to reschedule. After each event expires, it follows up via a custom in-app notification to confirm completion, track partial progress, or reschedule.

**Platform:** macOS (menu bar app)
**Framework:** SwiftUI + AppKit (for menu bar integration)
**Minimum OS:** macOS 14.0 (Sonoma)
**Data Access:** EventKit (Reminders + Calendar)

---

## Core Workflow

```
┌─────────────────────────────────────────────────────────┐
│            MORNING SCAN (Configurable Time)              │
│            + WAKE-FROM-SLEEP FALLBACK                    │
│                                                          │
│  1. Check if scan already ran today                      │
│  2. Fetch incomplete reminders from selected lists       │
│  3. Fetch calendar events from selected calendars        │
│  4. Identify free time slots                             │
│  5. Match reminders → available slots                    │
│     (priority-aware, energy-aware, duration-learned)     │
│  6. Split long tasks across multiple blocks if needed    │
│  7. Present suggestions to user                          │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   USER REVIEW & APPROVE                  │
│                                                          │
│  • View suggested time blocks per reminder               │
│  • Drag-and-drop to reorder / swap time slots            │
│  • Adjust duration, time, or skip                        │
│  • Approve individually or batch-approve                 │
│  • Quick-add new tasks inline                            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              CONFLICT-FREE CALENDAR BLOCKING             │
│                                                          │
│  • Re-verify availability before creating events         │
│  • Warn if a conflict appeared since scan                │
│  • Create calendar events for approved items             │
│  • Events tagged with reminder metadata + notes/URLs     │
│  • Events color-coded by priority or source list         │
│  • Events created on designated calendar                 │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              ACTIVE MONITORING & OVERRUN DETECTION        │
│                                                          │
│  During active task blocks:                              │
│  • Track calendar for new conflicts → offer reschedule   │
│  • "5 min left" warning if next event is approaching     │
│  • "Start Now" available for any upcoming task           │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│           POST-EVENT FOLLOW-UP (Custom In-App)           │
│                                                          │
│  After event end time (queued, rate-limited):            │
│  • Custom popover notification:                          │
│    "Did you complete [Task]?"                            │
│     ✅ Done → Mark reminder as complete                  │
│     🔶 Partially → Enter remaining time, reschedule rest │
│     🔄 Reschedule → Show reschedule options              │
│     ⏭ Skip → Leave reminder open, remove event          │
│     ↩️ Undo (30s window after Done/Skip)                 │
│  • Missed follow-ups queue and appear when app           │
│    comes to foreground                                   │
└─────────────────────────────────────────────────────────┘
```

---

### Wake-from-Sleep Behavior

If the Mac is asleep during the configured scan time:
1. Register for `NSWorkspace.didWakeNotification`
2. On wake, check if today's scan has already run (`DailyPlan.scanCompletedAt`)
3. If not, immediately trigger the scan for remaining available time today
4. Adjust suggestions to only use time slots from now onward

### Late-Day Scan

If the user opens the app for the first time at e.g. 2 PM without having scanned:
1. Auto-trigger a scan scoped to remaining hours
2. Notify: "Better late than never — here are your afternoon suggestions"

### Multi-Block Task Splitting

When a task requires more time than any single available slot:
1. Split the task into multiple blocks across the day (or across days)
2. Label blocks as "Task Name (1/3)", "Task Name (2/3)", etc.
3. After each partial block, follow up: "How much progress did you make?"
4. Adjust remaining blocks based on user feedback

### Conflict Detection

Monitor `EKEventStoreChangedNotification` continuously:
1. When a new/changed event overlaps an approved ProcrastiNaut block:
   - Notification: "Your block for [Task] conflicts with [New Meeting]"
   - Options: Reschedule task, keep both, cancel task block
2. When a ProcrastiNaut event is moved externally (in Calendar.app):
   - Update the `ProcrastiNautTask` to reflect the new time
3. When a ProcrastiNaut event is deleted externally:
   - Mark the task as `cancelled` and notify the user

---

## Architecture

### High-Level Components

```
┌──────────────────────────────────────────────────────────┐
│                      ProcrastiNaut                        │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  Menu Bar    │  │  Suggestion  │  │  Settings       │  │
│  │  Controller  │  │  Engine      │  │  Manager        │  │
│  └──────┬──────┘  └──────┬───────┘  └──────┬─────────┘  │
│         │                │                  │             │
│  ┌──────┴────────────────┴──────────────────┴──────────┐ │
│  │                Core Services Layer                   │ │
│  │                                                      │ │
│  │  ┌──────────────┐  ┌────────────────────────┐       │ │
│  │  │ EventKit     │  │ Custom Notification    │       │ │
│  │  │ Manager      │  │ Manager               │       │ │
│  │  └──────────────┘  └────────────────────────┘       │ │
│  │  ┌──────────────┐  ┌────────────────────────┐       │ │
│  │  │ Scheduler    │  │ Persistence            │       │ │
│  │  │ Service      │  │ (SwiftData)            │       │ │
│  │  └──────────────┘  └────────────────────────┘       │ │
│  │  ┌──────────────┐  ┌────────────────────────┐       │ │
│  │  │ Conflict     │  │ Duration Learning      │       │ │
│  │  │ Monitor      │  │ Service                │       │ │
│  │  └──────────────┘  └────────────────────────┘       │ │
│  │  ┌──────────────┐  ┌────────────────────────┐       │ │
│  │  │ Energy       │  │ Gamification           │       │ │
│  │  │ Manager      │  │ Engine                 │       │ │
│  │  └──────────────┘  └────────────────────────┘       │ │
│  └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### Key Classes / Modules

| Module | Responsibility |
|---|---|
| `MenuBarController` | NSStatusItem management, persistent popover UI, quick actions, keyboard shortcuts |
| `SuggestionEngine` | Analyzes reminders + calendar availability + energy levels, generates time block proposals, splits long tasks |
| `EventKitManager` | Unified interface for reading/writing Reminders and Calendar events, tracks ProcrastiNaut-created events |
| `SchedulerService` | Manages daily scan timing, wake-from-sleep fallback, post-event follow-up triggers |
| `ConflictMonitor` | Watches for calendar changes that conflict with approved task blocks |
| `CustomNotificationManager` | In-app notification popover for follow-ups with full interactive controls |
| `DurationLearningService` | Tracks actual vs estimated durations per list/tag, adjusts future estimates |
| `EnergyManager` | Manages user-defined energy-level time ranges, matches tasks to energy slots |
| `GamificationEngine` | Tracks streaks, completion scores, badges, space-themed progression |
| `SettingsManager` | Persists user preferences (selected calendars, reminder lists, etc.) |
| `ProcrastiNautEvent` | Data model linking a calendar event to its source reminder |
| `ArchiveManager` | Handles auto-archiving of old task records and daily stats |

---

## Configuration & Settings

### Calendar Settings

| Setting | Type | Default | Description |
|---|---|---|---|
| `monitoredCalendars` | `[EKCalendar]` | All calendars | Which calendars to check for existing events (busy time) |
| `blockingCalendar` | `EKCalendar` | Auto-created "ProcrastiNaut" | Calendar where time-block events are created |
| `workingHoursStart` | `TimeInterval` | 8:00 AM | Earliest time to suggest blocks (stored as seconds from midnight) |
| `workingHoursEnd` | `TimeInterval` | 6:00 PM | Latest time to suggest blocks (stored as seconds from midnight) |
| `workingDays` | `Set<Weekday>` | Mon–Fri | Days to suggest time blocks |
| `eventColorByPriority` | `Bool` | `true` | Color-code calendar events by priority |
| `eventColorByList` | `Bool` | `false` | Color-code calendar events by source reminder list |

### Reminder Settings

| Setting | Type | Default | Description |
|---|---|---|---|
| `monitoredReminderLists` | `[EKCalendar]` | All lists | Which reminder lists to scan for open tasks |
| `ignorePastDueOnly` | `Bool` | `false` | If true, only suggest blocks for reminders that are past due |
| `includeUndated` | `Bool` | `true` | Include reminders with no due date |

### Scheduling Preferences

| Setting | Type | Default | Description |
|---|---|---|---|
| `morningScanTime` | `TimeInterval` | 7:30 AM | When to trigger the daily scan (seconds from midnight) |
| `defaultTaskDuration` | `Int` (minutes) | 30 | Default time block length |
| `minimumSlotSize` | `Int` (minutes) | 15 | Smallest free slot to consider |
| `bufferBetweenBlocks` | `Int` (minutes) | 10 | Padding between any event and a task block |
| `followUpDelay` | `Int` (minutes) | 5 | Minutes after event ends to send follow-up |
| `maxSuggestionsPerDay` | `Int` | 10 | Cap on daily suggestions to avoid overwhelm |
| `prioritySorting` | `Bool` | `true` | High-priority reminders get earlier/better slots |
| `undoWindowDuration` | `Int` (seconds) | 30 | Time window to undo accidental follow-up actions |

### Energy & Focus Settings

| Setting | Type | Default | Description |
|---|---|---|---|
| `energyLevels` | `[EnergyBlock]` | See defaults | User-defined time ranges with energy levels |
| `focusTimeBlocks` | `[TimeRange]` | Empty | Protected time ranges (e.g., "deep work 9–11 AM") |
| `preferredSlotTimes` | `Enum` | `.morning_first` | Preference: morning first, afternoon first, spread evenly |
| `matchEnergyToTasks` | `Bool` | `true` | Match demanding tasks to high-energy slots |

Default energy levels:
```
9:00 AM – 11:00 AM  → High Focus
11:00 AM – 12:00 PM → Medium
1:00 PM – 2:00 PM   → Low (post-lunch)
2:00 PM – 4:00 PM   → Medium
4:00 PM – 6:00 PM   → Low (wind-down)
```

### Gamification Settings

| Setting | Type | Default | Description |
|---|---|---|---|
| `showCompletionStats` | `Bool` | `true` | Track and display completion rate in menu bar |
| `enableStreaks` | `Bool` | `true` | Track daily completion streaks |
| `streakThreshold` | `Double` | `0.8` | Minimum completion rate to maintain a streak (80%) |
| `enableBadges` | `Bool` | `true` | Award badges for milestones |

### Advanced Options

| Setting | Type | Default | Description |
|---|---|---|---|
| `autoApproveRecurring` | `Bool` | `false` | Auto-approve suggestions for recurring reminders |
| `snoozeOptions` | `[Int]` (minutes) | [15, 30, 60, 1440] | Reschedule delay options (15m, 30m, 1h, tomorrow) |
| `scanSnoozeOptions` | `[Int]` (minutes) | [30, 60] | Options to snooze the morning scan notification |
| `archiveAfterDays` | `Int` | 90 | Auto-archive task records older than this many days |
| `deleteArchivedAfterDays` | `Int` | 365 | Delete archived records after this many days |
| `followUpRateLimit` | `Int` (seconds) | 120 | Minimum seconds between consecutive follow-up notifications |
| `launchAtLogin` | `Bool` | `false` | Launch at login via SMAppService |
| `enableDurationLearning` | `Bool` | `true` | Learn task durations from completion history |
| `weeklyPlanningEnabled` | `Bool` | `false` | Enable weekly planning mode |
| `weeklyPlanningDay` | `Weekday` | `.sunday` | Day for weekly planning session |
| `weeklyPlanningTime` | `TimeInterval` | 6:00 PM | Time for weekly planning prompt |

---

## UI Design

### Menu Bar Icon & States

```
Normal:        🚀  (or custom SF Symbol: "checkmark.circle")
Pending:       🚀● (badge dot — suggestions waiting for review)
Active Block:  🚀▶ (currently in a scheduled task block)
All Complete:  🚀✓ (all tasks for today completed)
Streak:        🚀🔥 (active streak indicator)
```

### Menu Bar Popover (Main View)

The popover stays open until explicitly dismissed by the user (clicking a close button or pressing Escape). It does NOT auto-dismiss on click-outside.

```
┌─────────────────────────────────────────┐
│  ProcrastiNaut        🔥7 days  ⚙️     │
├─────────────────────────────────────────┤
│                                          │
│  ┌─ Quick Add ──────────────────────┐   │
│  │ 30m: Write blog post...     [+]  │   │
│  └──────────────────────────────────┘   │
│                                          │
│  📋 Today's Plan                         │
│  ─────────────────────────────           │
│                                          │
│  ✅ 9:00–9:30   Review Q1 budget         │
│  ⏳ 10:00–10:30 Update security policy   │
│     [▶ Start Now]                        │
│  📌 11:00–11:45 Prepare proposal (1/2)   │
│  📌 2:00–2:30   Prepare proposal (2/2)   │
│  ○  3:00–3:30   Order new equipment      │
│                                          │
│  ─────────────────────────────           │
│  🔔 3 pending suggestions                │
│     [Review Suggestions]                 │
│                                          │
│  ─────────────────────────────           │
│  📊 Today: 1/5 complete (20%)            │
│  🚀 Rank: Orbital Cadet                  │
│                                          │
├─────────────────────────────────────────┤
│  [Scan Now]   [Plan Week]   [Dismiss]   │
└─────────────────────────────────────────┘
```

**Keyboard Shortcuts (in popover):**
| Shortcut | Action |
|---|---|
| `A` | Approve all pending suggestions |
| `↑` / `↓` | Navigate between tasks |
| `Enter` | Approve selected suggestion |
| `S` | Skip selected suggestion |
| `N` | Start now on selected task |
| `Q` | Focus quick-add field |
| `Esc` | Dismiss popover |

### Quick-Add Input

The quick-add field at the top of the popover allows inline task creation:

```
Format: "[duration]: [task name]"
Examples:
  "30m: Write blog post"
  "1h: Security audit"
  "15m: Reply to emails"

Behavior:
  1. Creates a new reminder in the default monitored list
  2. Immediately finds the next available slot
  3. Creates the calendar block
  4. Adds to today's plan
```

### Suggestion Review Sheet

```
┌─────────────────────────────────────────┐
│  📋 Suggested Time Blocks                │
│  (drag to reorder)                       │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ ≡ 🔴 Review Q1 budget             │  │
│  │    Due: Today                      │  │
│  │    Suggested: 9:00 – 9:30 AM      │  │
│  │    Energy: ⚡ High Focus slot      │  │
│  │    Duration: [30 min ▾]            │  │
│  │                                    │  │
│  │    [✓ Approve] [✎ Change] [✗ Skip]│  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ ≡ 🟡 Update security policy       │  │
│  │    Due: Feb 22                     │  │
│  │    Suggested: 2:00 – 2:30 PM      │  │
│  │    Energy: 😌 Low Energy slot      │  │
│  │    Duration: [30 min ▾]            │  │
│  │    📎 Est. based on past: ~25 min  │  │
│  │                                    │  │
│  │    [✓ Approve] [✎ Change] [✗ Skip]│  │
│  └────────────────────────────────────┘  │
│                                          │
│  ────────────────────────────────────    │
│  [Approve All]              [Dismiss]    │
└─────────────────────────────────────────┘
```

### Custom In-App Follow-Up Notification

Instead of relying on macOS system notifications (which have limited actions), ProcrastiNaut uses its own custom popover notification anchored to the menu bar icon. This allows full interactive controls.

```
┌─────────────────────────────────────────┐
│  ProcrastiNaut                    ✕     │
│                                          │
│  Did you complete:                       │
│  "Review Q1 budget"?                     │
│                                          │
│  [✅ Done]  [🔶 Partial]  [🔄 Reschedule]  [⏭ Skip]  │
│                                          │
│  ↩️ Undo available for 30 seconds        │
└─────────────────────────────────────────┘
```

### Partial Completion Sheet

```
┌─────────────────────────────────────────┐
│  Partial Progress — "Review Q1 budget"   │
│                                          │
│  How much time do you still need?        │
│                                          │
│  ○ 15 minutes                            │
│  ○ 30 minutes                            │
│  ○ 45 minutes                            │
│  ○ Custom: [___] minutes                 │
│                                          │
│  Schedule the rest:                      │
│  ○ Next available slot today             │
│  ○ Tomorrow                              │
│  ○ Pick a time...                        │
│                                          │
│  [Schedule Remaining]        [Cancel]    │
└─────────────────────────────────────────┘
```

### Reschedule Options

```
┌─────────────────────────────────────────┐
│  Reschedule "Review Q1 budget"           │
│                                          │
│  ○ In 15 minutes                         │
│  ○ In 30 minutes                         │
│  ○ In 1 hour                             │
│  ○ Tomorrow (next available slot)        │
│  ○ Pick a time...                        │
│                                          │
│  [Reschedule]              [Cancel]      │
└─────────────────────────────────────────┘
```

### Conflict Alert

```
┌─────────────────────────────────────────┐
│  ⚠️ Schedule Conflict Detected           │
│                                          │
│  Your block for:                         │
│  "Update security policy" (10:00–10:30)  │
│                                          │
│  Conflicts with new event:               │
│  "Team Standup" (10:00–10:15)            │
│                                          │
│  [🔄 Reschedule Task]                    │
│  [📌 Keep Both]                          │
│  [✗ Cancel Task Block]                   │
└─────────────────────────────────────────┘
```

### Overrun Warning

```
┌─────────────────────────────────────────┐
│  ⏰ 5 minutes left                       │
│                                          │
│  "Review Q1 budget" ends at 9:30 AM     │
│  Your next event: "Team Standup" at 9:30 │
│                                          │
│  [✅ Mark Done]     [🔶 Continue Later]  │
└─────────────────────────────────────────┘
```

### No Availability View

```
┌─────────────────────────────────────────┐
│  😅 No available time slots today        │
│                                          │
│  You have 4 tasks but your calendar is   │
│  fully booked during working hours.      │
│                                          │
│  [📐 Extend Working Hours]               │
│  [📆 Schedule for Tomorrow]              │
│  [💤 Snooze until tomorrow's scan]       │
└─────────────────────────────────────────┘
```

### Morning Scan Notification (System Notification)

```
Title: "ProcrastiNaut — Daily Plan Ready"
Body:  "You have 5 tasks that could be scheduled today. Tap to review."
Actions:
  - "Review Now" → Opens popover
  - "Snooze 30m" → Reschedule notification
  - "Snooze 1h" → Reschedule notification
Trigger: Configurable time OR wake-from-sleep fallback
```

### Weekly Planning View

```
┌──────────────────────────────────────────────────────┐
│  📅 Plan Your Week                         [✕ Close] │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Unscheduled Tasks (12):                             │
│  ─────────────────────                               │
│  🔴 Security audit (est. 2h)                         │
│  🔴 Q1 budget review (est. 45m)                      │
│  🟡 Client proposal (est. 1h30m)                     │
│  🟡 Update docs (est. 30m)                           │
│  ...                                                  │
│                                                       │
│  ┌──────┬──────┬──────┬──────┬──────┐               │
│  │ Mon  │ Tue  │ Wed  │ Thu  │ Fri  │               │
│  ├──────┼──────┼──────┼──────┼──────┤               │
│  │2h    │3h    │1.5h  │2.5h  │4h    │ ← Free time  │
│  │free  │free  │free  │free  │free  │               │
│  ├──────┼──────┼──────┼──────┼──────┤               │
│  │      │      │      │      │      │ ← Assigned    │
│  └──────┴──────┴──────┴──────┴──────┘               │
│                                                       │
│  [Auto-Distribute]  [Clear]  [Apply Plan]            │
└──────────────────────────────────────────────────────┘
```

### Gamification & Streaks

Space-themed progression system:

| Level | Title | Requirement |
|---|---|---|
| 1 | Ground Control | First task completed |
| 2 | Launchpad Cadet | 5 tasks completed |
| 3 | Orbital Cadet | 3-day streak |
| 4 | Space Explorer | 7-day streak |
| 5 | Lunar Navigator | 25 tasks completed |
| 6 | Mars Voyager | 14-day streak |
| 7 | Asteroid Miner | 100 tasks completed |
| 8 | Galaxy Commander | 30-day streak |
| 9 | Nebula Architect | 500 tasks completed |
| 10 | ProcrastiNaut Legend | 100-day streak |

Badges:
- **First Launch** — Complete your first task
- **Early Bird** — Complete a task before 9 AM
- **Night Owl** — Complete a task after 5 PM
- **Perfect Day** — 100% completion rate in a day
- **Perfect Week** — 80%+ every day for a week
- **Estimator** — 10 tasks completed within 5 min of estimated duration
- **Streak Saver** — Maintain a 30+ day streak
- **Splitter** — Complete a multi-block task

### Settings Window

```
┌──────────────────────────────────────────────────────┐
│  ProcrastiNaut Settings                    [✕ Close] │
├──────────┬───────────────────────────────────────────┤
│          │                                            │
│ General  │  Morning Scan Time: [7:30 AM ▾]           │
│          │  Default Task Duration: [30 min ▾]        │
│ Calendars│  Buffer Between Events: [10 min ▾]        │
│          │  Follow-up Delay: [5 min ▾]               │
│ Reminders│  Max Suggestions/Day: [10 ▾]              │
│          │                                            │
│ Schedule │  ☐ Launch at Login                         │
│          │  ☑ Show completion stats in menu bar       │
│ Energy   │  ☐ Auto-approve recurring tasks            │
│          │  ☑ Learn task durations from history       │
│ Gamific. │                                            │
│          │  Scheduling Preference:                    │
│ Data     │  ○ Morning first                           │
│          │  ○ Afternoon first                         │
│ Advanced │  ○ Spread evenly                           │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  ⚡ Energy Levels                          │
│          │  ─────────────────                         │
│ Calendars│  9:00–11:00 AM   [High Focus ▾]           │
│          │  11:00 AM–12:00  [Medium ▾]               │
│ Reminders│  1:00–2:00 PM    [Low ▾]                  │
│          │  2:00–4:00 PM    [Medium ▾]               │
│ Schedule │  4:00–6:00 PM    [Low ▾]                  │
│          │                                            │
│ Energy   │  [+ Add Energy Block]                      │
│          │                                            │
│ Gamific. │  ☑ Match task difficulty to energy level   │
│          │                                            │
│ Data     │  Task Energy Requirements:                 │
│          │  Reminders list → default difficulty:       │
│ Advanced │  Work Tasks  [High ▾]                      │
│          │  Projects    [High ▾]                      │
│          │  Reminders   [Medium ▾]                    │
│          │  Shopping    [Low ▾]                       │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  🏆 Gamification                           │
│          │  ─────────────────                         │
│ Calendars│  ☑ Enable streaks                          │
│          │  Streak threshold: [80% ▾]                │
│ Reminders│  ☑ Enable badges                           │
│          │  ☑ Show rank in menu bar                   │
│ Schedule │                                            │
│          │  Current Rank: 🚀 Orbital Cadet            │
│ Energy   │  Current Streak: 7 days 🔥                 │
│          │  Badges Earned: 4/8                        │
│ Gamific. │                                            │
│          │                                            │
│ Data     │                                            │
│          │                                            │
│ Advanced │                                            │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  🗄️ Data Management                        │
│          │  ─────────────────                         │
│ Calendars│  Auto-archive after: [90 days ▾]           │
│          │  Delete archived after: [1 year ▾]        │
│ Reminders│                                            │
│          │  Task Records: 234 active, 89 archived    │
│ Schedule │  Daily Stats: 67 entries                   │
│          │                                            │
│ Energy   │  [Archive Now]  [Export Data]              │
│          │                                            │
│ Gamific. │                                            │
│          │                                            │
│ Data     │                                            │
│          │                                            │
│ Advanced │                                            │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  📅 Calendars to Monitor (busy time):     │
│          │  ☑ Work                                    │
│ Calendars│  ☑ Personal                                │
│          │  ☐ Birthdays                               │
│ Reminders│  ☐ Holidays                                │
│          │                                            │
│ Schedule │  📝 Create Events On:                      │
│          │  ○ ProcrastiNaut (auto-created)            │
│ Energy   │  ○ Work                                    │
│          │  ○ Personal                                │
│ Gamific. │                                            │
│          │  Event Color Coding:                        │
│ Data     │  ○ By priority (🔴🟡🔵⚪)                  │
│          │  ○ By source list                          │
│ Advanced │  ○ Single color                            │
│          │                                            │
│          │  ⏰ Working Hours:                          │
│          │  Start: [8:00 AM ▾]  End: [6:00 PM ▾]    │
│          │                                            │
│          │  Working Days:                              │
│          │  ☑ Mon ☑ Tue ☑ Wed ☑ Thu ☑ Fri            │
│          │  ☐ Sat ☐ Sun                               │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  📋 Reminder Lists to Monitor:             │
│          │  ☑ Reminders                               │
│ Calendars│  ☑ Work Tasks                              │
│          │  ☐ Shopping                                 │
│ Reminders│  ☑ Projects                                │
│          │                                            │
│ Schedule │  Include Options:                           │
│          │  ☑ Include reminders with no due date      │
│ Energy   │  ☐ Only show past-due reminders            │
│          │  ☑ Sort by priority                        │
│ Gamific. │                                            │
│          │                                            │
│ Data     │                                            │
│          │                                            │
│ Advanced │                                            │
│          │                                            │
└──────────┴───────────────────────────────────────────┘

┌──────────┬───────────────────────────────────────────┐
│          │                                            │
│ General  │  🔧 Advanced                               │
│          │  ─────────────────                         │
│ Calendars│  Weekly Planning:                          │
│          │  ☐ Enable weekly planning mode             │
│ Reminders│  Planning day: [Sunday ▾]                  │
│          │  Planning time: [6:00 PM ▾]               │
│ Schedule │                                            │
│          │  Notifications:                             │
│ Energy   │  Follow-up rate limit: [2 min ▾]           │
│          │  Undo window: [30 sec ▾]                   │
│ Gamific. │  Morning scan snooze: [30m, 1h]            │
│          │                                            │
│ Data     │  Focus Time Blocks:                         │
│          │  9:00–11:00 AM  "Deep Work" [✕]           │
│ Advanced │  [+ Add Focus Block]                       │
│          │                                            │
│          │  Permissions:                               │
│          │  Calendar: ✅ Granted  [Re-request]        │
│          │  Reminders: ✅ Granted  [Re-request]       │
│          │  Notifications: ✅ Granted  [Re-request]   │
│          │                                            │
└──────────┴───────────────────────────────────────────┘
```

---

## Data Models

### ProcrastiNautTask

```swift
struct ProcrastiNautTask: Identifiable, Codable {
    let id: UUID
    let reminderIdentifier: String      // EKReminder calendarItemIdentifier
    let reminderTitle: String
    let reminderListName: String
    let priority: TaskPriority           // high, medium, low, none
    let dueDate: Date?
    let reminderNotes: String?           // Carried into calendar event
    let reminderURL: URL?               // Carried into calendar event
    let energyRequirement: EnergyLevel   // Derived from list or explicit

    var suggestedStartTime: Date?
    var suggestedEndTime: Date?
    var suggestedDuration: TimeInterval  // seconds
    var blockIndex: Int?                 // For split tasks: 1, 2, 3...
    var totalBlocks: Int?               // For split tasks: total count

    var status: TaskStatus
    var calendarEventIdentifier: String? // EKEvent calendarItemIdentifier

    var rescheduleCount: Int = 0
    var remainingDuration: TimeInterval? // For partial completions
    var createdAt: Date
    var completedAt: Date?
    var actualDuration: TimeInterval?    // Tracked for duration learning
}

enum TaskStatus: String, Codable {
    case pending        // Suggested but not yet approved
    case approved       // Approved, calendar event created
    case inProgress     // Currently within the time block
    case awaitingReview // Time block ended, waiting for user response
    case completed      // User confirmed completion
    case partiallyDone  // User indicated partial progress
    case rescheduled    // User chose to reschedule
    case skipped        // User skipped the follow-up
    case cancelled      // User declined the suggestion
    case conflicted     // A new event conflicts with this block
}

enum TaskPriority: Int, Codable, Comparable {
    case high = 1
    case medium = 5
    case low = 9
    case none = 99

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum EnergyLevel: String, Codable, CaseIterable {
    case highFocus = "high_focus"
    case medium = "medium"
    case low = "low"
}
```

### DailyPlan

```swift
struct DailyPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    var tasks: [ProcrastiNautTask]
    var scanCompletedAt: Date?
    var scanType: ScanType               // .scheduled, .wakeFromSleep, .manual, .lateDay
    var completionRate: Double {
        let completed = tasks.filter { $0.status == .completed }.count
        return tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count)
    }
    var streakEligible: Bool {
        completionRate >= UserSettings.shared.streakThreshold
    }
}

enum ScanType: String, Codable {
    case scheduled      // Ran at configured time
    case wakeFromSleep  // Ran after Mac woke up
    case manual         // User tapped "Scan Now"
    case lateDay        // Auto-triggered on first open after scan window
}
```

### EnergyBlock

```swift
struct EnergyBlock: Identifiable, Codable {
    let id: UUID
    var startTime: TimeInterval    // Seconds from midnight
    var endTime: TimeInterval      // Seconds from midnight
    var level: EnergyLevel
}
```

### WeeklyPlan

```swift
struct WeeklyPlan: Identifiable, Codable {
    let id: UUID
    let weekStartDate: Date        // Monday of the week
    var dayPlans: [DailyPlan]
    var unassignedTasks: [ProcrastiNautTask]
    var createdAt: Date
}
```

### GamificationState

```swift
struct GamificationState: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var totalTasksCompleted: Int
    var currentLevel: Int
    var currentTitle: String
    var earnedBadges: [Badge]
    var lastStreakDate: Date?

    mutating func recordCompletion(dailyRate: Double, threshold: Double) {
        totalTasksCompleted += 1
        if dailyRate >= threshold {
            if let lastDate = lastStreakDate,
               Calendar.current.isDateInYesterday(lastDate) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            lastStreakDate = Date()
            longestStreak = max(longestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
        updateLevel()
    }
}

struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconName: String       // SF Symbol name
    var earnedAt: Date?
}
```

### UserSettings

```swift
class UserSettings: ObservableObject {
    static let shared = UserSettings()

    // Time values stored as TimeInterval (seconds from midnight)
    // This avoids @AppStorage incompatibility with Date
    @AppStorage("morningScanTime") var morningScanTime: Double = 27000        // 7:30 AM
    @AppStorage("defaultTaskDuration") var defaultTaskDuration: Int = 30       // minutes
    @AppStorage("bufferBetweenBlocks") var bufferBetweenBlocks: Int = 10       // minutes
    @AppStorage("followUpDelay") var followUpDelay: Int = 5                    // minutes
    @AppStorage("maxSuggestionsPerDay") var maxSuggestionsPerDay: Int = 10
    @AppStorage("workingHoursStart") var workingHoursStart: Double = 28800     // 8:00 AM
    @AppStorage("workingHoursEnd") var workingHoursEnd: Double = 64800         // 6:00 PM
    @AppStorage("prioritySorting") var prioritySorting: Bool = true
    @AppStorage("preferredSlotTimes") var preferredSlotTimes: String = "morning_first"
    @AppStorage("autoApproveRecurring") var autoApproveRecurring: Bool = false
    @AppStorage("showCompletionStats") var showCompletionStats: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("matchEnergyToTasks") var matchEnergyToTasks: Bool = true
    @AppStorage("enableStreaks") var enableStreaks: Bool = true
    @AppStorage("streakThreshold") var streakThreshold: Double = 0.8
    @AppStorage("enableBadges") var enableBadges: Bool = true
    @AppStorage("enableDurationLearning") var enableDurationLearning: Bool = true
    @AppStorage("archiveAfterDays") var archiveAfterDays: Int = 90
    @AppStorage("deleteArchivedAfterDays") var deleteArchivedAfterDays: Int = 365
    @AppStorage("followUpRateLimit") var followUpRateLimit: Int = 120          // seconds
    @AppStorage("undoWindowDuration") var undoWindowDuration: Int = 30         // seconds
    @AppStorage("weeklyPlanningEnabled") var weeklyPlanningEnabled: Bool = false
    @AppStorage("weeklyPlanningDay") var weeklyPlanningDay: Int = 1            // 1=Sunday
    @AppStorage("weeklyPlanningTime") var weeklyPlanningTime: Double = 64800   // 6:00 PM
    @AppStorage("eventColorMode") var eventColorMode: String = "priority"      // priority, list, single
    @AppStorage("minimumSlotSize") var minimumSlotSize: Int = 15               // minutes

    // Stored as JSON-encoded data
    @AppStorage("monitoredCalendarIDs") var monitoredCalendarIDs: Data = Data()
    @AppStorage("monitoredReminderListIDs") var monitoredReminderListIDs: Data = Data()
    @AppStorage("blockingCalendarID") var blockingCalendarID: String = ""
    @AppStorage("workingDays") var workingDays: Data = Data()                  // Set<Int> encoded
    @AppStorage("energyBlocks") var energyBlocks: Data = Data()                // [EnergyBlock] encoded
    @AppStorage("focusTimeBlocks") var focusTimeBlocks: Data = Data()          // [TimeRange] encoded
    @AppStorage("snoozeOptions") var snoozeOptions: Data = Data()              // [Int] encoded
    @AppStorage("listEnergyDefaults") var listEnergyDefaults: Data = Data()    // [String: EnergyLevel] encoded
}
```

---

## Suggestion Engine Algorithm

### Slot Finding

```
FUNCTION findAvailableSlots(date, settings):
    1. Get all events from monitored calendars for `date`
    2. Merge overlapping events into busy blocks
    3. Define available window: workingHoursStart → workingHoursEnd
       (If late-day scan: now → workingHoursEnd)
    4. Subtract busy blocks from available window
    5. Subtract focus time blocks (if configured)
    6. Apply buffer: shrink each slot by bufferBetweenBlocks on both ends
       adjacent to existing events
    7. Filter out slots smaller than minimumSlotSize
    8. Annotate each slot with its energy level from EnergyManager
    9. Return sorted list of free slots with energy metadata
```

### Task Matching (Energy-Aware)

```
FUNCTION generateSuggestions(reminders, freeSlots, settings):
    1. Sort reminders by priority:
       a. Overdue tasks (by how overdue)
       b. Due today
       c. Due this week
       d. High priority (no date)
       e. Medium priority
       f. Low / no priority (none = last)

    2. For each reminder (up to maxSuggestionsPerDay):
       a. Determine duration:
          i.   Check reminder notes for [duration:XXm] hint
          ii.  Check DurationLearningService for learned estimate
          iii. Fall back to defaultTaskDuration
       b. Determine energy requirement (from list defaults or reminder tag)
       c. If duration > any single free slot:
          → Split into multiple blocks (see Multi-Block Splitting)
       d. Find best matching slot:
          - If matchEnergyToTasks: prefer slots matching energy level
          - Based on preferredSlotTimes:
            morning_first: scan slots earliest → latest
            afternoon_first: scan slots latest → earliest
            spread_evenly: distribute across the day
       e. If match found, create ProcrastiNautTask suggestion
       f. Remove used time from available slots

    3. Return list of suggestions
```

### Multi-Block Splitting

```
FUNCTION splitTaskIntoBlocks(reminder, duration, freeSlots):
    1. remainingDuration = duration
    2. blockIndex = 1
    3. blocks = []

    4. While remainingDuration > 0 AND freeSlots not empty:
       a. Find largest available slot (or best energy match)
       b. allocatedTime = min(slot.duration, remainingDuration)
       c. If allocatedTime < minimumSlotSize: skip slot
       d. Create block with blockIndex, allocatedTime
       e. remainingDuration -= allocatedTime
       f. blockIndex += 1
       g. Remove used time from slot

    5. Set totalBlocks on all created blocks
    6. If remainingDuration > 0:
       → Carry over to next day's planning

    7. Return blocks
```

### Duration Learning

```
FUNCTION learnDuration(task, settings):
    IF NOT settings.enableDurationLearning: return

    1. When task is marked complete, calculate:
       actualDuration = completedAt - inProgressStartTime

    2. Store in DurationLearningService keyed by:
       - reminderListName (primary grouping)
       - reminderTitle keywords (secondary, for recurring tasks)

    3. Maintain rolling average of last 20 completions per group

    4. When estimating future tasks:
       a. Check for title-keyword match → use that average
       b. Fall back to list-level average
       c. Fall back to defaultTaskDuration

    5. Show learned estimate in suggestion card:
       "📎 Est. based on past: ~25 min"
```

### Conflict Detection

```
FUNCTION monitorConflicts():
    1. Listen for EKEventStoreChangedNotification
    2. On notification:
       a. Fetch all approved ProcrastiNautTask blocks for today
       b. Fetch current calendar events for today
       c. For each task block:
          - Check if any non-ProcrastiNaut event overlaps
          - Check if the ProcrastiNaut event still exists
          - Check if the ProcrastiNaut event was moved
       d. If overlap detected:
          → Set task status to .conflicted
          → Show ConflictAlert popover
       e. If ProcrastiNaut event moved:
          → Update task.suggestedStartTime/EndTime
       f. If ProcrastiNaut event deleted:
          → Set task status to .cancelled
          → Notify user
```

### Weekly Planning

```
FUNCTION generateWeeklyPlan(startDate, settings):
    1. For each working day in the week:
       a. Fetch calendar events
       b. Calculate available time per day

    2. Fetch all incomplete reminders from monitored lists

    3. Sort tasks by priority + due date

    4. Distribute tasks across days:
       a. Due-date-bound tasks → assigned to their due date (or before)
       b. High priority → assigned to earliest days with capacity
       c. Energy matching: demanding tasks → days with high-energy availability
       d. Respect maxSuggestionsPerDay per day

    5. Present weekly view for user review
    6. On "Apply Plan": create DailyPlan for each day
       (daily plans execute as normal each morning)
```

---

## Duration Hinting

Reminders can include a duration hint in their notes field:

```
Format: [duration:45m] or [duration:1h30m]
Parsed by SuggestionEngine, falls back to learned duration, then defaultTaskDuration
```

---

## EventKit Integration

### Permissions

```swift
let eventStore = EKEventStore()

// Request access on first launch
eventStore.requestFullAccessToReminders { granted, error in ... }
eventStore.requestFullAccessToEvents { granted, error in ... }

// Monitor permission changes
func checkPermissions() -> PermissionState {
    let calStatus = EKEventStore.authorizationStatus(for: .event)
    let remStatus = EKEventStore.authorizationStatus(for: .reminder)
    // Return combined state for UI display
}
```

### Permission Revocation Handling

```swift
// On app foreground, re-check permissions
func handlePermissionState(_ state: PermissionState) {
    switch state {
    case .allGranted:
        // Normal operation
    case .calendarDenied:
        // Show "Calendar access required" in popover
        // Disable calendar-related features
        // Show "Re-request" button → opens System Settings
    case .remindersDenied:
        // Show "Reminders access required" in popover
        // Disable reminder scanning
        // Show "Re-request" button → opens System Settings
    case .allDenied:
        // Show full permissions-needed state
        // Minimal UI with setup instructions
    }
}
```

### Reading Reminders

```swift
func fetchOpenReminders(from lists: [EKCalendar]) async -> [EKReminder] {
    let predicate = eventStore.predicateForIncompleteReminders(
        withDueDateStarting: nil,
        ending: nil,
        calendars: lists
    )
    return await withCheckedContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            continuation.resume(returning: reminders ?? [])
        }
    }
}
```

### Creating Calendar Events

```swift
func createTimeBlock(for task: ProcrastiNautTask, on calendar: EKCalendar) throws -> EKEvent {
    // Re-verify no conflicts before creating
    let conflicts = checkForConflicts(start: task.suggestedStartTime!,
                                       end: task.suggestedEndTime!,
                                       calendars: monitoredCalendars)
    guard conflicts.isEmpty else {
        throw ProcrastiNautError.conflictDetected(conflicts)
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = "📋 \(task.reminderTitle)"
    if let blockIndex = task.blockIndex, let total = task.totalBlocks {
        event.title = "📋 \(task.reminderTitle) (\(blockIndex)/\(total))"
    }
    event.startDate = task.suggestedStartTime
    event.endDate = task.suggestedEndTime
    event.calendar = calendar
    event.timeZone = .current  // Shifts with local time on travel

    // Carry reminder context into event
    var notes = "Created by ProcrastiNaut\nReminder: \(task.reminderIdentifier)"
    if let reminderNotes = task.reminderNotes {
        notes += "\n\n--- Original Notes ---\n\(reminderNotes)"
    }
    event.notes = notes
    if let url = task.reminderURL {
        event.url = url
    }

    // Color coding
    // Note: EKEvent color is controlled by calendar, but we can use
    // separate calendars or rely on the title prefix for visual distinction

    try eventStore.save(event, span: .thisEvent)
    return event
}
```

### Tracking ProcrastiNaut Events

```swift
// Store mapping of our events for change detection
func trackCreatedEvent(_ event: EKEvent, for task: ProcrastiNautTask) {
    let record = TrackedEvent(
        eventIdentifier: event.calendarItemIdentifier,
        taskID: task.id,
        originalStart: event.startDate,
        originalEnd: event.endDate
    )
    // Persist in SwiftData
}

// On EKEventStoreChangedNotification
func reconcileTrackedEvents() {
    for tracked in allTrackedEvents {
        guard let event = eventStore.event(withIdentifier: tracked.eventIdentifier) else {
            // Event was deleted externally
            handleExternalDeletion(tracked)
            continue
        }
        if event.startDate != tracked.originalStart || event.endDate != tracked.originalEnd {
            // Event was moved externally
            handleExternalMove(tracked, newStart: event.startDate, newEnd: event.endDate)
        }
    }
}
```

### Completing Reminders

```swift
func completeReminder(identifier: String) throws {
    guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
        throw ProcrastiNautError.reminderNotFound
    }
    reminder.isCompleted = true
    reminder.completionDate = Date()
    try eventStore.save(reminder, commit: true)
}
```

---

## Custom Notification System

Instead of relying solely on `UNUserNotificationCenter` (which has limited action buttons and can't show complex UI), ProcrastiNaut uses a hybrid approach:

### System Notifications (for background alerts)

Used only for the morning scan notification and snooze, since these need to work when the popover isn't visible.

```swift
// Morning scan — system notification with snooze actions
let scanAction = UNNotificationAction(identifier: "REVIEW", title: "Review Now")
let snooze30 = UNNotificationAction(identifier: "SNOOZE_30", title: "Snooze 30m")
let snooze60 = UNNotificationAction(identifier: "SNOOZE_60", title: "Snooze 1h")

let scanCategory = UNNotificationCategory(
    identifier: "MORNING_SCAN",
    actions: [scanAction, snooze30, snooze60],
    intentIdentifiers: []
)
```

### Custom In-App Notifications (for follow-ups)

A custom `NSPanel` or popover anchored to the menu bar icon, providing full interactive controls:

```swift
class CustomNotificationManager: ObservableObject {
    @Published var pendingFollowUps: [ProcrastiNautTask] = []
    @Published var currentFollowUp: ProcrastiNautTask?
    @Published var undoAction: UndoableAction?

    private var followUpQueue: [FollowUpItem] = []
    private var lastFollowUpTime: Date?
    private let rateLimitSeconds: Int  // from settings

    // Queue follow-ups with rate limiting
    func scheduleFollowUp(for task: ProcrastiNautTask, delay: TimeInterval) {
        let item = FollowUpItem(task: task, fireAt: Date().addingTimeInterval(delay))
        followUpQueue.append(item)
        followUpQueue.sort { $0.fireAt < $1.fireAt }
        processQueue()
    }

    // Show next follow-up, respecting rate limit
    func processQueue() {
        guard let next = followUpQueue.first else { return }

        if let lastTime = lastFollowUpTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < Double(rateLimitSeconds) {
                // Schedule to fire after rate limit window
                let delay = Double(rateLimitSeconds) - elapsed
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.processQueue()
                }
                return
            }
        }

        if Date() >= next.fireAt {
            followUpQueue.removeFirst()
            currentFollowUp = next.task
            lastFollowUpTime = Date()
            showFollowUpPopover()
        } else {
            // Schedule for fire time
            let delay = next.fireAt.timeIntervalSinceNow
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.processQueue()
            }
        }
    }

    // Undo support
    func markDone(_ task: ProcrastiNautTask) {
        let action = UndoableAction(task: task, action: .completed, expiresAt: Date().addingTimeInterval(Double(undoWindowDuration)))
        undoAction = action

        // Delay actual completion by undo window
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(undoWindowDuration)) {
            if self.undoAction?.id == action.id {
                self.commitAction(action)
                self.undoAction = nil
            }
        }
    }

    func undo() {
        undoAction = nil
        // Task remains in its previous state
    }
}
```

### Overrun Detection

```swift
class OverrunMonitor {
    private var activeTimer: Timer?

    func startMonitoring(task: ProcrastiNautTask) {
        guard let endTime = task.suggestedEndTime else { return }

        // Schedule 5-minute warning
        let warningTime = endTime.addingTimeInterval(-300) // 5 min before
        let delay = warningTime.timeIntervalSinceNow

        if delay > 0 {
            activeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                self.showOverrunWarning(task: task)
            }
        }
    }

    func showOverrunWarning(task: ProcrastiNautTask) {
        // Check if there's a next event soon
        let nextEvent = findNextEvent(after: task.suggestedEndTime!)
        // Show overrun warning popover with next event info
    }
}
```

---

## Persistence

### SwiftData Models

```swift
@Model
class TaskRecord {
    var taskID: UUID
    var reminderTitle: String
    var reminderListName: String
    var scheduledDate: Date
    var scheduledStart: Date
    var scheduledEnd: Date
    var status: String              // TaskStatus raw value
    var rescheduleCount: Int
    var completedAt: Date?
    var actualDuration: Double?     // seconds, for duration learning
    var blockIndex: Int?
    var totalBlocks: Int?
    var isArchived: Bool = false
    var archivedAt: Date?

    init(...) { ... }
}

@Model
class DailyStats {
    var date: Date
    var totalSuggested: Int
    var totalApproved: Int
    var totalCompleted: Int
    var totalRescheduled: Int
    var totalSkipped: Int
    var totalPartial: Int
    var completionRate: Double
    var scanType: String            // ScanType raw value
    var isArchived: Bool = false
    var archivedAt: Date?

    init(...) { ... }
}

@Model
class DurationEstimate {
    var listName: String
    var titleKeywords: String?      // For recurring task matching
    var recentDurations: [Double]   // Last 20 actual durations (seconds)
    var averageDuration: Double     // Rolling average
    var lastUpdated: Date

    func addSample(_ duration: Double) {
        recentDurations.append(duration)
        if recentDurations.count > 20 {
            recentDurations.removeFirst()
        }
        averageDuration = recentDurations.reduce(0, +) / Double(recentDurations.count)
        lastUpdated = Date()
    }
}

@Model
class TrackedEvent {
    var eventIdentifier: String
    var taskID: UUID
    var originalStart: Date
    var originalEnd: Date
    var isActive: Bool = true

    init(...) { ... }
}

@Model
class GamificationRecord {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalTasksCompleted: Int = 0
    var currentLevel: Int = 1
    var lastStreakDate: Date?
    var earnedBadgeIDs: [String] = []

    init() { }
}
```

### Auto-Archive & Cleanup

```swift
class ArchiveManager {
    let modelContext: ModelContext

    // Run daily (e.g., during morning scan)
    func performMaintenance(settings: UserSettings) {
        archiveOldRecords(olderThan: settings.archiveAfterDays)
        deleteStaleArchives(olderThan: settings.deleteArchivedAfterDays)
    }

    func archiveOldRecords(olderThan days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        // Archive TaskRecords
        let taskPredicate = #Predicate<TaskRecord> {
            $0.scheduledDate < cutoff && !$0.isArchived
        }
        let tasks = try? modelContext.fetch(FetchDescriptor(predicate: taskPredicate))
        tasks?.forEach {
            $0.isArchived = true
            $0.archivedAt = Date()
        }

        // Archive DailyStats
        let statsPredicate = #Predicate<DailyStats> {
            $0.date < cutoff && !$0.isArchived
        }
        let stats = try? modelContext.fetch(FetchDescriptor(predicate: statsPredicate))
        stats?.forEach {
            $0.isArchived = true
            $0.archivedAt = Date()
        }

        try? modelContext.save()
    }

    func deleteStaleArchives(olderThan days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let taskPredicate = #Predicate<TaskRecord> {
            $0.isArchived && ($0.archivedAt ?? Date.distantPast) < cutoff
        }
        try? modelContext.delete(model: TaskRecord.self, where: taskPredicate)

        let statsPredicate = #Predicate<DailyStats> {
            $0.isArchived && ($0.archivedAt ?? Date.distantPast) < cutoff
        }
        try? modelContext.delete(model: DailyStats.self, where: statsPredicate)

        try? modelContext.save()
    }
}
```

---

## Project Structure

```
ProcrastiNaut/
├── ProcrastiNautApp.swift              # App entry point, menu bar setup
├── Info.plist                           # LSUIElement = true (menu bar only)
│
├── Core/
│   ├── EventKitManager.swift            # Unified Reminders + Calendar access
│   ├── SuggestionEngine.swift           # Availability analysis + task matching + splitting
│   ├── SchedulerService.swift           # Daily scan timing + wake-from-sleep + follow-up triggers
│   ├── ConflictMonitor.swift            # Calendar change detection + conflict resolution
│   ├── CustomNotificationManager.swift  # In-app follow-up notifications with full controls
│   ├── DurationLearningService.swift    # Learns task durations from completion history
│   ├── EnergyManager.swift              # Energy-level time range management
│   ├── GamificationEngine.swift         # Streaks, badges, levels, space-themed progression
│   └── ArchiveManager.swift             # Auto-archive and cleanup of old records
│
├── Models/
│   ├── ProcrastiNautTask.swift          # Task data model (with energy, splitting, partial)
│   ├── DailyPlan.swift                  # Daily plan container
│   ├── WeeklyPlan.swift                 # Weekly plan container
│   ├── EnergyBlock.swift                # Energy level time range model
│   ├── GamificationState.swift          # Streaks, badges, levels
│   ├── UserSettings.swift               # @AppStorage settings (TimeInterval for dates)
│   ├── TaskRecord.swift                 # SwiftData persistence model
│   ├── DailyStats.swift                 # SwiftData stats model
│   ├── DurationEstimate.swift           # SwiftData learned duration model
│   └── TrackedEvent.swift               # SwiftData calendar event tracking model
│
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift      # NSStatusItem, persistent popover, keyboard shortcuts
│   │   ├── MenuBarPopover.swift         # Main popover view (stays open until dismissed)
│   │   ├── MenuBarIcon.swift            # Dynamic icon states (streak indicator)
│   │   └── QuickAddView.swift           # Inline quick-add text field
│   │
│   ├── Suggestions/
│   │   ├── SuggestionListView.swift     # Review all suggestions (drag-and-drop reorder)
│   │   ├── SuggestionCardView.swift     # Individual card (energy indicator, learned duration)
│   │   └── TimePickerView.swift         # Custom time adjustment
│   │
│   ├── Settings/
│   │   ├── SettingsWindow.swift         # Main settings window
│   │   ├── GeneralSettingsView.swift    # Timing + behavior prefs
│   │   ├── CalendarSettingsView.swift   # Calendar selection + color coding
│   │   ├── ReminderSettingsView.swift   # Reminder list selection
│   │   ├── ScheduleSettingsView.swift   # Working hours, days
│   │   ├── EnergySettingsView.swift     # Energy level configuration
│   │   ├── GamificationSettingsView.swift # Streak/badge preferences
│   │   ├── DataSettingsView.swift       # Archive/cleanup settings
│   │   ├── AdvancedSettingsView.swift   # Focus blocks, weekly planning, permissions
│   │   └── PermissionsView.swift        # Permission status + re-request buttons
│   │
│   ├── FollowUp/
│   │   ├── CustomFollowUpView.swift     # In-app follow-up notification popover
│   │   ├── PartialCompletionView.swift  # Partial progress entry + reschedule remainder
│   │   ├── RescheduleView.swift         # Reschedule options
│   │   └── UndoBannerView.swift         # 30-second undo banner
│   │
│   ├── Conflicts/
│   │   ├── ConflictAlertView.swift      # Conflict detected notification
│   │   └── OverrunWarningView.swift     # Time running out warning
│   │
│   ├── Planning/
│   │   ├── WeeklyPlanView.swift         # Weekly planning overview
│   │   ├── DayColumnView.swift          # Per-day column in weekly view
│   │   └── NoAvailabilityView.swift     # No slots available options
│   │
│   └── Stats/
│       ├── CompletionStatsView.swift    # Weekly/monthly completion stats
│       ├── StreakView.swift             # Current streak + history
│       └── BadgesView.swift            # Earned badges gallery
│
├── Utilities/
│   ├── DateHelpers.swift                # Date/time formatting + TimeInterval conversions
│   ├── DurationParser.swift             # Parse [duration:XXm] from notes
│   ├── LaunchAtLogin.swift              # SMAppService integration
│   ├── WakeObserver.swift               # NSWorkspace.didWakeNotification handler
│   └── KeyboardShortcuts.swift          # Popover keyboard shortcut handling
│
└── Resources/
    └── Assets.xcassets                  # App icon, menu bar icons, badge icons
```

---

## Key Technical Decisions

### Why Menu Bar App?
- Always accessible without cluttering the Dock
- Lightweight — no main window needed
- `LSUIElement = true` in Info.plist hides from Dock
- Popover UI is natural for quick interactions
- Persistent popover (non-transient) so it stays open during review

### Why EventKit (not CalendarStore)?
- Single framework for both Reminders and Calendar
- Full read/write access to both stores
- Change notifications via `EKEventStoreChangedNotification`
- Modern async APIs available

### Why SwiftData over Core Data?
- Native Swift, less boilerplate
- `@Model` macro simplifies persistence
- Built-in SwiftUI integration
- Used for task history, stats, duration learning, and event tracking

### Why Custom Notifications over UNUserNotificationCenter?
- System notifications have a max of 3-4 action buttons
- Can't show complex UI (partial completion, reschedule options, undo)
- Custom popover allows full SwiftUI views with any interaction
- System notifications still used for morning scan (works when popover is closed)

### Why TimeInterval for @AppStorage Dates?
- `@AppStorage` doesn't natively support `Date`
- Storing as `Double` (seconds from midnight) is simple and reliable
- Helper functions convert to/from `Date` for display

### Background Scheduling
- `SchedulerService` uses `Timer` for morning scan when app is running
- `NSWorkspace.didWakeNotification` for wake-from-sleep fallback
- `SMAppService` for launch-at-login
- Custom in-app notifications for follow-ups (queued, rate-limited)
- `EKEventStoreChangedNotification` to react to external calendar changes

### Buffer Application
- Buffer is applied between any existing event and a ProcrastiNaut block
- If a meeting ends at 10:00 and buffer is 10 min, earliest task block starts at 10:10
- Buffer also applied between consecutive ProcrastiNaut blocks

### Time Zone Handling
- Calendar events created with `timeZone = .current`
- Events shift to local time when user travels
- Consistent with standard macOS Calendar behavior

---

## Future Enhancements (v2+)

- **Widgets:** WidgetKit for Today's Plan on desktop
- **Shortcuts Integration:** Siri Shortcuts for "What's my plan today?"
- **AI Duration Estimation:** Use ML models for more accurate duration predictions
- **Calendar Sync:** Two-way sync if user moves/resizes events manually (basic version in v1 via ConflictMonitor)
- **Team Awareness:** Respect shared calendar busy times
- **Pomodoro Mode:** Break long tasks into focus intervals with breaks
- **iOS Companion:** Paired iPhone app for on-the-go follow-ups
- **Natural Language Input:** "Block 2 hours for the security audit tomorrow morning"
- **Apple Watch Complications:** Quick completion from wrist
- **Focus Mode Integration:** Automatically enable macOS Focus when in a task block
