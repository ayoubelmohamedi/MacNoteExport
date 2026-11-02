import AppKit

func createAppIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let margin = size * 0.08
    let iconRect = rect.insetBy(dx: margin, dy: margin)
    let cornerRadius = size * 0.22
    
    // Background Rounded Rect with Gradient
    let path = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // Gradient: Warm Amber / Note Yellow to Orange
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.28, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.94, green: 0.62, blue: 0.15, alpha: 1.0)
    )
    gradient?.draw(in: path, angle: -45)
    
    // Subtle Inner Shadow / Border
    NSColor(white: 1.0, alpha: 0.25).setStroke()
    path.lineWidth = size * 0.015
    path.stroke()
    
    // Draw Note Pad Sheet
    let padMargin = size * 0.24
    let padRect = NSRect(x: padMargin, y: padMargin + size * 0.04, width: size - 2 * padMargin, height: size - 2 * padMargin)
    let padPath = NSBezierPath(roundedRect: padRect, xRadius: size * 0.05, yRadius: size * 0.05)
    NSColor(white: 1.0, alpha: 0.95).setFill()
    padPath.fill()
    
    // Draw horizontal ruled lines on the sheet
    let lineCount = 4
    let lineSpacing = padRect.height / CGFloat(lineCount + 2)
    NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.85, alpha: 1.0).setStroke()
    
    for i in 1...lineCount {
        let y = padRect.minY + CGFloat(i) * lineSpacing
        let line = NSBezierPath()
        line.lineWidth = size * 0.018
        line.lineCapStyle = .round
        let lineWidth = (i == 1) ? padRect.width * 0.5 : (i == lineCount ? padRect.width * 0.4 : padRect.width * 0.7)
        line.move(to: NSPoint(x: padRect.minX + padRect.width * 0.15, y: y))
        line.line(to: NSPoint(x: padRect.minX + padRect.width * 0.15 + lineWidth, y: y))
        line.stroke()
    }
    
    // Draw Export Arrow Badge (circle with outward arrow in bottom-right)
    let badgeRadius = size * 0.16
    let badgeCenter = NSPoint(x: iconRect.maxX - badgeRadius * 0.9, y: iconRect.minY + badgeRadius * 0.9)
    let badgeRect = NSRect(x: badgeCenter.x - badgeRadius, y: badgeCenter.y - badgeRadius, width: badgeRadius * 2, height: badgeRadius * 2)
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    
    NSColor(calibratedRed: 0.12, green: 0.55, blue: 0.98, alpha: 1.0).setFill()
    badgePath.fill()
    NSColor.white.setStroke()
    badgePath.lineWidth = size * 0.02
    badgePath.stroke()
    
    // Arrow symbol in badge
    let arrowPath = NSBezierPath()
    let aw = badgeRadius * 0.6
    arrowPath.lineWidth = size * 0.022
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    // Line going up-right
    arrowPath.move(to: NSPoint(x: badgeCenter.x - aw * 0.4, y: badgeCenter.y - aw * 0.4))
    arrowPath.line(to: NSPoint(x: badgeCenter.x + aw * 0.4, y: badgeCenter.y + aw * 0.4))
    // Arrow heads
    arrowPath.move(to: NSPoint(x: badgeCenter.x + aw * 0.05, y: badgeCenter.y + aw * 0.4))
    arrowPath.line(to: NSPoint(x: badgeCenter.x + aw * 0.4, y: badgeCenter.y + aw * 0.4))
    arrowPath.line(to: NSPoint(x: badgeCenter.x + aw * 0.4, y: badgeCenter.y + aw * 0.05))
    NSColor.white.setStroke()
    arrowPath.stroke()
    
    img.unlockFocus()
    return img
}

let iconsetPath = "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true, attributes: nil)

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for (pt, scale) in sizes {
    let px = pt * scale
    let img = createAppIcon(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    
    let filename = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
    let fileURL = URL(fileURLWithPath: "\(iconsetPath)/\(filename)")
    try? png.write(to: fileURL)
}

print("Generated iconset PNGs")
