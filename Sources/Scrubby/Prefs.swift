import Foundation

/// User preferences, stored in UserDefaults. The engine reads these at the start
/// of every swipe, so changes in Settings apply immediately.
enum Prefs {
    static let d = UserDefaults.standard

    enum Key {
        static let enabled = "enabled"
        static let tabGesture = "tabGestureEnabled"
        static let windowGesture = "windowGestureEnabled"
        static let tabFirst = "tabFirstDistance"
        static let tabStep = "tabStepDistance"
        static let winFirst = "windowFirstDistance"
        static let winStep = "windowStepDistance"
        static let disabledBrowsers = "disabledBrowsers"   // comma-separated bundle IDs
        static let showWindowHUD = "showWindowHUD"
        static let onboarded = "hasOnboarded"
    }

    static let defaults: [String: Any] = [
        Key.enabled: true,
        Key.tabGesture: true,
        Key.windowGesture: true,
        Key.tabFirst: 25.0,
        Key.tabStep: 90.0,
        Key.winFirst: 15.0,
        Key.winStep: 120.0,
        Key.disabledBrowsers: "",
        Key.showWindowHUD: true,
        Key.onboarded: false,
    ]

    static func register() { d.register(defaults: defaults) }

    static var enabled: Bool { d.bool(forKey: Key.enabled) }
    static var tabGesture: Bool { d.bool(forKey: Key.tabGesture) }
    static var windowGesture: Bool { d.bool(forKey: Key.windowGesture) }
    static var tabFirst: Double { d.double(forKey: Key.tabFirst) }
    static var tabStep: Double { d.double(forKey: Key.tabStep) }
    static var winFirst: Double { d.double(forKey: Key.winFirst) }
    static var winStep: Double { d.double(forKey: Key.winStep) }
    static var showWindowHUD: Bool { d.bool(forKey: Key.showWindowHUD) }

    static var disabledBrowsers: Set<String> {
        Set((d.string(forKey: Key.disabledBrowsers) ?? "").split(separator: ",").map(String.init))
    }

    static func setBrowser(_ bundleID: String, enabled: Bool) {
        var set = disabledBrowsers
        if enabled { set.remove(bundleID) } else { set.insert(bundleID) }
        d.set(set.sorted().joined(separator: ","), forKey: Key.disabledBrowsers)
    }
}
