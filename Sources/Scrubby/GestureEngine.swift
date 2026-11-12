import AppKit
import ApplicationServices

/// Turns multi-finger horizontal trackpad drags into tab and window switches.
///
/// How it works (each point was learned from logging real swipes):
/// - **Finger count** comes from trackpad gesture events' touches. macOS often
///   sends gesture events listing zero touches, even in the middle of a swipe,
///   so a count of 0 is ignored and the last real count is trusted briefly.
/// - **Movement** comes from the smooth horizontal scroll events the trackpad
///   sends during a multi-finger drag. Finger positions were too unreliable.
/// - A swipe's mode (tabs, windows or pass-through) is decided once, when the
///   swipe starts, and kept until the scroll phase ends.
/// - Scroll events of a captured swipe, and the coasting (momentum) events after
///   it, are swallowed so the browser doesn't scroll or go back/forward.
final class GestureEngine {
    static let shared = GestureEngine()

    private(set) var isRunning = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Finger count
    private var lastFingers = 0
    private var lastFingersAt: TimeInterval = 0
    private let fingerMemory: TimeInterval = 0.3

    // Per-swipe state
    private enum Mode { case tabs(Browser), windows }
    private var mode: Mode?
    private var accum = 0.0
    private var steps = 0
    private var blockMomentum = false
    private var flickMode: Mode?   // swipe ended before switching anything; the coast may finish it

    private static let gestureEventType: UInt32 = 29   // NSEvent.EventType.gesture
    private static let phaseBegan: Int64 = 1, phaseEnded: Int64 = 4, phaseCancelled: Int64 = 8

    /// Starts listening. Returns false if macOS refused (usually: no Accessibility permission yet).
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue) | (1 << CGEventMask(Self.gestureEventType))
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        runLoopSource = nil
        isRunning = false
    }

    // MARK: - Event handling

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        // macOS disables taps that are slow or interrupted; turn it straight back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }

        if type.rawValue == Self.gestureEventType {
            noteTouches(event)
            return pass
        }
        if type == .scrollWheel {
            return handleScroll(event) ? nil : pass
        }
        return pass
    }

    private func noteTouches(_ event: CGEvent) {
        guard let ns = NSEvent(cgEvent: event) else { return }
        let n = ns.touches(matching: .touching, in: nil).count
        if n > 0 {   // zero-touch events are noise, not a lift
            lastFingers = n
            lastFingersAt = ProcessInfo.processInfo.systemUptime
        }
    }

    private func fingersNow() -> Int {
        ProcessInfo.processInfo.systemUptime - lastFingersAt < fingerMemory ? lastFingers : 0
    }

    private func resetSwipe() {
        mode = nil
        accum = 0
        steps = 0
    }

    /// Returns true to swallow the event.
    private func handleScroll(_ event: CGEvent) -> Bool {
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)

        if momentum {
            // A quick flick puts most of its distance into the coast after the fingers
            // lift. If the swipe hadn't switched anything yet, let the coast count
            // toward the first switch.
            if let flick = flickMode {
                accum += horizontalDelta(event)
                if abs(accum) >= firstDistance(for: flick) {
                    perform(flick, direction: accum > 0 ? 1 : -1)
                    flickMode = nil
                }
            }
            return blockMomentum
        }
        flickMode = nil
        guard Prefs.enabled else { return false }

        if phase == Self.phaseBegan {
            resetSwipe()
            blockMomentum = false
        }

        // Decide the mode once per swipe, then keep it until the swipe ends.
        if mode == nil {
            let fingers = fingersNow()
            if fingers >= 4, Prefs.windowGesture {
                mode = .windows
            } else if fingers == 3, Prefs.tabGesture, let browser = Browser.frontmostEnabled() {
                mode = .tabs(browser)
            }
        }
        guard let mode else { return false }
        blockMomentum = true

        let dx = horizontalDelta(event)
        let dy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)

        if abs(dx) >= abs(dy) {
            accum += dx
            let first = firstDistance(for: mode)
            let step: Double
            switch mode {
            case .tabs: step = Prefs.tabStep
            case .windows: step = Prefs.winStep
            }

            // One action per distance crossed: a long swipe moves several tabs/windows.
            while abs(accum) >= first + Double(steps) * step {
                steps += 1
                perform(mode, direction: accum > 0 ? 1 : -1)
            }

            // Reversing direction mid-swipe starts counting fresh the other way.
            if steps > 0, (accum > 0 && dx < -2) || (accum < 0 && dx > 2) {
                accum = dx
                steps = 0
            }
        }

        if phase == Self.phaseEnded || phase == Self.phaseCancelled {
            if steps == 0 { flickMode = mode }   // let the coast finish a quick flick
            let keep = accum
            resetSwipe()   // blockMomentum stays on so the coast is swallowed
            if flickMode != nil { accum = keep }
        }
        return true
    }

    /// Horizontal movement, positive when the fingers move right, whatever the
    /// natural-scrolling setting.
    private func horizontalDelta(_ event: CGEvent) -> Double {
        let natural = NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? true
        return event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) * (natural ? 1 : -1)
    }

    private func firstDistance(for mode: Mode) -> Double {
        switch mode {
        case .tabs: return Prefs.tabFirst
        case .windows: return Prefs.winFirst
        }
    }

    private func perform(_ mode: Mode, direction: Int) {
        switch mode {
        case .tabs(let browser): browser.shortcut.send(direction: direction)
        case .windows: WindowSwitcher.cycle(direction: direction)
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<GestureEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
}
