#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("CodexProfiles/Assets.xcassets/AppIcon.appiconset")
let menuSetURL = root.appendingPathComponent("CodexProfiles/Assets.xcassets/MenuBarIcon.imageset")
let resourcesURL = root.appendingPathComponent("CodexProfiles/Resources")
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

// MARK: - The mark
//
// Two offset profile cards: the front card is the account you are signed in to,
// the card tucked behind it is the next one you switch to. Drawing the mark in
// code keeps the app icon and the menu-bar glyph in sync and needs no artwork.

let codexTeal = NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.65, alpha: 1)
let codexIndigo = NSColor(calibratedRed: 0.25, green: 0.30, blue: 0.90, alpha: 1)

func rgbaRep(from image: NSImage, size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: size * 4,
        bitsPerPixel: 32
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    NSColor.clear.setFill()
    ctx.cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func pngData(_ image: NSImage, size: Int) -> Data {
    let rep = rgbaRep(from: image, size: size)
    return rep.representation(using: .png, properties: [:])!
}

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func fill(rounded rect: NSRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

/// Draws the mark centred in a square.
///
/// - `cardRatio`/`offsetRatio` set how far the back card peeks out.
/// - `gapRatio` cuts a real gap around the front card (clear compositing). The
///   menu-bar template uses it so the two cards stay distinct at 22 px, where an
///   alpha difference alone would blur into one blob.
func drawProfileStack(
    center: NSPoint,
    box: CGFloat,
    cardRatio: CGFloat,
    offsetRatio: CGFloat,
    gapRatio: CGFloat,
    front: NSColor,
    back: NSColor,
    shadow: Bool
) {
    let cardW = box * cardRatio
    let radius = cardW * 0.26
    let offset = box * offsetRatio
    let span = cardW + offset
    let origin = NSPoint(x: center.x - span / 2, y: center.y - span / 2)
    let frontRect = NSRect(x: origin.x, y: origin.y, width: cardW, height: cardW)

    fill(
        rounded: NSRect(x: origin.x + offset, y: origin.y + offset, width: cardW, height: cardW),
        radius: radius,
        color: back
    )

    if gapRatio > 0 {
        let gap = box * gapRatio
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.black.setStroke()
        let ring = NSBezierPath(
            roundedRect: frontRect.insetBy(dx: -gap / 2, dy: -gap / 2),
            xRadius: radius + gap / 2,
            yRadius: radius + gap / 2
        )
        ring.lineWidth = gap
        ring.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.saveGraphicsState()
    if shadow {
        let drop = NSShadow()
        drop.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.22)
        drop.shadowBlurRadius = box * 0.09
        drop.shadowOffset = NSSize(width: 0, height: -box * 0.035)
        drop.set()
    }
    fill(rounded: frontRect, radius: radius, color: front)
    NSGraphicsContext.restoreGraphicsState()
}
func appIconImage(pixelSize: Int, boxRatio: CGFloat = 0.56) -> NSImage {
    let s = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    NSColor.clear.setFill()
    rect.fill()

    let radius = s * 0.223
    let plate = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    plate.addClip()
    if let gradient = NSGradient(colors: [codexTeal, codexIndigo]) {
        gradient.draw(in: plate, angle: -55)
    }

    // A soft sheen across the top so the plate does not read as flat colour.
    NSGraphicsContext.saveGraphicsState()
    plate.addClip()
    let sheen = NSBezierPath(ovalIn: NSRect(x: -s * 0.3, y: s * 0.34, width: s * 1.6, height: s * 1.0))
    if let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.26),
        NSColor.white.withAlphaComponent(0),
    ]) {
        glow.draw(in: sheen, angle: -90)
    }
    NSGraphicsContext.restoreGraphicsState()

    drawProfileStack(
        center: NSPoint(x: s * 0.5, y: s * 0.5),
        box: s * boxRatio,
        cardRatio: 0.62,
        offsetRatio: 0.20,
        gapRatio: 0,
        front: .white,
        back: NSColor.white.withAlphaComponent(0.52),
        shadow: true
    )

    NSColor.white.withAlphaComponent(0.30).setStroke()
    plate.lineWidth = s * 0.006
    plate.stroke()

    image.unlockFocus()
    return image
}

/// The menu-bar variant is a template image: only its alpha matters. A real gap
/// between the cards is what keeps the shape readable at 22 px.
func menuBarImage(
    pixelSize: Int,
    cardRatio: CGFloat = 0.60,
    offsetRatio: CGFloat = 0.24,
    boxRatio: CGFloat = 0.84,
    backAlpha: CGFloat = 1.0,
    gapRatio: CGFloat = 0.055
) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()
    let s = CGFloat(pixelSize)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()
    drawProfileStack(
        center: NSPoint(x: s * 0.5, y: s * 0.5),
        box: s * boxRatio,
        cardRatio: cardRatio,
        offsetRatio: offsetRatio,
        gapRatio: gapRatio,
        front: .black,
        back: NSColor.black.withAlphaComponent(backAlpha),
        shadow: false
    )
    image.unlockFocus()
    image.isTemplate = true
    return image
}

let master = appIconImage(pixelSize: 1024)

try ensureDir(iconsetURL)
try ensureDir(resourcesURL)
let workingIconset = root.appendingPathComponent("Design/AppIcon.iconset")
try ensureDir(workingIconset)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    let data = pngData(master, size: px)
    try data.write(to: iconsetURL.appendingPathComponent("\(name).png"))
    try data.write(to: workingIconset.appendingPathComponent("\(name).png"))
}

let catalog = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try catalog.write(to: iconsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", icnsURL.path, workingIconset.path]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
try ensureDir(menuSetURL)
let menu1x = pngData(menuBarImage(pixelSize: 22), size: 22)
let menu2x = pngData(menuBarImage(pixelSize: 44), size: 44)
try menu1x.write(to: menuSetURL.appendingPathComponent("MenuBarIcon.png"))
try menu2x.write(to: menuSetURL.appendingPathComponent("MenuBarIcon@2x.png"))
try menu1x.write(to: resourcesURL.appendingPathComponent("MenuBarIcon.png"))
try menu2x.write(to: resourcesURL.appendingPathComponent("MenuBarIcon@2x.png"))

let menuCatalog = """
{
  "images" : [
    { "filename" : "MenuBarIcon.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "MenuBarIcon@2x.png", "idiom" : "universal", "scale" : "2x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}
"""
try menuCatalog.write(to: menuSetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("Wrote \(icnsURL.path)")
print("Wrote AppIcon.appiconset and MenuBarIcon.imageset")