import SwiftUI

struct AISuggestionsPanel: View {
    @Bindable var viewModel: PlannerViewModel

    private var aiService: AISchedulingService { viewModel.aiService }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("AI Suggestions")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                if !aiService.suggestions.isEmpty {
                    Button {
                        withAnimation { aiService.dismissAll() }
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.showAISuggestions = false
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if aiService.isProcessing {
                AILoadingView()
            } else if let error = aiService.error {
                errorView(error)
            } else if aiService.suggestions.isEmpty {
                emptyView
            } else {
                suggestionsList
            }

            Spacer(minLength: 0)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)

            Button("Try Again") {
                Task { await viewModel.requestAISuggestions() }
            }
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.green.opacity(0.6))

            Text("No suggestions")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("All suggestions were accepted or dismissed")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Run Again") {
                Task { await viewModel.requestAISuggestions() }
            }
            .controlSize(.small)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            // Reasoning disclosure
            if !aiService.reasoning.isEmpty {
                DisclosureGroup {
                    Text(aiService.reasoning)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("AI Reasoning")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
            }

            // Suggestion count
            HStack {
                Text("\(aiService.suggestions.count) suggestion\(aiService.suggestions.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(aiService.suggestions) { suggestion in
                        AISuggestionCard(
                            suggestion: suggestion,
                            onAccept: {
                                withAnimation { viewModel.acceptAISuggestion(suggestion) }
                            },
                            onDismiss: {
                                withAnimation { aiService.dismissSuggestion(suggestion) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Loading View (animated status messages)

private struct AILoadingView: View {
    @State private var currentPhrase = 0
    @State private var opacity: Double = 1.0
    @State private var sparkleRotation: Double = 0

    private let phrases = [
        "Reading your reminders...",
        "Scanning your calendar...",
        "Analyzing free time slots...",
        "Checking energy levels...",
        "Weighing task priorities...",
        "Avoiding conflicts...",
        "Optimizing your schedule...",
        "Finding the best time slots...",
        "Almost there...",
        "Crunching the numbers...",
        "Matching tasks to energy...",
        "Building your plan...",
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated sparkle icon
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.purple.opacity(0.0), .purple.opacity(0.4), .purple.opacity(0.0)],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(sparkleRotation))

                // Inner icon
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse, options: .repeating)
            }

            // Rotating status text
            Text(phrases[currentPhrase])
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(opacity)
                .animation(.easeInOut(duration: 0.3), value: opacity)
                .frame(height: 20)

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.purple.opacity(dotOpacity(for: i)))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            startPhraseRotation()
            startSpinning()
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let phase = (currentPhrase + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.5
        default: return 0.2
        }
    }

    private func startPhraseRotation() {
        Timer.scheduledTimer(withTimeInterval: 2.2, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
                try? await Task.sleep(for: .milliseconds(250))
                currentPhrase = (currentPhrase + 1) % phrases.count
                withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
            }
        }
    }

    private func startSpinning() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
    }
}

// MARK: - Suggestion Card

struct AISuggestionCard: View {
    let suggestion: AISuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    private var confidenceColor: Color {
        if suggestion.confidence >= 0.8 { return .green }
        if suggestion.confidence >= 0.5 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 7, height: 7)

                Text(suggestion.reminderTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)

                Text(formatSuggestionDateTime(suggestion))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text(suggestion.reason)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            HStack {
                Spacer()
                Button {
                    onAccept()
                } label: {
                    Label("Accept", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding(11)
        .background(.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.purple.opacity(0.15), lineWidth: 1)
        )
    }

    private func formatSuggestionDateTime(_ suggestion: AISuggestion) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let day = dayFormatter.string(from: suggestion.suggestedDate)
        let start = timeFormatter.string(from: suggestion.suggestedStartTime)
        let end = timeFormatter.string(from: suggestion.suggestedEndTime)
        return "\(day) \u{2022} \(start) \u{2013} \(end)"
    }
}
