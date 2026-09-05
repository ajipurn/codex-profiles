#!/usr/bin/env swift
import AppKit
import Foundation
import QuartzCore

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Design/app-icon-source-isometric.png")
let iconsetURL = root.appendingPathComponent("CodexProfiles/Assets.xcassets/AppIcon.appiconset")
let menuSetURL = root.appendingPathComponent("CodexProfiles/Assets.xcassets/MenuBarIcon.imageset")
let resourcesURL = root.appendingPathComponent("CodexProfiles/Resources")
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

guard let source = NSImage(contentsOf: sourceURL) else {
    fputs("missing \(sourceURL.path)\n", stderr)
    exit(1)
}

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

func floodClearBackground(_ rep: NSBitmapImageRep, threshold: Int = 28) {
    let w = rep.pixelsWide
    let h = rep.pixelsHigh
    guard let data = rep.bitmapData else { return }
    let row = rep.bytesPerRow
    func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
        let o = y * row + x * 4
        return (Int(data[o]), Int(data[o + 1]), Int(data[o + 2]), Int(data[o + 3]))
    }
    func setAlpha(_ x: Int, _ y: Int, _ a: UInt8) {
        data[y * row + x * 4 + 3] = a
    }
    let corners = [pixel(0, 0), pixel(w - 1, 0), pixel(0, h - 1), pixel(w - 1, h - 1)]
    let seed = corners[0]
    let isBackdrop = corners.allSatisfy { p in
        abs(p.0 - seed.0) < threshold && abs(p.1 - seed.1) < threshold && abs(p.2 - seed.2) < threshold
    }
    let seedLuma = (seed.0 + seed.1 + seed.2) / 3
    guard isBackdrop, seedLuma > 210 || seedLuma < 18 else { return }

    var seen = [Bool](repeating: false, count: w * h)
    var queue: [(Int, Int)] = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while let (x, y) = queue.popLast() {
        if x < 0 || y < 0 || x >= w || y >= h { continue }
        let i = y * w + x
        if seen[i] { continue }
        seen[i] = true
        let p = pixel(x, y)
        let close = abs(p.0 - seed.0) < threshold && abs(p.1 - seed.1) < threshold && abs(p.2 - seed.2) < threshold
        guard close else { continue }
        setAlpha(x, y, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))
    }
}

func clearNeutralBackdrop(_ rep: NSBitmapImageRep) {
    let w = rep.pixelsWide
    let h = rep.pixelsHigh
    guard let data = rep.bitmapData else { return }
    let row = rep.bytesPerRow

    for y in 0..<h {
        for x in 0..<w {
            let offset = y * row + x * 4
            let red = Int(data[offset])
            let green = Int(data[offset + 1])
            let blue = Int(data[offset + 2])
            let chroma = max(red, green, blue) - min(red, green, blue)
            let luma = (red + green + blue) / 3

            // Image generators sometimes render their transparency preview into
            // enclosed negative spaces. The logo itself is saturated blue/teal,
            // so removing near-neutral light pixels is safe and deterministic.
            if luma > 222, chroma < 18 {
                data[offset + 3] = 0
            }
        }
    }
}

func composeAppIcon(_ foreground: NSImage, size: CGFloat) -> NSImage {
    let output = NSImage(size: NSSize(width: size, height: size))
    output.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    let radius = size * 0.223
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.86, green: 0.94, blue: 1.00, alpha: 1),
    ])!
    background.draw(in: path, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.02, alpha: 0.26)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.set()
    let inset = size * 0.105
    foreground.draw(
        in: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.72).setStroke()
    path.lineWidth = size * 0.006
    path.stroke()
    output.unlockFocus()
    return output
}

func croppedToOpaque(_ rep: NSBitmapImageRep, size: Int) -> NSImage {
    let w = rep.pixelsWide
    let h = rep.pixelsHigh
    var minX = w, minY = h, maxX = 0, maxY = 0
    for y in 0..<h {
        for x in 0..<w {
            guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.08 else { continue }
            let r = Int(color.redComponent * 255)
            let g = Int(color.greenComponent * 255)
            let b = Int(color.blueComponent * 255)
            let chroma = max(r, g, b) - min(r, g, b)
            // Keep the indigo/teal fill; drop the white bezel around the original squircle.
            guard chroma > 18 else { continue }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    if maxX > minX {
        let pad = 1
        minX = max(0, minX - pad)
        minY = max(0, minY - pad)
        maxX = min(w - 1, maxX + pad)
        maxY = min(h - 1, maxY + pad)
    }

    let out = NSBitmapImageRep(
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
    let ctx = NSGraphicsContext(bitmapImageRep: out)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    NSColor.clear.setFill()
    ctx.cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
    if maxX > minX, maxY > minY, let cg = rep.cgImage {
        let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        if let piece = cg.cropping(to: crop) {
            ctx.cgContext.interpolationQuality = .high
            ctx.cgContext.draw(piece, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    let result = NSImage(size: NSSize(width: size, height: size))
    result.addRepresentation(out)
    return result
}

func pngData(_ image: NSImage, size: Int) -> Data {
    let rep = rgbaRep(from: image, size: size)
    return rep.representation(using: .png, properties: [:])!
}

func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

let masterRep = rgbaRep(from: source, size: 1024)
floodClearBackground(masterRep)
clearNeutralBackdrop(masterRep)
let unmasked = croppedToOpaque(masterRep, size: 1024)
let master = composeAppIcon(unmasked, size: 1024)

try ensureDir(iconsetURL)
try ensureDir(resourcesURL)
let workingIconset = root.appendingPathComponent("Design/AppIcon.iconset")
try? FileManager.default.removeItem(at: workingIconset)
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

func point(center: NSPoint, radius: CGFloat, angle: CGFloat) -> NSPoint {
    let radians = angle * .pi / 180
    return NSPoint(
        x: center.x + cos(radians) * radius,
        y: center.y + sin(radians) * radius
    )
}

func drawArrowhead(tip: NSPoint, direction: CGFloat, size: CGFloat) {
    let radians = direction * .pi / 180
    let path = NSBezierPath()
    path.move(to: tip)
    path.line(to: NSPoint(
        x: tip.x - cos(radians - 0.68) * size,
        y: tip.y - sin(radians - 0.68) * size
    ))
    path.line(to: NSPoint(
        x: tip.x - cos(radians + 0.68) * size,
        y: tip.y - sin(radians + 0.68) * size
    ))
    path.close()
    path.fill()
}

func drawCodexSwitchMark(center: NSPoint, size: CGFloat) {
    let arrowRadius = size * 0.40
    let arrowWidth = max(1.6, size * 0.085)
    let arrowSize = size * 0.17

    let top = NSBezierPath()
    top.lineWidth = arrowWidth
    top.lineCapStyle = .round
    top.appendArc(
        withCenter: center,
        radius: arrowRadius,
        startAngle: 160,
        endAngle: 20,
        clockwise: true
    )
    top.stroke()
    drawArrowhead(
        tip: point(center: center, radius: arrowRadius, angle: 20),
        direction: -70,
        size: arrowSize
    )

    let bottom = NSBezierPath()
    bottom.lineWidth = arrowWidth
    bottom.lineCapStyle = .round
    bottom.appendArc(
        withCenter: center,
        radius: arrowRadius,
        startAngle: 340,
        endAngle: 200,
        clockwise: true
    )
    bottom.stroke()
    drawArrowhead(
        tip: point(center: center, radius: arrowRadius, angle: 200),
        direction: 110,
        size: arrowSize
    )

    // A compact six-sided AI node with a terminal chevron. It echoes the app
    // icon without reproducing a third-party brand mark at menu-bar scale.
    let nodeRadius = size * 0.225
    let node = NSBezierPath()
    for index in 0..<6 {
        let vertex = point(center: center, radius: nodeRadius, angle: CGFloat(index * 60 + 30))
        if index == 0 { node.move(to: vertex) } else { node.line(to: vertex) }
    }
    node.close()
    node.lineWidth = max(1.7, size * 0.105)
    node.lineJoinStyle = .round
    node.stroke()

    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: center.x - size * 0.055, y: center.y + size * 0.075))
    chevron.line(to: NSPoint(x: center.x + size * 0.045, y: center.y))
    chevron.line(to: NSPoint(x: center.x - size * 0.055, y: center.y - size * 0.075))
    chevron.lineWidth = max(1.2, size * 0.065)
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.stroke()
}

func menuBarImage(pixelSize: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
    let s = CGFloat(pixelSize)
    NSColor.black.setStroke()
    NSColor.black.setFill()
    drawCodexSwitchMark(center: NSPoint(x: s * 0.50, y: s * 0.50), size: s)
    image.unlockFocus()
    image.isTemplate = true
    return image
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
