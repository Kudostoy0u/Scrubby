// Draws Scrubby's app icon and writes Resources/AppIcon.icns.
// Run from the repo root:  swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS icon grid: an 824pt rounded square centered in a 1024pt canvas.
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSGradient(colors: [
    NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.13, green: 0.62, blue: 0.98, alpha: 1),
])!.draw(in: shape, angle: -60)
NSGraphicsContext.current?.restoreGraphicsState()

// Three "tabs" along the top, the middle one highlighted.
let tabW: CGFloat = 170, tabH: CGFloat = 70, gap: CGFloat = 26
let tabsX = rect.midX - (3 * tabW + 2 * gap) / 2
for i in 0..<3 {
    let r = NSRect(x: tabsX + CGFloat(i) * (tabW + gap), y: rect.maxY - 200, width: tabW, height: tabH)
    NSColor.white.withAlphaComponent(i == 1 ? 0.95 : 0.35).setFill()
    NSBezierPath(roundedRect: r, xRadius: 22, yRadius: 22).fill()
}

// A hand swiping sideways.
func symbol(_ name: String, pointSize: CGFloat) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}
let hand = symbol("hand.draw.fill", pointSize: 330)
let hs = hand.size
hand.draw(in: NSRect(x: rect.midX - hs.width / 2, y: rect.minY + 90, width: hs.width, height: hs.height))

let arrows = symbol("arrow.left.and.right", pointSize: 120)
let asz = arrows.size
arrows.draw(in: NSRect(x: rect.midX - asz.width / 2, y: rect.maxY - 200 - asz.height - 30,
                       width: asz.width, height: asz.height))

image.unlockFocus()

// Write a 1024 PNG, then let sips + iconutil build the .icns.
let fm = FileManager.default
let iconset = "build/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
try! fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let master = "build/icon-1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: master))

func run(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    try! p.run()
    p.waitUntilExit()
}
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        run(["sips", "-z", "\(px)", "\(px)", master, "--out", "\(iconset)/\(name)"])
    }
}
run(["iconutil", "-c", "icns", iconset, "-o", "Resources/AppIcon.icns"])
run(["sips", "-z", "256", "256", master, "--out", "Resources/icon.png"])   // for the README
print("Wrote Resources/AppIcon.icns and Resources/icon.png")
