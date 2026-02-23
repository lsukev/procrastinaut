import SwiftUI

/// A confetti particle animation overlay for milestone celebrations
struct ConfettiView: View {
    @Binding var isActive: Bool

    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                particle.shape
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * particle.aspectRatio)
                    .rotationEffect(.degrees(particle.rotation))
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                spawnConfetti()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isActive = false
                    particles.removeAll()
                }
            }
        }
    }

    private func spawnConfetti() {
        particles = (0..<40).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                x: CGFloat.random(in: -180...180),
                y: -20,
                size: CGFloat.random(in: 4...8),
                aspectRatio: CGFloat.random(in: 0.5...2.0),
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
        }

        // Animate particles falling
        for i in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let targetY = CGFloat.random(in: 100...400)
            let targetX = particles[i].x + CGFloat.random(in: -60...60)
            let targetRotation = particles[i].rotation + Double.random(in: -180...180)

            withAnimation(.easeOut(duration: 2.0).delay(delay)) {
                particles[i].y = targetY
                particles[i].x = targetX
                particles[i].rotation = targetRotation
            }
            withAnimation(.easeIn(duration: 0.8).delay(delay + 1.5)) {
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let aspectRatio: CGFloat
    var rotation: Double
    var opacity: Double

    var shape: some Shape {
        RoundedRectangle(cornerRadius: 1)
    }
}
