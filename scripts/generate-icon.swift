#!/usr/bin/env swift

import AppKit
import CoreGraphics

/// Generates a macOS app icon with a gear/automation design.
func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.05
    let roundedRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = size * 0.22

    // Background: dark gradient
    let bgPath = CGPath(roundedRect: roundedRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0),
    ]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size),
                                   end: CGPoint(x: size, y: 0),
                                   options: [])
    }

    let center = CGPoint(x: size / 2, y: size / 2)

    // Large gear
    drawGear(context: context, center: CGPoint(x: center.x - size * 0.08, y: center.y + size * 0.05),
             outerRadius: size * 0.28, innerRadius: size * 0.18, teeth: 8, toothDepth: size * 0.06,
             color: CGColor(red: 0.49, green: 0.34, blue: 0.99, alpha: 0.9))

    // Small gear (interlocking)
    drawGear(context: context, center: CGPoint(x: center.x + size * 0.2, y: center.y - size * 0.18),
             outerRadius: size * 0.16, innerRadius: size * 0.10, teeth: 6, toothDepth: size * 0.04,
             color: CGColor(red: 0.45, green: 0.87, blue: 0.62, alpha: 0.9))

    // Play triangle (run indicator) in the center of the large gear
    let triCenter = CGPoint(x: center.x - size * 0.05, y: center.y + size * 0.05)
    let triSize = size * 0.10
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    context.move(to: CGPoint(x: triCenter.x - triSize * 0.4, y: triCenter.y - triSize * 0.5))
    context.addLine(to: CGPoint(x: triCenter.x - triSize * 0.4, y: triCenter.y + triSize * 0.5))
    context.addLine(to: CGPoint(x: triCenter.x + triSize * 0.6, y: triCenter.y))
    context.closePath()
    context.fillPath()

    // Subtle connection lines between gears
    context.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 0.3))
    context.setLineWidth(size * 0.008)
    context.setLineDash(phase: 0, lengths: [size * 0.02, size * 0.015])

    // Bottom decorative dots (step indicators)
    let dotY = center.y - size * 0.32
    let dotSpacing = size * 0.08
    let dotRadius = size * 0.018
    let dotColors: [CGColor] = [
        CGColor(red: 0.45, green: 0.87, blue: 0.62, alpha: 0.9), // green
        CGColor(red: 0.45, green: 0.87, blue: 0.62, alpha: 0.9), // green
        CGColor(red: 0.49, green: 0.34, blue: 0.99, alpha: 0.9), // purple (running)
        CGColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 0.5),    // gray (pending)
    ]

    for (i, color) in dotColors.enumerated() {
        let dotX = center.x - dotSpacing * 1.5 + CGFloat(i) * dotSpacing
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(x: dotX - dotRadius, y: dotY - dotRadius,
                                        width: dotRadius * 2, height: dotRadius * 2))
    }

    image.unlockFocus()
    return image
}

func drawGear(context: CGContext, center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat,
              teeth: Int, toothDepth: CGFloat, color: CGColor) {
    context.saveGState()

    let path = CGMutablePath()
    let angleStep = CGFloat.pi * 2 / CGFloat(teeth * 2)

    for i in 0..<(teeth * 2) {
        let angle = CGFloat(i) * angleStep - CGFloat.pi / 2
        let radius = (i % 2 == 0) ? outerRadius : outerRadius - toothDepth
        let point = CGPoint(x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius)
        if i == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()

    // Gear body
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()

    // Center hole
    context.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: center.x - innerRadius * 0.4, y: center.y - innerRadius * 0.4,
                                    width: innerRadius * 0.8, height: innerRadius * 0.8))

    context.restoreGState()
}

// Generate all required icon sizes
let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

// Create iconset directory
let iconsetPath = "AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = renderIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let path = "\(iconsetPath)/\(name).png"
    try! pngData.write(to: URL(fileURLWithPath: path))
    print("Generated \(path) (\(Int(size))x\(Int(size)))")
}

print("\nConverting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Created AppIcon.icns")
} else {
    print("iconutil failed")
}

// Clean up iconset
try? fm.removeItem(atPath: iconsetPath)
