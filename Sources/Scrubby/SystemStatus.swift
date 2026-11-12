import AppKit
import ApplicationServices
import ServiceManagement

/// Checks for the macOS settings Scrubby depends on, and opens the right panes.
enum SystemStatus {
    // MARK: Accessibility ("Device Control and Data Access" on newer macOS)

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    // MARK: Trackpad gestures that compete with Scrubby

    private static let trackpadDomains = [
        "com.apple.AppleMultitouchTrackpad",                 // built-in trackpad
        "com.apple.driver.AppleBluetoothMultitouch.trackpad", // Magic Trackpad
    ]

    private static func trackpadValue(_ key: String) -> Int {
        trackpadDomains.map { domain -> Int in
            CFPreferencesAppSynchronize(domain as CFString)
            return (CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int) ?? 0
        }.max() ?? 0
    }

    /// True if macOS uses three-finger horizontal swipes itself
    /// ("Swipe between pages" or "Swipe between full-screen applications" set to three fingers).
    static var threeFingerSwipeTakenBySystem: Bool { trackpadValue("TrackpadThreeFingerHorizSwipeGesture") != 0 }

    /// True if macOS uses four-finger horizontal swipes ("Swipe between full-screen applications").
    static var fourFingerSwipeTakenBySystem: Bool { trackpadValue("TrackpadFourFingerHorizSwipeGesture") != 0 }

    static func openTrackpadSettings() {
        open("x-apple.systempreferences:com.apple.Trackpad-Settings.extension")
    }

    // MARK: Launch at login

    static var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    static func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Scrubby: launch-at-login change failed: \(error)")
        }
    }

    private static func open(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}
