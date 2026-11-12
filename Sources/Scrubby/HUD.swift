import AppKit

/// A small, click-through overlay that briefly shows which window was focused.
final class HUD {
    static let shared = HUD()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: blur.leadingAnchor, constant: 22),
            label.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -22),
            label.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
        ])
        panel.contentView = blur
    }

    func show(_ text: String) {
        label.stringValue = text
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        let width = min(max(label.intrinsicContentSize.width + 44, 220), visible.width * 0.6)
        let height: CGFloat = 52
        panel.setFrame(NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2,
                              width: width, height: height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                self?.panel.animator().alphaValue = 0
            }, completionHandler: { self?.panel.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
