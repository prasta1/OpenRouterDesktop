import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        setupStatusItem()

        DispatchQueue.main.async { [weak self] in
            self?.attachWindowDelegate()
        }
    }

    /// Keep the app alive when the user closes the main window — the menu-bar icon brings it back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// When the user re-launches from the Dock with no visible windows, show the window again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    /// Intercept close-button clicks: hide instead of close so we can re-show via the menu-bar icon.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func attachWindowDelegate() {
        guard let window = mainWindow() else { return }
        window.delegate = self
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "bubble.left.and.bubble.right.fill",
                accessibilityDescription: "OpenRouterDesktop"
            )
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let window = mainWindow() else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if window.isVisible && NSApp.isActive {
            window.orderOut(nil)
        } else {
            showMainWindow()
        }
    }

    private func showMainWindow() {
        guard let window = mainWindow() else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Finds the SwiftUI-managed primary window. Filters out auxiliary panels (Settings, popovers).
    private func mainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.canBecomeMain && !window.isExcludedFromWindowsMenu && window.contentViewController != nil
        }
    }
}
