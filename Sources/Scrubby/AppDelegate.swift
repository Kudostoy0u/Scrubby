import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let status = StatusModel()
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        setUpMenuBar()

        if !GestureEngine.shared.start() {
            // No permission yet: keep trying quietly until it's granted.
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                if GestureEngine.shared.start() {
                    timer.invalidate()
                    self?.retryTimer = nil
                    self?.updateIcon()
                }
            }
        }
        updateIcon()

        let needsSetup = !GestureEngine.shared.isRunning
            || SystemStatus.threeFingerSwipeTakenBySystem
            || SystemStatus.fourFingerSwipeTakenBySystem
        if !Prefs.d.bool(forKey: Prefs.Key.onboarded) || needsSetup {
            Prefs.d.set(true, forKey: Prefs.Key.onboarded)
            if !GestureEngine.shared.isRunning { SystemStatus.requestAccessibility() }
            showSettings()
        }
    }

    /// Opening Scrubby again from Finder or Spotlight shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: Menu bar

    private func setUpMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateIcon() {
        let symbol = !GestureEngine.shared.isRunning ? "exclamationmark.triangle"
            : Prefs.enabled ? "hand.draw" : "hand.raised.slash"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Scrubby")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let state: String
        if !GestureEngine.shared.isRunning { state = "Needs permission — open Settings" }
        else if !Prefs.enabled { state = "Paused" }
        else { state = "Active" }
        let header = NSMenuItem(title: "Scrubby: \(state)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: Prefs.enabled ? "Pause Scrubby" : "Resume Scrubby",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Scrubby", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func toggleEnabled() {
        Prefs.d.set(!Prefs.enabled, forKey: Prefs.Key.enabled)
        updateIcon()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Scrubby"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(status: status))
            window.center()
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in self?.updateIcon() }
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
