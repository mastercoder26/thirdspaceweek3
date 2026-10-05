import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = output.appendingPathComponent("TabDNA.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int, name: String) throws {
    let dimension = CGFloat(size)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    NSColor.white.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: dimension, height: dimension)).fill()
    NSColor.black.setStroke()
    NSColor.black.setFill()

    let points = [
        NSPoint(x: dimension * 0.25, y: dimension * 0.76),
        NSPoint(x: dimension * 0.72, y: dimension * 0.50),
        NSPoint(x: dimension * 0.25, y: dimension * 0.24)
    ]
    let trail = NSBezierPath()
    trail.lineWidth = max(1.5, dimension * 0.075)
    trail.lineCapStyle = .round
    trail.lineJoinStyle = .round
    trail.move(to: points[0])
    trail.line(to: points[1])
    trail.line(to: points[2])
    trail.stroke()

    let radius = max(2.0, dimension * 0.105)
    for point in points {
        NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    let url = iconset.appendingPathComponent(name)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

for (size, name) in [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
] {
    try render(size: size, name: name)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("TabDNA.icns").path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed with exit code \(process.terminationStatus)") }
try FileManager.default.removeItem(at: iconset)
