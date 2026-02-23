import SwiftUI

struct TemplateDragCard: View {
    let template: EventTemplate

    private var templateColor: Color {
        switch template.color {
        case "purple": .purple
        case "blue": .blue
        case "green": .green
        case "indigo": .indigo
        case "red": .red
        case "orange": .orange
        case "pink": .pink
        case "teal": .teal
        case "yellow": .yellow
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: template.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(templateColor)
                .frame(width: 22, height: 22)
                .background(templateColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(template.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text(formatDuration(template.duration))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(templateColor.opacity(0.2), lineWidth: 0.5)
        )
        .draggable("template:\(template.id.uuidString)") {
            // Drag preview
            HStack(spacing: 6) {
                Image(systemName: template.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(templateColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text(formatDuration(template.duration))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
