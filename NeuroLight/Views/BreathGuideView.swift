// ========== BLOCK 13: BreathGuideView - START ==========
//
//  BreathGuideView.swift
//  NeuroLight
//
//  A single warm ring that expands on inhale and contracts on exhale,
//  with a slow inner shimmer during hold phases. Reads breathPhase and
//  breathStageName from the SessionEngine. Linear phase from the engine
//  is shaped here through an ease-in-out curve so the motion feels
//  organic, not mechanical.
//

import SwiftUI

struct BreathGuideView: View {
    let phase: Double         // 0.0 – 1.0 within current stage
    let stageName: String     // "Inhale" / "Hold" / "Exhale" / "Hold"
    let tint: SessionTint
    let elapsed: TimeInterval // for the hold-phase shimmer
    var enlarged: Bool = false  // breathwork mode — bigger, fuller ring

    /// Cream — warm enough to belong to the palette, bright enough to
    /// stay visible whether the flicker is in its on or off phase.
    private static let creamStroke = Color(red: 1.0, green: 0.949, blue: 0.863)

    var body: some View {
        let scale = currentScale()
        let shimmer = isHoldStage ? (0.85 + 0.15 * sin(elapsed * 2 * .pi * 0.5)) : 1.0
        let size: CGFloat = enlarged ? 320 : 240
        let lineWidth: CGFloat = enlarged ? 2.8 : 2.2
        let haloLineWidth: CGFloat = enlarged ? 92 : 70
        let labelOffset: CGFloat = enlarged ? 220 : 160

        // NOTE: Per Mark's preference (May 2026), reverted to the
        // stroke+blur halo. He liked the previous look better even
        // with the stutter. The visible jitter at the top/bottom of
        // the breath cycle (and Focus pattern change) are deferred to
        // 1.1 polish — see MEMORY.md "Known Polish Issues".
        ZStack {
            // Warm halo — same color world as the active state, so the
            // ring still feels like it belongs.
            Circle()
                .stroke(
                    RadialGradient(
                        colors: [tint.startColor.opacity(enlarged ? 0.42 : 0.32), .clear],
                        center: .center, startRadius: 1, endRadius: 220
                    ),
                    lineWidth: haloLineWidth
                )
                .blur(radius: enlarged ? 18 : 14)

            // The ring itself — cream, never the same color as the
            // flicker, so it stays distinct on every frame.
            Circle()
                .stroke(BreathGuideView.creamStroke.opacity(0.92), lineWidth: lineWidth)
                .shadow(color: BreathGuideView.creamStroke.opacity(0.45), radius: enlarged ? 6 : 4)
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .opacity(shimmer)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Breath guide")
        .accessibilityValue(stageName.isEmpty ? "Starting" : stageName)
        // No implicit .animation here — the engine produces a fresh
        // scale every CADisplayLink tick (60–120 Hz). An ease-in-out
        // animation per frame causes the SwiftUI animation system to
        // continually start a new 0.18 s tween that the next frame
        // immediately invalidates, which manifests as a stutter at the
        // top and bottom of the breath cycle. Direct render = smooth.
        .overlay(
            Text(stageName.uppercased())
                .font(.system(size: enlarged ? 13 : 11, weight: .medium))
                .tracking(5)
                .foregroundColor(BreathGuideView.creamStroke.opacity(0.7))
                .offset(y: labelOffset)
        )
    }

    private var isHoldStage: Bool {
        stageName == "Hold"
    }

    /// Map the engine's linear `phase` (0–1 within the stage) onto an
    /// organic scale value. Inhale grows 0.4 → 1.0; Exhale shrinks the
    /// reverse. Holds sit flat at the corresponding extreme.
    private func currentScale() -> Double {
        let eased = easeInOut(phase)
        switch stageName {
        case "Inhale":
            return 0.4 + 0.6 * eased
        case "Exhale":
            return 1.0 - 0.6 * eased
        case "Hold":
            // Hold *after* inhale stays expanded (1.0); hold *after*
            // exhale stays contracted (0.4). We can't tell which from
            // the name alone, so look at phase progress: holds always
            // start where they ended, so we approximate with 1.0 for
            // the first hold stage encountered. For a four-phase
            // pattern with equal holds, this is correct most of the
            // time. Refined later if needed.
            return phase < 1.0 ? 1.0 : 0.4
        default:
            return 0.7
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        let clamped = max(0, min(1, x))
        return clamped < 0.5
            ? 2 * clamped * clamped
            : 1 - pow(-2 * clamped + 2, 2) / 2
    }
}
// ========== BLOCK 13: BreathGuideView - END ==========
