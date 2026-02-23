import SwiftUI

struct XPGainView: View {
    let amount: Int
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack {
            Spacer()

            Text("+\(amount) XP")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .orange.opacity(0.4), radius: 4, y: 1)
                .scaleEffect(scale)
                .offset(y: offset)
                .opacity(opacity)

            Spacer()
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                scale = 1.2
            }
            withAnimation(.easeOut(duration: 0.15).delay(0.3)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 1.2).delay(0.6)) {
                offset = -60
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onComplete()
            }
        }
    }
}
