import SwiftUI

struct PlannerChatBar: View {
    @Bindable var viewModel: PlannerViewModel

    @FocusState private var isFocused: Bool
    @State private var micPulse = false

    private var isRecording: Bool {
        viewModel.speechService.isRecording
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Main input row
            HStack(spacing: 10) {
                // AI sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20)

                // Text field — shows live transcription while recording
                TextField(
                    isRecording
                        ? "Listening…"
                        : "Ask anything… \"Lunch tomorrow at noon\" or \"Remind me to call dentist\"",
                    text: isRecording
                        ? .constant(viewModel.speechService.transcribedText)
                        : $viewModel.chatBarText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit {
                    Task { await viewModel.submitChatBar() }
                }
                .disabled(viewModel.chatBarService.isProcessing || isRecording)

                // Microphone button
                Button {
                    Task { await viewModel.toggleVoiceInput() }
                } label: {
                    ZStack {
                        if isRecording {
                            // Pulsing red background
                            Circle()
                                .fill(.red.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .scaleEffect(micPulse ? 1.3 : 1.0)
                                .opacity(micPulse ? 0.0 : 0.6)
                        }

                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isRecording ? .red : .secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                isRecording
                                    ? AnyShapeStyle(.red.opacity(0.12))
                                    : AnyShapeStyle(.clear)
                            )
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.chatBarService.isProcessing)
                .help(isRecording ? "Stop recording" : "Voice input")

                // Right side: send button or loading indicator
                if viewModel.chatBarService.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20, height: 20)
                } else if !viewModel.chatBarText.trimmingCharacters(in: .whitespaces).isEmpty && !isRecording {
                    Button {
                        Task { await viewModel.submitChatBar() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            // Result banner (success or error)
            if viewModel.showChatBarResult {
                resultBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showChatBarResult)
        .animation(.easeInOut(duration: 0.15), value: viewModel.chatBarText.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .onChange(of: isRecording) { _, recording in
            if recording {
                startPulseAnimation()
            } else {
                micPulse = false
            }
        }
        // Unfocus chat bar when an event is selected so Delete key works
        .onChange(of: viewModel.editingEvent?.id) { _, newValue in
            if newValue != nil {
                isFocused = false
            }
        }
        // Deselect event when chat bar gets focus
        .onChange(of: isFocused) { _, focused in
            if focused && viewModel.editingEvent != nil {
                viewModel.cancelEdit()
            }
        }
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
            micPulse = true
        }
    }

    // MARK: - Result Banner

    @ViewBuilder
    private var resultBanner: some View {
        if let error = viewModel.chatBarService.error {
            // Error state
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)

                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button {
                    viewModel.chatBarService.error = nil
                    viewModel.showChatBarResult = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.06))
        } else if let result = viewModel.chatBarService.lastResult, result.success {
            // Success state
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)

                Text(result.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.showChatBarResult = false
                    viewModel.chatBarService.lastResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.green.opacity(0.06))
        }
    }
}
