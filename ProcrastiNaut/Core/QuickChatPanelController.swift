import AppKit
import SwiftUI

/// Borderless NSPanel that can become key (receive keyboard input).
/// Required because `.borderless` panels return `false` from `canBecomeKey` by default.
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Manages a floating NSPanel for the Quick Chat input overlay.
/// Uses `.nonactivatingPanel` so it can receive keyboard focus without
/// stealing activation from the frontmost app.
@MainActor
final class QuickChatPanelController {
    private var panel: KeyablePanel?
    private var outsideClickMonitor: Any?
    private var viewModel = QuickChatViewModel()

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Toggle

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Show

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        guard let panel else { return }

        viewModel.reset()
        viewModel.onDismiss = { [weak self] in
            self?.hidePanel()
        }

        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        installOutsideClickMonitor()
    }

    // MARK: - Hide

    func hidePanel() {
        guard let panel, panel.isVisible else { return }

        removeOutsideClickMonitor()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.viewModel.reset()
        })
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 80),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = false
        // Accept mouse events so we can interact with the text field
        panel.acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: QuickChatView(viewModel: viewModel))
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
    }

    // MARK: - Positioning

    private func positionPanel() {
        guard let panel,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 600
        let x = screenFrame.midX - panelWidth / 2
        // Position roughly 25% from top of screen (Spotlight-style)
        let y = screenFrame.maxY - screenFrame.height * 0.25

        panel.setFrame(
            NSRect(x: x, y: y, width: panelWidth, height: 200),
            display: true
        )
    }

    // MARK: - Outside Click Monitor

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
