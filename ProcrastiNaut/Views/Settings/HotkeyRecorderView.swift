import SwiftUI
import Carbon

/// A shortcut recorder button for capturing global hotkey combinations.
/// Displays the current shortcut and enters recording mode when clicked.
struct HotkeyRecorderView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        HStack {
            Text("Quick Chat Shortcut")

            Spacer()

            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "Press shortcut\u{2026}" : currentShortcutString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isRecording ? .blue : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isRecording ? .blue : .clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            if currentShortcutString != defaultShortcutString {
                Button("Reset") {
                    resetToDefault()
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Display

    private var currentShortcutString: String {
        shortcutString(keyCode: settings.quickChatKeyCode, modifiers: settings.quickChatModifiers)
    }

    private var defaultShortcutString: String {
        shortcutString(keyCode: 45, modifiers: 0x0108) // Cmd+Shift+N
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = carbonModifiers(from: event.modifierFlags)
            let keyCode = Int(event.keyCode)

            // Ignore bare modifier presses and Escape to cancel
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }

            // Require at least one modifier key
            guard modifiers != 0 else { return nil }

            settings.quickChatKeyCode = keyCode
            settings.quickChatModifiers = modifiers
            stopRecording()

            // Re-register the hotkey with new settings
            GlobalHotkeyManager.shared?.registerQuickChatHotkey()

            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func resetToDefault() {
        settings.quickChatKeyCode = 45        // 'N' key
        settings.quickChatModifiers = 0x0108  // cmdKey | shiftKey
        GlobalHotkeyManager.shared?.registerQuickChatHotkey()
    }

    // MARK: - Conversion Helpers

    /// Convert NSEvent modifier flags to Carbon modifier flags.
    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        return carbon
    }

    /// Build a human-readable string from key code and Carbon modifier flags.
    private func shortcutString(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []

        if modifiers & controlKey != 0 { parts.append("\u{2303}") }  // ⌃
        if modifiers & optionKey != 0 { parts.append("\u{2325}") }   // ⌥
        if modifiers & shiftKey != 0 { parts.append("\u{21E7}") }    // ⇧
        if modifiers & cmdKey != 0 { parts.append("\u{2318}") }      // ⌘

        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    /// Map Carbon key code to a human-readable key name.
    private func keyCodeToString(_ keyCode: Int) -> String {
        // Common key codes (Carbon kVK_* constants)
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 50: return "`"
        case 51: return "\u{232B}"  // ⌫ Delete
        case 53: return "\u{238B}"  // ⎋ Escape
        case 36: return "\u{21A9}"  // ↩ Return
        case 48: return "\u{21E5}"  // ⇥ Tab
        case 76: return "\u{2324}"  // ⌤ Enter
        case 123: return "\u{2190}" // ← Left
        case 124: return "\u{2192}" // → Right
        case 125: return "\u{2193}" // ↓ Down
        case 126: return "\u{2191}" // ↑ Up
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "Key\(keyCode)"
        }
    }
}
