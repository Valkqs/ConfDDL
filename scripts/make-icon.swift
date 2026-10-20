import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(size: Int, name: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale); transform.concat()
    let rect = NSRect(x: 68, y: 68, width: 888, height: 888)
    let background = NSBezierPath(roundedRect: rect, xRadius: 205, yRadius: 205)
    let gradient = NSGradient(starting: NSColor(srgbRed: 0.15, green: 0.58, blue: 0.44, alpha: 1),
                              ending: NSColor(srgbRed: 0.06, green: 0.32, blue: 0.27, alpha: 1))!
    gradient.draw(in: background, angle: -75)
    NSColor.white.withAlphaComponent(0.94).setStroke()
    let frame = NSBezierPath()
    frame.lineWidth = 36; frame.lineCapStyle = .round; frame.lineJoinStyle = .round
    frame.move(to: NSPoint(x: 350, y: 755)); frame.line(to: NSPoint(x: 674, y: 755))
    frame.move(to: NSPoint(x: 350, y: 269)); frame.line(to: NSPoint(x: 674, y: 269))
    frame.move(to: NSPoint(x: 380, y: 745))
    frame.curve(to: NSPoint(x: 475, y: 530), controlPoint1: NSPoint(x: 380, y: 630), controlPoint2: NSPoint(x: 385, y: 610))
    frame.curve(to: NSPoint(x: 475, y: 494), controlPoint1: NSPoint(x: 490, y: 518), controlPoint2: NSPoint(x: 490, y: 506))
    frame.curve(to: NSPoint(x: 380, y: 279), controlPoint1: NSPoint(x: 385, y: 414), controlPoint2: NSPoint(x: 380, y: 394))
    frame.move(to: NSPoint(x: 644, y: 745))
    frame.curve(to: NSPoint(x: 549, y: 530), controlPoint1: NSPoint(x: 644, y: 630), controlPoint2: NSPoint(x: 639, y: 610))
    frame.curve(to: NSPoint(x: 549, y: 494), controlPoint1: NSPoint(x: 534, y: 518), controlPoint2: NSPoint(x: 534, y: 506))
    frame.curve(to: NSPoint(x: 644, y: 279), controlPoint1: NSPoint(x: 639, y: 414), controlPoint2: NSPoint(x: 644, y: 394))
    frame.stroke()
    let sand = NSBezierPath()
    sand.move(to: NSPoint(x: 428, y: 331)); sand.line(to: NSPoint(x: 596, y: 331))
    sand.curve(to: NSPoint(x: 512, y: 425), controlPoint1: NSPoint(x: 584, y: 373), controlPoint2: NSPoint(x: 545, y: 405))
    sand.curve(to: NSPoint(x: 428, y: 331), controlPoint1: NSPoint(x: 479, y: 405), controlPoint2: NSPoint(x: 440, y: 373))
    sand.close(); NSColor(srgbRed: 0.79, green: 0.93, blue: 0.66, alpha: 1).setFill(); sand.fill()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name))
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size, name: "icon_\(size)x\(size).png")
    try drawIcon(size: size * 2, name: "icon_\(size)x\(size)@2x.png")
}
