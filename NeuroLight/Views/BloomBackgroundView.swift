// ========== BLOCK 36: BloomBackgroundView - START ==========
//
//  BloomBackgroundView.swift
//  NeuroLight
//
//  The BLOOM session's responsive visual layer — a slow generative
//  full-screen radial bloom whose parameters are driven in real time
//  by the audio synthesis state (DriftSynthesisState LFO phases).
//
//  Three driven elements (per 2.0 spec §3):
//
//    Breathing Carrier (24 s cycle) → bloom radius (0.85↔1.15× base)
//      and overall opacity (0.925↔1.0). The visual field literally
//      inhales and exhales with the carrier-frequency LFO.
//
//    Phase Drift (40 s cycle) → color temperature, interpolating
//      between an amber-leaning palette at 0° and a red-leaning
//      palette at 180°. Visual color drifts through the same space
//      the sound is moving through.
//
//    Harmonic Shimmer (1–2 Hz beats; only when Layer 3 is enabled)
//      → faint additive ring overlay at the beat frequency.
//      "More felt than seen." Default OFF per spec.
//
//  Implementation: TimelineView(.animation) re-renders at the display's
//  preferred refresh rate. Canvas does the gradient drawing — iOS 17
//  compatible (MeshGradient is iOS 18+, off the table for 2.0).
//
//  Reads DriftSynthesisState directly. The class is @unchecked Sendable
//  with word-aligned Double phases written by the audio render thread;
//  see DriftAudioEngine.swift for the rationale. Sub-Hz visual
//  modulation makes any tearing imperceptible.
//

import SwiftUI

struct BloomBackgroundView: View {
    /// Reference to the DriftAudioEngine's shared synthesis state.
    /// Audio render thread writes the LFO phases, this view reads them
    /// every frame.
    let driftState: DriftSynthesisState

    /// 0.0–1.0 fade envelope from SessionEngine. Multiplied into the
    /// rendered opacity so 3 s fade-in and 30 s fade-out apply
    /// automatically across the bloom's lifecycle.
    let envelope: Double

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas(rendersAsynchronously: false) { ctx, size in
                draw(ctx: ctx, size: size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Drawing

    private func draw(ctx: GraphicsContext, size: CGSize) {
        guard envelope > 0.001 else { return }

        // Read the audio thread's LFO phases. Per Q5 in CC's pre-build
        // response, these are word-aligned Doubles whose stores are
        // atomic at the hardware level on Apple silicon. No locking.
        let breathPhase   = driftState.breathingCarrierPhase
        let driftPhase    = driftState.phaseDriftPhase
        let shimmerPhase  = driftState.harmonicShimmerPhase
        let shimmerOn     = driftState.layerHarmonicShimmer

        // ---- Layer 1: Breathing Carrier → radius + opacity ----
        // sin(2π × phase) ∈ [-1, 1] → scale 0.85↔1.15, opacity 0.925↔1.0
        let breathSin = sin(2 * .pi * breathPhase)
        let radiusScale  = 1.00 + 0.15 * breathSin
        let bloomOpacity = (0.925 + 0.075 * breathSin) * envelope

        // ---- Layer 2: Phase Drift → color palette interpolation ----
        // Two warm palettes — amber-leaning at drift = 0, red-leaning
        // at drift = π. sin(2π × phase) maps to colorMix ∈ [0, 1].
        let driftSin = sin(2 * .pi * driftPhase)
        let colorMix = (driftSin + 1) / 2

        let core  = lerp(amberCore,  redCore,  colorMix)
        let mid   = lerp(amberMid,   redMid,   colorMix)
        let outer = lerp(amberOuter, redOuter, colorMix)

        // Bloom dimensions — anchored to the longer screen dimension so
        // the bloom always fills the viewport on any device shape.
        let baseRadius = max(size.width, size.height) * 0.6
        let radius = baseRadius * radiusScale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // First wash: black background. Ensures the radial bloom edge
        // bleeds to true black, not the system background.
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.black)
        )

        // ---- Bloom: radial gradient from warm core to deep dark ----
        var bloomCtx = ctx
        bloomCtx.opacity = bloomOpacity
        let gradient = Gradient(stops: [
            .init(color: core,  location: 0.00),
            .init(color: mid,   location: 0.35),
            .init(color: outer, location: 0.75),
            .init(color: .black, location: 1.00),
        ])
        bloomCtx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )

        // ---- Layer 3: Harmonic Shimmer (opt-in) → ring overlay ----
        // Subtle moiré-adjacent: a stroked ring at ~70% radius whose
        // alpha breathes at the shimmer beat frequency. Default off.
        if shimmerOn {
            let shimmerSin = sin(2 * .pi * shimmerPhase)
            let shimmerAlpha = (0.04 + 0.04 * shimmerSin) * envelope
            let shimmerRadius = radius * 0.7
            let rect = CGRect(
                x: center.x - shimmerRadius,
                y: center.y - shimmerRadius,
                width:  shimmerRadius * 2,
                height: shimmerRadius * 2
            )
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(shimmerAlpha)),
                lineWidth: 1
            )
        }
    }

    // MARK: Palette

    private var amberCore:  Color { Color(hex: 0xF5A623) }
    private var amberMid:   Color { Color(hex: 0xE8593C) }
    private var amberOuter: Color { Color(hex: 0x4A1810) }

    private var redCore:    Color { Color(hex: 0xE8593C) }
    private var redMid:     Color { Color(hex: 0xC0392B) }
    private var redOuter:   Color { Color(hex: 0x2A0808) }

    /// Linear interpolation between two SwiftUI Colors via their
    /// resolved sRGB components. SwiftUI's built-in Color has no
    /// public lerp; we extract components and rebuild.
    private func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ra = a.sRGBComponents
        let rb = b.sRGBComponents
        return Color(
            .sRGB,
            red:   ra.r + (rb.r - ra.r) * t,
            green: ra.g + (rb.g - ra.g) * t,
            blue:  ra.b + (rb.b - ra.b) * t,
            opacity: ra.a + (rb.a - ra.a) * t
        )
    }
}

// MARK: - Color introspection

private extension Color {
    /// Resolve a SwiftUI Color back into sRGB components. Used for
    /// linear interpolation in BLOOM's drift-driven palette mixing.
    /// The Color(hex:) initializer always builds sRGB so this round-
    /// trips losslessly for every color in our palette.
    var sRGBComponents: (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        // Fallback. Should be unreachable on iOS / iPadOS / tvOS.
        return (1, 1, 1, 1)
        #endif
    }
}
// ========== BLOCK 36: BloomBackgroundView - END ==========
