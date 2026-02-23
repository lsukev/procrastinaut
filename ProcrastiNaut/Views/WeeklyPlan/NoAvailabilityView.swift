import SwiftUI

struct NoAvailabilityView: View {
    let message: String
    let suggestion: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.minus")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline.weight(.medium))

            Text(suggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
