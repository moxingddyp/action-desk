import AppKit

// Original vector artwork. Generate the asset catalog without external images.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let colors: [NSColor] = [
    .init(srgbRed: 0.25, green: 0.69, blue: 0.98, alpha: 1),
    .init(srgbRed: 0.27, green: 0.82, blue: 0.67, alpha: 1),
    .init(srgbRed: 1.00, green: 0.83, blue: 0.26, alpha: 1),
    .init(srgbRed: 1.00, green: 0.45, blue: 0.48, alpha: 1),
    .init(srgbRed: 0.72, green: 0.63, blue: 0.96, alpha: 1)
]
func draw(_ size: Int) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 204, yRadius: 204)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 1).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    let centre = NSPoint(x: 512, y: 512)
    for i in 0..<5 {
        let start = CGFloat(90 - i * 72), end = start - 72
        let segment = NSBezierPath()
        segment.appendArc(withCenter: centre, radius: 328, startAngle: start, endAngle: end, clockwise: true)
        segment.appendArc(withCenter: centre, radius: 210, startAngle: end, endAngle: start, clockwise: false)
        segment.close(); colors[i].setFill(); segment.fill()
    }
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 422, y: 510)); mark.line(to: NSPoint(x: 486, y: 449)); mark.line(to: NSPoint(x: 610, y: 581))
    mark.lineWidth = 42; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
    NSColor(srgbRed: 0.18, green: 0.25, blue: 0.36, alpha: 1).setStroke(); mark.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon-\(size).png"))
}
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes { try draw(size) }
let entries: [[String: Any]] = [16, 32, 128, 256, 512].flatMap { size in
    [1, 2].map { scale in ["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": "icon-\(size * scale).png"] }
}
let manifest: [String: Any] = ["images": entries, "info": ["author": "moxingddyp", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
