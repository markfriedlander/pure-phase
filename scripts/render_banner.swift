// Render the README banner — wide aspect (1280×400), warm radial pulse
// on the right, "PURE PHASE" wordmark left-centered with the gradient
// underline bar. Output: banner.png in repo root.

import AppKit
import CoreGraphics
import CoreText
import Foundation

let w: CGFloat = 1280
let h: CGFloat = 400
let outURL = URL(fileURLWithPath: "banner.png")

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(w), height: Int(h),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext") }

// Black background.
ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

// Warm radial pulse on the right side.
let pulseCenter = CGPoint(x: w * 0.74, y: h * 0.5)
let pulseColors: [CGFloat] = [
    0xF5/255, 0xA6/255, 0x23/255, 0.95,
    0xE8/255, 0x59/255, 0x3C/255, 0.65,
    0xC0/255, 0x39/255, 0x2B/255, 0.18,
    0.0,      0.0,      0.0,      0.0
]
let pulseLocs: [CGFloat] = [0, 0.30, 0.65, 1.0]
guard let pulse = CGGradient(colorSpace: cs, colorComponents: pulseColors, locations: pulseLocs, count: 4) else {
    fatalError("gradient")
}
ctx.drawRadialGradient(pulse, startCenter: pulseCenter, startRadius: 0, endCenter: pulseCenter, endRadius: 280, options: [])

// Two atmospheric rings around the pulse.
ctx.setStrokeColor(red: 0xE8/255, green: 0x59/255, blue: 0x3C/255, alpha: 0.35)
ctx.setLineWidth(2)
ctx.strokeEllipse(in: CGRect(x: pulseCenter.x - 240, y: pulseCenter.y - 240, width: 480, height: 480))

ctx.setStrokeColor(red: 0xF5/255, green: 0xA6/255, blue: 0x23/255, alpha: 0.55)
ctx.setLineWidth(4)
ctx.strokeEllipse(in: CGRect(x: pulseCenter.x - 150, y: pulseCenter.y - 150, width: 300, height: 300))

// Gradient underline bar above the wordmark.
let barRect = CGRect(x: 80, y: h - 200, width: 220, height: 2)
let barColors: [CGFloat] = [
    0xF5/255, 0xA6/255, 0x23/255, 1.0,
    0xE8/255, 0x59/255, 0x3C/255, 1.0,
    0xC0/255, 0x39/255, 0x2B/255, 1.0
]
guard let bar = CGGradient(colorSpace: cs, colorComponents: barColors, locations: [0, 0.5, 1.0], count: 3) else {
    fatalError("bar gradient")
}
ctx.saveGState()
ctx.clip(to: barRect)
ctx.drawLinearGradient(bar,
                       start: CGPoint(x: barRect.minX, y: barRect.midY),
                       end: CGPoint(x: barRect.maxX, y: barRect.midY),
                       options: [])
ctx.restoreGState()

// "PURE PHASE" wordmark — bold, wide tracking, white.
let title = "PURE PHASE"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 80, weight: .bold),
    .foregroundColor: NSColor.white,
    .kern: 16
]
let titleLine = CTLineCreateWithAttributedString(NSAttributedString(string: title, attributes: titleAttrs) as CFAttributedString)
ctx.textPosition = CGPoint(x: 80, y: h - 270)
CTLineDraw(titleLine, ctx)

// Subtitle — lowercase, muted, tracked.
let sub = "light · sound · breath"
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .regular),
    .foregroundColor: NSColor(white: 0.55, alpha: 1),
    .kern: 8
]
let subLine = CTLineCreateWithAttributedString(NSAttributedString(string: sub, attributes: subAttrs) as CFAttributedString)
ctx.textPosition = CGPoint(x: 82, y: h - 310)
CTLineDraw(subLine, ctx)

// Output PNG.
guard let cgImage = ctx.makeImage() else { fatalError("makeImage") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode") }
try png.write(to: outURL)
print("Wrote \(outURL.path) — \(png.count) bytes")
