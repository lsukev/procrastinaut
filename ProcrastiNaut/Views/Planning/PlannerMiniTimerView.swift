import SwiftUI

struct PlannerMiniTimerView: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var isHovering = false

    var body: some View {
        if viewModel.focusTimerRunning, let event = viewModel.focusTimerEvent {
            VStack(spacing: 0) {
                // Compact view
                HStack(spacing: 10) {
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(.quaternary, lineWidth: 3)
                            .frame(width: 32, height: 32)

                        Circle()
                            .trim(from: 0, to: viewModel.focusTimerProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: "brain")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)

                        Text(viewModel.focusTimerFormatted)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    // Controls
                    if isHovering {
                        Button {
                            viewModel.stopFocusTimer()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                                .frame(width: 24, height: 24)
                                .background(.red.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .frame(width: isHovering ? 240 : 200)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
    }
}
