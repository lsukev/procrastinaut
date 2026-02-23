import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitor: Any?
    let popoverViewModel = PopoverViewModel()

    var isPopoverShown: Bool { popover.isShown }

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
    }

    func getCurrentDailyPlan() -> DailyPlan? {
        popoverViewModel.dailyPlan
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        updateIcon(.normal)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .applicationDefined
        popover.animates = true
        let notifManager = AppDelegate.shared?.getNotificationManager()
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover(viewModel: popoverViewModel, notificationManager: notifManager)
        )
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let plannerItem = NSMenuItem(title: "Open Planner...", action: #selector(openPlanner), keyEquivalent: "p")
        plannerItem.target = self
        menu.addItem(plannerItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let scanItem = NSMenuItem(title: "Scan Now", action: #selector(scanNow), keyEquivalent: "")
        scanItem.target = self
        menu.addItem(scanItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ProcrastiNaut", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func updateIcon(_ state: MenuBarIconState) {
        guard let button = statusItem?.button else { return }
        button.image = state.image()
        // If no timer text, just show icon
        if button.title.isEmpty {
            button.imagePosition = .imageOnly
        }
    }

    /// Update the timer countdown text next to the icon
    func updateTimerText(_ text: String?) {
        guard let button = statusItem?.button else { return }
        if let text, !text.isEmpty {
            button.title = " \(text)"
            button.imagePosition = .imageLeading
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.attributedTitle = NSAttributedString(
                string: " \(text)",
                attributes: [.font: font]
            )
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            statusItem?.menu = buildMenu()
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startEventMonitor()
    }

    func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                self.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Menu Actions

    @objc private func openPlanner() {
        AppDelegate.shared?.openPlanner()
    }

    @objc private func openSettings() {
        AppDelegate.shared?.openSettings()
    }

    @objc private func scanNow() {
        showPopover()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
