// Exports the app icon set from a 1024×1024 full-bleed render of the icon.
//   swift export.swift <source.png> <AppIcon.appiconset>
// iOS gets the square image as it is, with no alpha channel (iOS rounds the corners itself).
// macOS gets Apple's icon shape drawn in: an 824pt continuous-corner tile centred on a
// 1024pt transparent canvas, with the template's soft shadow.
import AppKit
import SwiftUI

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let image = NSImage(contentsOfFile: arguments[1]),
      let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      source.width == 1024, source.height == 1024 else {
    fatalError("usage: swift export.swift <1024×1024 source.png> <AppIcon.appiconset>")
}
let output = URL(fileURLWithPath: arguments[2])

func makeContext(side: Int, opaque: Bool) -> CGContext {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
    context.interpolationQuality = .high
    return context
}

func write(_ context: CGContext, as name: String) {
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination), "couldn't write \(name)")
    print("wrote", name)
}

let ios = makeContext(side: 1024, opaque: true)
ios.draw(source, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
write(ios, as: "icon-1024.png")

for side in [16, 32, 64, 128, 256, 512, 1024] {
    let scale = CGFloat(side) / 1024
    let tile = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = RoundedRectangle(cornerRadius: 185.4 * scale, style: .continuous).path(in: tile).cgPath
    let mac = makeContext(side: side, opaque: false)
    mac.saveGState()
    mac.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 10 * scale, color: CGColor(gray: 0, alpha: 0.3))
    mac.addPath(shape)
    mac.setFillColor(CGColor(gray: 0.13, alpha: 1))
    mac.fillPath()
    mac.restoreGState()
    mac.addPath(shape)
    mac.clip()
    mac.draw(source, in: tile)
    write(mac, as: "icon-mac-\(side).png")
}
