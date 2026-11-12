import SwiftUI

/// Live status of the things Scrubby needs, refreshed every second while Settings is open.
final class StatusModel: ObservableObject {
    @Published var accessibility = SystemStatus.hasAccessibility
    @Published var engineRunning = GestureEngine.shared.isRunning
    @Published var threeFingerConflict = SystemStatus.threeFingerSwipeTakenBySystem
    @Published var fourFingerConflict = SystemStatus.fourFingerSwipeTakenBySystem
    @Published var launchAtLogin = SystemStatus.launchesAtLogin
    private var timer: Timer?

    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        accessibility = SystemStatus.hasAccessibility
        if accessibility && !GestureEngine.shared.isRunning { GestureEngine.shared.start() }
        engineRunning = GestureEngine.shared.isRunning
        threeFingerConflict = SystemStatus.threeFingerSwipeTakenBySystem
        fourFingerConflict = SystemStatus.fourFingerSwipeTakenBySystem
        launchAtLogin = SystemStatus.launchesAtLogin
    }

    var allGood: Bool { engineRunning && !threeFingerConflict && !fourFingerConflict }
}

struct SettingsView: View {
    @ObservedObject var status: StatusModel

    @AppStorage(Prefs.Key.enabled) private var enabled = true
    @AppStorage(Prefs.Key.tabGesture) private var tabGesture = true
    @AppStorage(Prefs.Key.windowGesture) private var windowGesture = true
    @AppStorage(Prefs.Key.tabFirst) private var tabFirst = 25.0
    @AppStorage(Prefs.Key.tabStep) private var tabStep = 90.0
    @AppStorage(Prefs.Key.winFirst) private var winFirst = 15.0
    @AppStorage(Prefs.Key.winStep) private var winStep = 120.0
    @AppStorage(Prefs.Key.showWindowHUD) private var showHUD = true
    @AppStorage(Prefs.Key.disabledBrowsers) private var disabledBrowsers = ""

    var body: some View {
        Form {
            Section {
                setupRow(
                    ok: status.engineRunning,
                    title: "Allow Scrubby to control your Mac",
                    detail: status.engineRunning
                        ? "Scrubby can read swipes and switch tabs."
                        : "Turn on Scrubby under Privacy & Security → Accessibility (called “Device Control and Data Access” on newer macOS).",
                    button: "Open Settings", action: SystemStatus.requestAccessibility)
                setupRow(
                    ok: !status.threeFingerConflict,
                    title: "Free up three-finger swipes",
                    detail: status.threeFingerConflict
                        ? "macOS is using them. In Trackpad → More Gestures, set “Swipe between pages” to two fingers or off, and make sure “Swipe between full-screen applications” isn’t on three fingers."
                        : "macOS isn’t using sideways three-finger swipes.",
                    button: "Open Trackpad Settings", action: SystemStatus.openTrackpadSettings)
                setupRow(
                    ok: !status.fourFingerConflict,
                    title: "Free up four-finger swipes",
                    detail: status.fourFingerConflict
                        ? "macOS is using them. In Trackpad → More Gestures, turn off “Swipe between full-screen applications”."
                        : "macOS isn’t using sideways four-finger swipes.",
                    button: "Open Trackpad Settings", action: SystemStatus.openTrackpadSettings)
            } header: {
                Text(status.allGood ? "Setup: all done" : "Setup")
            }

            Section("Gestures") {
                Toggle("Scrubby is on", isOn: $enabled)
                Toggle("Three-finger swipe moves through browser tabs", isOn: $tabGesture)
                Toggle("Four-finger swipe moves through windows", isOn: $windowGesture)
                Toggle("Show the window name when switching windows", isOn: $showHUD)
                    .disabled(!windowGesture)
            }

            Section {
                distanceSlider("Distance to the first tab", value: $tabFirst, range: 10...120)
                distanceSlider("Distance to each further tab", value: $tabStep, range: 30...300)
                distanceSlider("Distance to the first window", value: $winFirst, range: 10...120)
                distanceSlider("Distance to each further window", value: $winStep, range: 40...400)
                Button("Reset to defaults") {
                    tabFirst = 25; tabStep = 90; winFirst = 15; winStep = 120
                }
            } header: {
                Text("Sensitivity")
            } footer: {
                Text("Shorter distances switch sooner. A long swipe keeps moving, like dragging a scrollbar.")
            }

            Section("Browsers") {
                let installed = Browser.installed
                if installed.isEmpty {
                    Text("No supported browsers found.").foregroundStyle(.secondary)
                }
                ForEach(installed) { browser in
                    Toggle(browser.name, isOn: Binding(
                        get: { !disabledSet.contains(browser.id) },
                        set: { on in
                            var set = disabledSet
                            if on { set.remove(browser.id) } else { set.insert(browser.id) }
                            disabledBrowsers = set.sorted().joined(separator: ",")
                        }))
                }
            }

            Section("General") {
                Toggle("Open Scrubby when you log in", isOn: Binding(
                    get: { status.launchAtLogin },
                    set: { SystemStatus.setLaunchAtLogin($0); status.refresh() }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
        .onAppear { status.startPolling() }
        .onDisappear { status.stopPolling() }
    }

    private var disabledSet: Set<String> {
        Set(disabledBrowsers.split(separator: ",").map(String.init))
    }

    private func setupRow(ok: Bool, title: String, detail: String, button: String,
                          action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !ok { Button(button, action: action).padding(.top, 2) }
            }
        }
        .padding(.vertical, 2)
    }

    private func distanceSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue))").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
