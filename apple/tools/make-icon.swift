import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Usage: swift tools/make-icon.swift <output.png>
// Draws the Frets 2 Keys app icon: guitar strings with colored note markers above a strip of piano keys.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let s = CGFloat(size)
// CoreGraphics origin is bottom-left.
let gradient = CGGradient(colorsSpace: space, colors: [rgb(0x27272A), rgb(0x18181B)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Fretboard area (top half).
let left: CGFloat = 120, right: CGFloat = s - 120
let stringYs: [CGFloat] = [800, 720, 640, 560]
ctx.setFillColor(rgb(0xF59E0B))
ctx.fill(CGRect(x: 230, y: 520, width: 14, height: 320)) // nut / capo line
for x in stride(from: 430 as CGFloat, through: 830, by: 200) {
    ctx.setFillColor(rgb(0x52525B))
    ctx.fill(CGRect(x: x, y: 520, width: 6, height: 320))
}
for (i, y) in stringYs.enumerated() {
    ctx.setFillColor(rgb(0xA1A1AA))
    ctx.fill(CGRect(x: left, y: y - CGFloat(3 + i), width: right - left, height: CGFloat(6 + 2 * i)))
}
// Selected notes, using the app's scale-degree colors (C major chord shape).
let dots: [(CGFloat, CGFloat, UInt32)] = [(335, 720, 0xEF4444), (535, 640, 0xCA8A04), (735, 560, 0x0891B2), (535, 800, 0xEF4444)]
for (x, y, color) in dots {
    let r: CGFloat = 46
    let rect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
    ctx.setFillColor(rgb(color))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.fillPath()
}

// Piano keys (bottom).
let keyTop: CGFloat = 430, keyBottom: CGFloat = 120
let whiteCount = 7
let keyWidth = (right - left) / CGFloat(whiteCount)
for i in 0..<whiteCount {
    let rect = CGRect(x: left + CGFloat(i) * keyWidth + 4, y: keyBottom, width: keyWidth - 8, height: keyTop - keyBottom)
    ctx.setFillColor(i == 0 || i == 2 || i == 4 ? rgb(0xFFFFFF) : rgb(0xF4F4F5))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.fillPath()
}
// Highlight C, E, G with matching colors.
for (i, color) in [(0, 0xEF4444), (2, 0xCA8A04), (4, 0x0891B2)] as [(Int, UInt32)] {
    let r: CGFloat = 30
    let cx = left + CGFloat(i) * keyWidth + keyWidth / 2
    ctx.setFillColor(rgb(color))
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx - r, y: keyBottom + 30, width: 2 * r, height: 2 * r), cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()
}
for i in [1, 2, 4, 5, 6] {
    let x = left + CGFloat(i) * keyWidth - keyWidth * 0.32
    ctx.setFillColor(rgb(0x3F3F46))
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: keyTop - 180, width: keyWidth * 0.64, height: 180), cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.fillPath()
}

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
