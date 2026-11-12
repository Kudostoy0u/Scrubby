import AppKit
import ApplicationServices

/// Cycles focus through the standard windows on the current Space, in a stable order.
enum WindowSwitcher {
    private struct Candidate {
        let windowID: CGWindowID
        let pid: pid_t
        let element: AXUIElement
        let appName: String
        let title: String
    }

    static func cycle(direction: Int) {
        let windows = candidates()
        guard windows.count >= 2 else { return }

        // The first on-screen window of the frontmost app is the focused one.
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let ordered = onScreenWindowInfo()
        let focusedID = ordered.first { $0.pid == frontPID }?.id

        let sorted = windows.sorted { $0.windowID < $1.windowID }
        let index = sorted.firstIndex { $0.windowID == focusedID } ?? 0
        let target = sorted[((index + direction) % sorted.count + sorted.count) % sorted.count]
        focus(target)

        if Prefs.showWindowHUD {
            HUD.shared.show(target.title.isEmpty ? target.appName : "\(target.appName)  —  \(target.title)")
        }
    }

    private static func focus(_ w: Candidate) {
        let app = AXUIElementCreateApplication(w.pid)
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(w.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(w.element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: w.pid)?.activate()
    }

    // MARK: - Window discovery

    private struct CGInfo { let id: CGWindowID; let pid: pid_t; let bounds: CGRect }

    /// Normal (layer 0) on-screen windows, front to back.
    private static func onScreenWindowInfo() -> [CGInfo] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 50, bounds.height > 50,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { return nil }
            return CGInfo(id: id, pid: pid, bounds: bounds)
        }
    }

    /// On-screen windows matched to their Accessibility elements; only standard windows are kept.
    private static func candidates() -> [Candidate] {
        var axCache: [pid_t: [AXUIElement]] = [:]
        var used = Set<CFHashCode>()
        var result: [Candidate] = []

        for info in onScreenWindowInfo() {
            let axWindows = axCache[info.pid] ?? {
                let list = axWindowsOf(pid: info.pid)
                axCache[info.pid] = list
                return list
            }()
            guard let match = axWindows.first(where: { el in
                !used.contains(CFHash(el)) && frameMatches(el, info.bounds) && isStandard(el)
            }) else { continue }
            used.insert(CFHash(match))

            let appName = NSRunningApplication(processIdentifier: info.pid)?.localizedName ?? ""
            let title = stringAttr(match, kAXTitleAttribute) ?? ""
            result.append(Candidate(windowID: info.id, pid: info.pid, element: match, appName: appName, title: title))
        }
        return result
    }

    private static func axWindowsOf(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func isStandard(_ el: AXUIElement) -> Bool {
        stringAttr(el, kAXSubroleAttribute) == (kAXStandardWindowSubrole as String)
    }

    private static func frameMatches(_ el: AXUIElement, _ bounds: CGRect) -> Bool {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return false }
        var pos = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return abs(pos.x - bounds.minX) < 2 && abs(pos.y - bounds.minY) < 2
            && abs(size.width - bounds.width) < 2 && abs(size.height - bounds.height) < 2
    }

    private static func stringAttr(_ el: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
