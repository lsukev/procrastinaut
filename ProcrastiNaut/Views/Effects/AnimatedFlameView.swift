import SwiftUI

/// An animated pulsing/glowing flame icon for active streaks
struct AnimatedFlameView: View {
    let isActive: Bool
    let streakCount: Int

    @State private var isPulsing = false
    @State private var glowOpacity = 0.3

    var body: some View {
        ZStack {
            if isActive {
                // Glow layer
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                    .blur(radius: 6)
                    .opacity(glowOpacity)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
            }

            // Main flame
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    isActive
                        ? LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .onAppear {
            if isActive {
                startPulsing()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startPulsing()
            } else {
                isPulsing = false
            }
        }
    }

    private func startPulsing() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
            glowOpacity = 0.6
        }
    }
}
