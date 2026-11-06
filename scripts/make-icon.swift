import AppKit

let size = 1024
guard let rep = NSBitmapImageRep(
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
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Unable to create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let accent = NSColor(srgbRed: 15.0 / 255.0, green: 40.0 / 255.0, blue: 47.0 / 255.0, alpha: 1)
let tile = NSRect(x: 48, y: 48, width: 928, height: 928)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 214, yRadius: 214)
accent.setFill()
tilePath.fill()

// Crescent: a large white disc with a shifted disc cut out.
let crescent = NSBezierPath(ovalIn: NSRect(x: 242, y: 250, width: 520, height: 520))
crescent.append(NSBezierPath(ovalIn: NSRect(x: 358, y: 318, width: 430, height: 430)))
crescent.windingRule = .evenOdd
NSColor.white.setFill()
crescent.fill()

// A small four-point star.
let starCenter = NSPoint(x: 714, y: 690)
let star = NSBezierPath()
star.move(to: NSPoint(x: starCenter.x, y: starCenter.y + 82))
star.line(to: NSPoint(x: starCenter.x + 22, y: starCenter.y + 22))
star.line(to: NSPoint(x: starCenter.x + 82, y: starCenter.y))
star.line(to: NSPoint(x: starCenter.x + 22, y: starCenter.y - 22))
star.line(to: NSPoint(x: starCenter.x, y: starCenter.y - 82))
star.line(to: NSPoint(x: starCenter.x - 22, y: starCenter.y - 22))
star.line(to: NSPoint(x: starCenter.x - 82, y: starCenter.y))
star.line(to: NSPoint(x: starCenter.x - 22, y: starCenter.y + 22))
star.close()
NSColor.white.setFill()
star.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
let output = URL(fileURLWithPath: "/tmp/Awqat-1024.png")
try png.write(to: output)
print(output.path)
