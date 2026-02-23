import SwiftUI

@MainActor @Observable
final class AppTheme {
    static let shared = AppTheme()
    private let settings = UserSettings.shared

    // MARK: - Accent Color

    var accentColor: Color {
        Self.color(named: settings.accentColorName) ?? .blue
    }

    static let accentColorOptions: [(name: String, color: Color)] = [
        ("blue", .blue),
        ("purple", .purple),
        ("orange", .orange),
        ("teal", .teal),
        ("pink", .pink),
        ("red", .red),
        ("indigo", .indigo),
    ]

    // MARK: - Font Scale

    var fontScale: CGFloat {
        switch settings.fontSizeTier {
        case "small": return 0.9
        case "large": return 1.1
        default: return 1.0
        }
    }

    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: round(size * fontScale), weight: weight, design: design)
    }

    // MARK: - Calendar Density

    var hourRowHeightDay: CGFloat {
        settings.calendarDensity == "compact" ? 60 : 80
    }

    var hourRowHeightWeek: CGFloat {
        settings.calendarDensity == "compact" ? 48 : 60
    }

    var eventVerticalPadding: CGFloat {
        settings.calendarDensity == "compact" ? 2 : 4
    }

    // MARK: - Now Line Color

    var nowLineColor: Color {
        Self.color(named: settings.nowLineColorName) ?? .red
    }

    static let nowLineColorOptions: [(name: String, color: Color)] = [
        ("red", .red),
        ("blue", .blue),
        ("orange", .orange),
        ("green", .green),
        ("white", .white),
    ]

    // MARK: - Animations

    var animationsEnabled: Bool {
        settings.animationsEnabled
    }

    // MARK: - Appearance Mode

    var preferredColorScheme: ColorScheme? {
        switch settings.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: - Helpers

    private static func color(named name: String) -> Color? {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "teal": return .teal
        case "pink": return .pink
        case "red": return .red
        case "indigo": return .indigo
        case "green": return .green
        case "white": return .white
        default: return nil
        }
    }
}
