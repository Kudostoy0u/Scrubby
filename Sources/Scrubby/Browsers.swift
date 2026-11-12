import AppKit

/// How a browser switches to the next/previous tab. Arrow keys and Tab are used
/// rather than [ and ] because their key codes are the same on every keyboard layout.
enum TabShortcut {
    case cmdOptionArrows   // ⌘⌥← / ⌘⌥→ : Chromium browsers, Firefox
    case controlTab        // ⌃⇧⇥ / ⌃⇥  : Safari

    func send(direction: Int) {
        switch self {
        case .cmdOptionArrows:
            Keys.press(direction > 0 ? Keys.rightArrow : Keys.leftArrow,
                       flags: [.maskCommand, .maskAlternate])
        case .controlTab:
            Keys.press(Keys.tab, flags: direction > 0 ? [.maskControl] : [.maskControl, .maskShift])
        }
    }
}

struct Browser: Identifiable, Hashable {
    let id: String       // bundle identifier
    let name: String
    let shortcut: TabShortcut

    static let known: [Browser] = [
        Browser(id: "com.brave.Browser", name: "Brave", shortcut: .cmdOptionArrows),
        Browser(id: "com.google.Chrome", name: "Google Chrome", shortcut: .cmdOptionArrows),
        Browser(id: "com.google.Chrome.canary", name: "Chrome Canary", shortcut: .cmdOptionArrows),
        Browser(id: "org.chromium.Chromium", name: "Chromium", shortcut: .cmdOptionArrows),
        Browser(id: "company.thebrowser.Browser", name: "Arc", shortcut: .cmdOptionArrows),
        Browser(id: "company.thebrowser.dia", name: "Dia", shortcut: .cmdOptionArrows),
        Browser(id: "com.microsoft.edgemac", name: "Microsoft Edge", shortcut: .cmdOptionArrows),
        Browser(id: "com.vivaldi.Vivaldi", name: "Vivaldi", shortcut: .cmdOptionArrows),
        Browser(id: "com.operasoftware.Opera", name: "Opera", shortcut: .cmdOptionArrows),
        Browser(id: "org.mozilla.firefox", name: "Firefox", shortcut: .cmdOptionArrows),
        Browser(id: "org.mozilla.firefoxdeveloperedition", name: "Firefox Developer Edition", shortcut: .cmdOptionArrows),
        Browser(id: "app.zen-browser.zen", name: "Zen", shortcut: .cmdOptionArrows),
        Browser(id: "com.apple.Safari", name: "Safari", shortcut: .controlTab),
        Browser(id: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview", shortcut: .controlTab),
    ]

    static let byID: [String: Browser] = Dictionary(uniqueKeysWithValues: known.map { ($0.id, $0) })

    static var installed: [Browser] {
        known.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil }
    }

    /// The frontmost app, if it is a browser Scrubby is enabled for.
    static func frontmostEnabled() -> Browser? {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let browser = byID[id],
              !Prefs.disabledBrowsers.contains(id) else { return nil }
        return browser
    }
}

enum Keys {
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let tab: CGKeyCode = 48

    static func press(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }
    }
}
