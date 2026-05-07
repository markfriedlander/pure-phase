// One-shot Swift script to render the NeuroLight app icon at 1024×1024.
// Output is a square PNG with no rounded corners (Apple rounds at display).
//
// Run:  swift scripts/render_icon.swift
// Output: NeuroLight/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import AppKit
import CoreGraphics
import CoreText
import Foundation

let size: CGFloat = 1024
let outURL = URL(fileURLWithPath: "NeuroLight/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext") }

// 1. Background — pure black, no rounded corners.
ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let center = CGPoint(x: size / 2, y: size / 2)

// 2. Radial gradient pulse — amber → red → black, fading at edge.
let pulseColors: [CGFloat] = [
    0xF5/255, 0xA6/255, 0x23/255, 0.95,   // amber
    0xE8/255, 0x59/255, 0x3C/255, 0.70,   // burnt orange
    0xC0/255, 0x39/255, 0x2B/255, 0.25,   // brick red
    0.0,      0.0,      0.0,      0.0     // transparent black
]
let pulseLocations: [CGFloat] = [0.0, 0.30, 0.65, 1.0]
guard let pulseGradient = CGGradient(
    colorSpace: cs,
    colorComponents: pulseColors,
    locations: pulseLocations,
    count: 4
) else { fatalError("gradient") }
// All radii / sizes scaled ~1.45× from Strategic Claude's original SVG
// so the visual mass fills ~85% of the 1024² icon per Apple HIG, instead
// of ~65% which Mark correctly called out as too tiny.
ctx.drawRadialGradient(
    pulseGradient,
    startCenter: center, startRadius: 0,
    endCenter: center, endRadius: 470,
    options: []
)

// 3. Outer faint ring — burnt orange at low opacity.
ctx.setStrokeColor(red: 0xE8/255, green: 0x59/255, blue: 0x3C/255, alpha: 0.5)
ctx.setLineWidth(6)
ctx.strokeEllipse(in: CGRect(
    x: center.x - 432, y: center.y - 432,
    width: 864, height: 864
))

// 4. Middle bright ring — amber, the prominent halo.
ctx.setStrokeColor(red: 0xF5/255, green: 0xA6/255, blue: 0x23/255, alpha: 0.8)
ctx.setLineWidth(13)
ctx.strokeEllipse(in: CGRect(
    x: center.x - 290, y: center.y - 290,
    width: 580, height: 580
))

// Innermost ring removed (was the boundary for the old NL letterform).
// With no text inside, leaving it would read as a leftover. The bright
// center of the radial pulse now carries the focal weight.

// No text. The pulse + two rings is the entire mark.

// 7. Output as PNG.
guard let cgImage = ctx.makeImage() else { fatalError("makeImage") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode")
}
try png.write(to: outURL)
print("Wrote \(outURL.path) — \(png.count) bytes")
