// Pick the brightest PNG from a list, by average pixel luminance.
//
// Usage: swift scripts/pick_brightest.swift <file1> <file2> ...
// Output: the path of the brightest input PNG (single line, no newline).
//
// Used by capture_screenshots.sh to identify the on-frame in a burst
// of screenshots of an entrainment session. File size is unreliable
// for low-saturation colors (SLEEP's ember red) because PNG compresses
// uniform dark colors similarly regardless of hue. Average pixel
// luminance directly measures the difference.

import AppKit
import Foundation

/// Average perceived luminance of a PNG, downsampled to 64×64 for
/// speed (~10 ms per file). Returns 0–255.
func averageLuminance(of path: String) -> Double {
    guard let img = NSImage(contentsOfFile: path)?
        .cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return -1 }

    let w = 64
    let h = 64
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: &pixels,
        width: w, height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return -1 }

    ctx.interpolationQuality = .low
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Rec. 709 perceived luminance: 0.2126 R + 0.7152 G + 0.0722 B
    var total: Int64 = 0
    let pixelCount = w * h
    for i in 0..<pixelCount {
        let r = Int64(pixels[i * 4])
        let g = Int64(pixels[i * 4 + 1])
        let b = Int64(pixels[i * 4 + 2])
        total += (2126 * r + 7152 * g + 722 * b) / 10000
    }
    return Double(total) / Double(pixelCount)
}

guard CommandLine.arguments.count > 1 else {
    print("usage: pick_brightest.swift <png-files...>")
    exit(1)
}

var bestPath = ""
var bestLuma: Double = -1
for arg in CommandLine.arguments.dropFirst() {
    let luma = averageLuminance(of: arg)
    if luma > bestLuma {
        bestLuma = luma
        bestPath = arg
    }
}
print(bestPath, terminator: "")
