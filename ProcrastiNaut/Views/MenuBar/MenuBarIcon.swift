import AppKit

enum MenuBarIconState {
    case normal
    case pending
    case active
    case allComplete
    case streak

    var systemSymbolName: String {
        switch self {
        case .normal:
            "checkmark.circle"
        case .pending:
            "checkmark.circle.badge.questionmark"
        case .active:
            "play.circle"
        case .allComplete:
            "checkmark.circle.fill"
        case .streak:
            "flame"
        }
    }

    func image(size: CGFloat = 18) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: "ProcrastiNaut")
        return image?.withSymbolConfiguration(config)
    }
}
