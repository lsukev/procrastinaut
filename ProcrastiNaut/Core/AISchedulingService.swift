import Foundation

struct AISuggestion: Identifiable {
    let id = UUID()
    let reminderID: String
    let reminderTitle: String
    let suggestedDate: Date
    let suggestedStartTime: Date
    let suggestedEndTime: Date
    let reason: String
    let confidence: Double
}

@MainActor
@Observable
final class AISchedulingService {
    var suggestions: [AISuggestion] = []
    var reasoning: String = ""
    var isProcessing: Bool = false
    var error: String?

    private let apiClient = ClaudeAPIClient.shared
    private let settings = UserSettings.shared

    // MARK: - Generate Suggestions

    func generateSuggestions(
        reminders: [ReminderItem],
        events: [CalendarEventItem],
        lookAheadDays: Int
    ) async {
        let apiKey = settings.claudeAPIKey
        guard !apiKey.isEmpty else {
            error = "Please add your Claude API key in Settings > AI."
            return
        }

        let unplanned = reminders.filter { !$0.isPlanned }
        guard !unplanned.isEmpty else {
            error = "All tasks are already scheduled!"
            return
        }

        isProcessing = true
        error = nil
        suggestions = []
        reasoning = ""

        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(reminders: unplanned, events: events, lookAheadDays: lookAheadDays)

        do {
            let response = try await apiClient.sendMessage(
                system: systemPrompt,
                userMessage: userPrompt,
                model: settings.claudeModel,
                apiKey: apiKey
            )

            let parsed = try parseResponse(response, reminders: unplanned)
            self.reasoning = parsed.reasoning
            self.suggestions = parsed.suggestions
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Accept / Dismiss

    func acceptSuggestion(_ suggestion: AISuggestion) -> AISuggestion {
        suggestions.removeAll { $0.id == suggestion.id }
        return suggestion
    }

    func dismissSuggestion(_ suggestion: AISuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    func dismissAll() {
        suggestions = []
        reasoning = ""
    }

    // MARK: - Prompt Building

    private func buildSystemPrompt() -> String {
        """
        You are a scheduling assistant for ProcrastiNaut, a macOS productivity app. \
        Given a user's open reminders and their calendar events, suggest optimal times \
        to schedule each task.

        Consider:
        - Task priority and due dates (urgent/overdue tasks first)
        - Estimated duration of each task
        - Energy requirements matched to time-of-day energy levels
        - Working hours and working days
        - Buffer time between tasks
        - Existing calendar commitments (never double-book)
        - Spreading tasks across days to avoid overload

        Respond ONLY with valid JSON. No markdown fences, no explanation outside the JSON. \
        The JSON must have this exact structure:
        {
          "reasoning": "Brief explanation of your scheduling strategy",
          "suggestions": [
            {
              "reminderID": "the exact reminder ID string",
              "date": "YYYY-MM-DD",
              "startTime": "HH:mm",
              "endTime": "HH:mm",
              "reason": "Brief reason for this specific slot",
              "confidence": 0.9
            }
          ]
        }

        STRICT Rules:
        - ONLY suggest times within the specified working hours. Never before the start or after the end.
        - ONLY suggest times on the specified working days. Days marked as NON-WORKING must be completely ignored.
        - Never overlap with existing calendar events
        - Include buffer time between suggestions and existing events
        - confidence is 0.0-1.0 (higher = more certain this is a good slot)
        - If a task cannot be reasonably scheduled within working hours on working days, omit it and mention why in reasoning
        """
    }

    private func buildUserPrompt(reminders: [ReminderItem], events: [CalendarEventItem], lookAheadDays: Int) -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        let workStart = formatSecondsToTime(settings.workingHoursStart)
        let workEnd = formatSecondsToTime(settings.workingHoursEnd)

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let workingDayNames = settings.workingDays.sorted().map { dayNames[$0] }.joined(separator: ", ")

        var prompt = """
        Current date/time: \(dateFormatter.string(from: now)) \(timeFormatter.string(from: now))
        Timezone: \(TimeZone.current.identifier)
        Look-ahead period: \(lookAheadDays) days

        Working hours: \(workStart) - \(workEnd)
        Working days: \(workingDayNames)
        Buffer between tasks: \(settings.bufferBetweenBlocks) minutes

        """

        // Energy blocks
        let energyBlocks = settings.energyBlocks
        if !energyBlocks.isEmpty {
            prompt += "Energy levels by time of day:\n"
            for block in energyBlocks {
                let start = formatSecondsToTime(block.startTime)
                let end = formatSecondsToTime(block.endTime)
                prompt += "  \(start)-\(end): \(block.level.displayName)\n"
            }
            prompt += "\n"
        }

        // Reminders
        prompt += "OPEN REMINDERS (\(reminders.count) tasks to schedule):\n"
        for reminder in reminders {
            let durationMin = Int(reminder.duration / 60)
            var line = "- ID: \(reminder.id) | Title: \(reminder.title) | Priority: \(reminder.priority) | Duration: \(durationMin)min"
            if let dueDate = reminder.dueDate {
                line += " | Due: \(dateFormatter.string(from: dueDate))"
                if dueDate < now {
                    line += " (OVERDUE)"
                }
            }
            line += " | List: \(reminder.listName)"
            if let notes = reminder.notes, !notes.isEmpty {
                let cleanNotes = notes.replacingOccurrences(of: "\\[duration:\\d+m\\]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanNotes.isEmpty {
                    line += " | Notes: \(String(cleanNotes.prefix(100)))"
                }
            }
            prompt += "\(line)\n"
        }

        // Calendar events grouped by day
        prompt += "\nCALENDAR EVENTS (next \(lookAheadDays) days):\n"
        let cal = Calendar.current
        let workingDaySet = settings.workingDays
        let grouped = Dictionary(grouping: events.filter { !$0.isAllDay }) { event in
            cal.startOfDay(for: event.startDate)
        }
        for dayOffset in 0..<lookAheadDays {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) else { continue }
            let weekday = cal.component(.weekday, from: day) // 1=Sun, 2=Mon, ...
            let settingsWeekday = weekday - 1 // 0=Sun, 1=Mon, ...
            let isWorkingDay = workingDaySet.contains(settingsWeekday)
            let dayLabel = dateFormatter.string(from: day) + " (\(dayFormatter.string(from: day)))"

            if !isWorkingDay {
                prompt += "\n\(dayLabel): *** NON-WORKING DAY — DO NOT SCHEDULE ***\n"
                continue
            }

            let dayEvents = (grouped[day] ?? []).sorted { $0.startDate < $1.startDate }
            if dayEvents.isEmpty {
                prompt += "\n\(dayLabel): No events (available \(workStart)-\(workEnd))\n"
            } else {
                prompt += "\n\(dayLabel):\n"
                for event in dayEvents {
                    prompt += "  \(timeFormatter.string(from: event.startDate))-\(timeFormatter.string(from: event.endDate)) \(event.title)\n"
                }
            }
        }

        return prompt
    }

    // MARK: - Response Parsing

    private struct ParsedResponse {
        let reasoning: String
        let suggestions: [AISuggestion]
    }

    private func parseResponse(_ response: String, reminders: [ReminderItem]) throws -> ParsedResponse {
        // Extract JSON from the response (handle potential markdown fences)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }

        let reasoning = json["reasoning"] as? String ?? ""

        guard let suggestionsArray = json["suggestions"] as? [[String: Any]] else {
            throw ClaudeAPIError.invalidResponse
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let reminderMap = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0) })

        var parsed: [AISuggestion] = []
        for item in suggestionsArray {
            guard let reminderID = item["reminderID"] as? String,
                  let dateStr = item["date"] as? String,
                  let startStr = item["startTime"] as? String,
                  let endStr = item["endTime"] as? String,
                  let reason = item["reason"] as? String else {
                continue
            }

            let confidence = (item["confidence"] as? Double) ?? 0.5
            let reminder = reminderMap[reminderID]

            guard let date = dateFormatter.date(from: dateStr),
                  let startTime = combineDateAndTime(date: date, timeString: startStr),
                  let endTime = combineDateAndTime(date: date, timeString: endStr) else {
                continue
            }

            parsed.append(AISuggestion(
                reminderID: reminderID,
                reminderTitle: reminder?.title ?? "Unknown",
                suggestedDate: date,
                suggestedStartTime: startTime,
                suggestedEndTime: endTime,
                reason: reason,
                confidence: confidence
            ))
        }

        // Post-parse validation: filter out suggestions outside working hours/days
        let validated = filterToWorkingSchedule(parsed)

        return ParsedResponse(reasoning: reasoning, suggestions: validated)
    }

    /// Removes any suggestions that fall outside configured working hours or non-working days.
    private func filterToWorkingSchedule(_ suggestions: [AISuggestion]) -> [AISuggestion] {
        let cal = Calendar.current
        let workingDaySet = settings.workingDays
        let workStartSeconds = settings.workingHoursStart
        let workEndSeconds = settings.workingHoursEnd

        return suggestions.filter { suggestion in
            // Check working day (convert Calendar weekday 1-7 to settings 0-6)
            let weekday = cal.component(.weekday, from: suggestion.suggestedDate)
            let settingsWeekday = weekday - 1
            guard workingDaySet.contains(settingsWeekday) else { return false }

            // Check working hours
            let startComps = cal.dateComponents([.hour, .minute], from: suggestion.suggestedStartTime)
            let endComps = cal.dateComponents([.hour, .minute], from: suggestion.suggestedEndTime)
            let startSeconds = Double((startComps.hour ?? 0) * 3600 + (startComps.minute ?? 0) * 60)
            let endSeconds = Double((endComps.hour ?? 0) * 3600 + (endComps.minute ?? 0) * 60)

            guard startSeconds >= workStartSeconds, endSeconds <= workEndSeconds else { return false }
            return true
        }
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) -> String {
        // Try to find JSON between code fences first
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Try finding the outermost braces
        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}") {
            return String(text[openBrace...closeBrace])
        }
        return text
    }

    private func combineDateAndTime(date: Date, timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    private func formatSecondsToTime(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
}
