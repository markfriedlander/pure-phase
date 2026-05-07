// ========== BLOCK 9: GradientProgressRing - START ==========
//
//  GradientProgressRing.swift
//  NeuroLight
//
//  Subliminal session progress: a 1-point-thin rounded rectangle stroke
//  that traces the screen edge, filling left → right across the top
//  edge first, then continuing clockwise. Reads peripherally — never
//  pulls attention.
//

import SwiftUI

struct GradientProgressRing: View {
    let progress: Double          // 0.0 – 1.0
    let tint: SessionTint
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            // No .rotationEffect — SwiftUI's RoundedRectangle path
            // starts at the top edge (just after the top-left rounded
            // corner) and proceeds clockwise. That gives the natural
            // "left → right across the top, then down the right side"
            // reading order Mark expects.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint.gradient, lineWidth: 1.0)
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(0.55)
                .animation(.linear(duration: 0.25), value: progress)
        }
        .allowsHitTesting(false)
    }
}
// ========== BLOCK 9: GradientProgressRing - END ==========
