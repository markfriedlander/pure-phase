// Render all tvOS branding assets for Pure Phase.
//
// Produces:
//   App Icon (home screen):        Back/Middle/Front × 1x (400×240)  + 2x (800×480)
//   App Icon - App Store:          Back/Middle/Front × 1x (1280×768) + 2x (2560×1536)
//   Top Shelf Image:               1x (1920×720) + 2x (3840×1440)
//   Top Shelf Image Wide:          1x (2320×720) + 2x (4640×1440)
//
// All assets share the same vocabulary as the iOS app icon (warm radial
// pulse on black, two warm rings) — extended to wider aspect ratios and
// decomposed across three depth layers so the Apple TV focus parallax
// reads cleanly.
//
// Layer breakdown:
//   Back:   pure black + a wide low-opacity outer glow.
//           Stays steady on focus, defines the canvas.
//   Middle: the main radial bloom + the outer faint orange ring.
//           Carries most of the visual weight; small parallax shift on focus.
//   Front:  the bright amber middle ring + a small bright core highlight.
//           Largest parallax shift on focus — the layer that "lifts" toward you.
//
// Run:  swift scripts/render_tvos_icons.swift

import AppKit
import CoreGraphics
import Foundation

// MARK: - Colors

let amber:     [CGFloat] = [0xF5/255, 0xA6/255, 0x23/255]
let burnt:     [CGFloat] = [0xE8/255, 0x59/255, 0x3C/255]
let brick:     [CGFloat] = [0xC0/255, 0x39/255, 0x2B/255]

// MARK: - Drawing helpers

func makeContext(width: Int, height: Int) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("CGContext") }
    return ctx
}

func writePNG(_ ctx: CGContext, to path: String) {
    guard let cgImage = ctx.makeImage() else { fatalError("makeImage(\(path))") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("png(\(path))")
    }
    let url = URL(fileURLWithPath: path)
    try! png.write(to: url)
    print("  ✓ \(path) — \(png.count / 1024) KB")
}

func radialGradient(_ cs: CGColorSpace, components: [CGFloat], locations: [CGFloat]) -> CGGradient {
    guard let g = CGGradient(
        colorSpace: cs,
        colorComponents: components,
        locations: locations,
        count: locations.count
    ) else { fatalError("gradient") }
    return g
}

// MARK: - Layered-icon layers
//
// Width × height matter for layout, but the bloom is centered and sized
// relative to the *shorter* dimension so it looks correct on any tvOS
// icon aspect ratio (400×240 → 1.66, 1280×768 → 1.66, identical).

struct LayerSize { let w: Int; let h: Int }

func renderBack(size: LayerSize, to path: String) {
    let ctx = makeContext(width: size.w, height: size.h)
    let cs = CGColorSpaceCreateDeviceRGB()

    // Pure black ground.
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: size.w, height: size.h))

    // Low-opacity outer glow centered. This is what's left of the bloom
    // when the front layers parallax away from center — it makes the
    // edge feel anchored rather than the bloom appearing to float in
    // empty space.
    let center = CGPoint(x: CGFloat(size.w) / 2, y: CGFloat(size.h) / 2)
    let r = CGFloat(min(size.w, size.h)) * 0.55
    let glowComponents: [CGFloat] = [
        brick[0], brick[1], brick[2], 0.18,
        brick[0], brick[1], brick[2], 0.04,
        0, 0, 0, 0
    ]
    let glow = radialGradient(cs, components: glowComponents, locations: [0, 0.55, 1.0])
    ctx.drawRadialGradient(glow,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: r,
                           options: [])

    writePNG(ctx, to: path)
}

func renderMiddle(size: LayerSize, to path: String) {
    let ctx = makeContext(width: size.w, height: size.h)
    let cs = CGColorSpaceCreateDeviceRGB()

    // Transparent canvas — Back shows through where Middle has alpha 0.
    let center = CGPoint(x: CGFloat(size.w) / 2, y: CGFloat(size.h) / 2)
    let shortDim = CGFloat(min(size.w, size.h))

    // Main radial pulse: amber → burnt → brick → transparent, fading
    // gracefully so the front layer reads on top.
    let pulseComponents: [CGFloat] = [
        amber[0], amber[1], amber[2], 0.95,
        burnt[0], burnt[1], burnt[2], 0.70,
        brick[0], brick[1], brick[2], 0.25,
        0, 0, 0, 0
    ]
    let pulse = radialGradient(cs, components: pulseComponents, locations: [0, 0.30, 0.65, 1.0])
    ctx.drawRadialGradient(pulse,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: shortDim * 0.46,
                           options: [])

    // Outer faint orange ring — burnt at low opacity, thin stroke.
    let ringRadius1 = shortDim * 0.42
    ctx.setStrokeColor(red: burnt[0], green: burnt[1], blue: burnt[2], alpha: 0.5)
    ctx.setLineWidth(shortDim * 0.006)
    ctx.strokeEllipse(in: CGRect(
        x: center.x - ringRadius1, y: center.y - ringRadius1,
        width: ringRadius1 * 2, height: ringRadius1 * 2
    ))

    writePNG(ctx, to: path)
}

func renderFront(size: LayerSize, to path: String) {
    let ctx = makeContext(width: size.w, height: size.h)
    let cs = CGColorSpaceCreateDeviceRGB()

    let center = CGPoint(x: CGFloat(size.w) / 2, y: CGFloat(size.h) / 2)
    let shortDim = CGFloat(min(size.w, size.h))

    // Bright amber inner ring — the prominent halo, the layer that
    // pops forward on focus.
    let ringRadius2 = shortDim * 0.28
    ctx.setStrokeColor(red: amber[0], green: amber[1], blue: amber[2], alpha: 0.85)
    ctx.setLineWidth(shortDim * 0.013)
    ctx.strokeEllipse(in: CGRect(
        x: center.x - ringRadius2, y: center.y - ringRadius2,
        width: ringRadius2 * 2, height: ringRadius2 * 2
    ))

    // Small bright core highlight — radial, very tight, white-amber.
    let coreComponents: [CGFloat] = [
        1.0, 0.96, 0.85, 0.7,
        amber[0], amber[1], amber[2], 0.3,
        0, 0, 0, 0
    ]
    let core = radialGradient(cs, components: coreComponents, locations: [0, 0.5, 1.0])
    ctx.drawRadialGradient(core,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: shortDim * 0.12,
                           options: [])

    writePNG(ctx, to: path)
}

// MARK: - Top shelf hero

/// Top shelf image — single image, not layered. The hero banner that
/// shows above when Pure Phase is in the user's top row of TV apps.
/// Bloom anchored slightly left of center, "PURE PHASE" wordmark on
/// the right, all on black.
func renderTopShelf(size: LayerSize, to path: String) {
    let ctx = makeContext(width: size.w, height: size.h)
    let cs = CGColorSpaceCreateDeviceRGB()

    // Black ground.
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: size.w, height: size.h))

    let h = CGFloat(size.h)
    let w = CGFloat(size.w)

    // Bloom on the left third.
    let bloomCenter = CGPoint(x: w * 0.28, y: h / 2)
    let bloomR = h * 0.72
    let pulseComponents: [CGFloat] = [
        amber[0], amber[1], amber[2], 0.95,
        burnt[0], burnt[1], burnt[2], 0.70,
        brick[0], brick[1], brick[2], 0.25,
        0, 0, 0, 0
    ]
    let pulse = radialGradient(cs, components: pulseComponents, locations: [0, 0.30, 0.65, 1.0])
    ctx.drawRadialGradient(pulse,
                           startCenter: bloomCenter, startRadius: 0,
                           endCenter: bloomCenter, endRadius: bloomR,
                           options: [])

    // Outer faint ring around the bloom.
    let ring1 = h * 0.38
    ctx.setStrokeColor(red: burnt[0], green: burnt[1], blue: burnt[2], alpha: 0.5)
    ctx.setLineWidth(h * 0.005)
    ctx.strokeEllipse(in: CGRect(
        x: bloomCenter.x - ring1, y: bloomCenter.y - ring1,
        width: ring1 * 2, height: ring1 * 2
    ))

    // Bright amber inner ring.
    let ring2 = h * 0.26
    ctx.setStrokeColor(red: amber[0], green: amber[1], blue: amber[2], alpha: 0.85)
    ctx.setLineWidth(h * 0.012)
    ctx.strokeEllipse(in: CGRect(
        x: bloomCenter.x - ring2, y: bloomCenter.y - ring2,
        width: ring2 * 2, height: ring2 * 2
    ))

    // PURE PHASE wordmark — bold, tracked, white.
    // Sized and tracked so the full word fits on the right two-thirds
    // of the canvas with comfortable margin (cap-corner rule of ~5%
    // of canvas width on the right side).
    let text = "PURE PHASE"
    let fontSize = h * 0.16
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
        .kern: fontSize * 0.32,  // a touch tighter than the in-app wordmark so it fits at top-shelf scale
    ]
    let attr = NSAttributedString(string: text, attributes: attrs)
    let textSize = attr.size()

    // Center the wordmark vertically; right-align with comfortable
    // padding from the canvas edge so PHASE doesn't clip on wide variants.
    let rightPad = w * 0.07
    let textOrigin = CGPoint(
        x: w - rightPad - textSize.width,
        y: (h - textSize.height) / 2
    )

    // Render via NSGraphicsContext so AttributedString's NSFont path works.
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = nsCtx
    attr.draw(at: textOrigin)
    NSGraphicsContext.restoreGraphicsState()

    // Thin warm gradient bar above the wordmark — same vocabulary as
    // the home screen. Width matches the wordmark for visual balance.
    let barW = textSize.width
    let barX = textOrigin.x
    let barY = textOrigin.y + textSize.height + h * 0.04
    let barRect = CGRect(x: barX, y: barY, width: barW, height: 2)
    let barColors: [CGFloat] = [
        amber[0], amber[1], amber[2], 1.0,
        burnt[0], burnt[1], burnt[2], 1.0,
        brick[0], brick[1], brick[2], 1.0,
    ]
    let barGradient = radialGradient(cs, components: barColors, locations: [0, 0.5, 1.0])
    ctx.saveGState()
    ctx.clip(to: barRect)
    ctx.drawLinearGradient(barGradient,
                           start: CGPoint(x: barX, y: barY),
                           end: CGPoint(x: barX + barW, y: barY),
                           options: [])
    ctx.restoreGState()

    writePNG(ctx, to: path)
}

// MARK: - Driver

let assetRoot = "NeuroLightTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

func renderLayeredIcon(stack: String, baseW: Int, baseH: Int) {
    let stackPath = "\(assetRoot)/\(stack).imagestack"

    for (layer, render): (String, (LayerSize, String) -> Void) in [
        ("Back",   renderBack),
        ("Middle", renderMiddle),
        ("Front",  renderFront),
    ] {
        let imagesetPath = "\(stackPath)/\(layer).imagestacklayer/Content.imageset"
        // 1x
        render(LayerSize(w: baseW, h: baseH), "\(imagesetPath)/\(layer.lowercased())-1x.png")
        // 2x
        render(LayerSize(w: baseW * 2, h: baseH * 2), "\(imagesetPath)/\(layer.lowercased())-2x.png")

        // Update Contents.json to reference the new files.
        let json = """
        {
          "images" : [
            {
              "filename" : "\(layer.lowercased())-1x.png",
              "idiom" : "tv",
              "scale" : "1x"
            },
            {
              "filename" : "\(layer.lowercased())-2x.png",
              "idiom" : "tv",
              "scale" : "2x"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try! json.write(toFile: "\(imagesetPath)/Contents.json", atomically: true, encoding: .utf8)
    }
}

print("=== App Icon (home, 400×240) ===")
renderLayeredIcon(stack: "App Icon", baseW: 400, baseH: 240)

print("=== App Icon — App Store (1280×768) ===")
renderLayeredIcon(stack: "App Icon - App Store", baseW: 1280, baseH: 768)

print("=== Top Shelf Image (1920×720) ===")
let topShelfDir = "\(assetRoot)/Top Shelf Image.imageset"
renderTopShelf(size: LayerSize(w: 1920, h: 720), to: "\(topShelfDir)/topshelf-1x.png")
renderTopShelf(size: LayerSize(w: 3840, h: 1440), to: "\(topShelfDir)/topshelf-2x.png")
let topShelfJSON = """
{
  "images" : [
    {
      "filename" : "topshelf-1x.png",
      "idiom" : "tv",
      "scale" : "1x"
    },
    {
      "filename" : "topshelf-2x.png",
      "idiom" : "tv",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try! topShelfJSON.write(toFile: "\(topShelfDir)/Contents.json", atomically: true, encoding: .utf8)

print("=== Top Shelf Image Wide (2320×720) ===")
let topShelfWideDir = "\(assetRoot)/Top Shelf Image Wide.imageset"
renderTopShelf(size: LayerSize(w: 2320, h: 720), to: "\(topShelfWideDir)/topshelf-wide-1x.png")
renderTopShelf(size: LayerSize(w: 4640, h: 1440), to: "\(topShelfWideDir)/topshelf-wide-2x.png")
let topShelfWideJSON = """
{
  "images" : [
    {
      "filename" : "topshelf-wide-1x.png",
      "idiom" : "tv",
      "scale" : "1x"
    },
    {
      "filename" : "topshelf-wide-2x.png",
      "idiom" : "tv",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try! topShelfWideJSON.write(toFile: "\(topShelfWideDir)/Contents.json", atomically: true, encoding: .utf8)

print("\nDone.")
