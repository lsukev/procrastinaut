import AppKit
import Carbon

/// Registers global keyboard shortcuts:
/// - Hotkey 1 (Cmd+Shift+Space): Toggle the popover
/// - Hotkey 2 (configurable, default Cmd+Shift+N): Toggle Quick Chat panel
@MainActor
final class GlobalHotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var quickChatHotkeyRef: EventHotKeyRef?

    var onHotkeyPressed: (() -> Void)?
    var onQuickChatHotkeyPressed: (() -> Void)?

    private static let hotkeyID = EventHotKeyID(signature: OSType(0x504E4154), id: 1)  // "PNAT"
    private static let quickChatHotkeyID = EventHotKeyID(signature: OSType(0x504E4154), id: 2)

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            if hotkeyID.id == 1 {
                Task { @MainActor in
                    GlobalHotkeyManager.shared?.onHotkeyPressed?()
                }
            } else if hotkeyID.id == 2 {
                Task { @MainActor in
                    GlobalHotkeyManager.shared?.onQuickChatHotkeyPressed?()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Hotkey 1: Cmd+Shift+Space — toggle popover
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 49  // Space bar

        RegisterEventHotKey(
            keyCode,
            modifiers,
            GlobalHotkeyManager.hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        // Hotkey 2: Quick Chat (configurable)
        registerQuickChatHotkey()
    }

    /// Register (or re-register) the Quick Chat hotkey from UserSettings.
    func registerQuickChatHotkey() {
        unregisterQuickChatHotkey()

        let settings = UserSettings.shared
        let keyCode = UInt32(settings.quickChatKeyCode)
        let modifiers = UInt32(settings.quickChatModifiers)

        RegisterEventHotKey(
            keyCode,
            modifiers,
            GlobalHotkeyManager.quickChatHotkeyID,
            GetApplicationEventTarget(),
            0,
            &quickChatHotkeyRef
        )
    }

    /// Unregister only the Quick Chat hotkey (for re-registration after settings change).
    func unregisterQuickChatHotkey() {
        if let quickChatHotkeyRef {
            UnregisterEventHotKey(quickChatHotkeyRef)
            self.quickChatHotkeyRef = nil
        }
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        unregisterQuickChatHotkey()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    // Singleton for the C callback
    static var shared: GlobalHotkeyManager?

    deinit {
        // Note: deinit can't be @MainActor, but cleanup is best-effort
    }
}
