// ========== BLOCK 41: TVSessionView (full-bleed, click-to-exit) - START ==========
//
//  TVSessionView.swift
//  NeuroLightTV
//
//  Full-bleed session experience for tvOS. Owns its own SessionEngine
//  instance (mirrors the iOS SessionView pattern) and renders the
//  appropriate visual layer based on the state's rendering style:
//
//    Entrainment states (FOCUS / CALM / SLEEP) — full-screen color
//      flicker with PrismHueModifier-equivalent treatment.
//
//    Breath-style states (BREATHWORK / DRIFT) — black canvas with
//      the soft halo + breath ring + INHALE/EXHALE label, identical
//      visual treatment to iOS just at TV scale.
//
//    BLOOM — the responsive Canvas bloom (BloomBackgroundView) that
//      already lives in the shared codebase, with the breath ring
//      riding subtly above. This is the flagship TV experience —
//      slow generative bloom filling a room-sized screen, audio
//      breathing out the home speakers.
//
//  Exit: Siri Remote Menu button (`.onExitCommand`) or play/pause.
//  No tap-to-reveal-overlay pattern on TV — the entire screen is the
//  exit affordance.
//

import SwiftUI

struct TVSessionView: View {
    let config: SessionConfig
    let onExit: () -> Void

    @State private var engine = SessionEngine()

    var body: some View {
        let state = config.state
        let breathOnly = state.usesBreathStyleRendering

        ZStack {
            Color.black.ignoresSafeArea()

            // Entrainment flicker layer — only when this state has flicker
            // (FOCUS / CALM / SLEEP on TV).
            if state.hasFlicker {
                Group {
                    if config.colorModeEnabled {
                        state.sessionTint.gradient
                    } else {
                        state.sessionTint.startColor
                    }
                }
                .opacity(engine.flickerPhase ? engine.brightness : 0)
                .ignoresSafeArea()
            }

            // BLOOM responsive bloom — full-screen radial bloom driven
            // by the audio LFOs. Only on BLOOM.
            if state.isBloom {
                BloomBackgroundView(
                    driftState: engine.driftAudio.state,
                    envelope: engine.brightness
                )
            }

            // BREATHWORK / DRIFT halo (suppressed on BLOOM, which has
            // its own much richer responsive background).
            if breathOnly && !state.isBloom {
                RadialGradient(
                    colors: [
                        state.sessionTint.startColor.opacity(0.18 + 0.05 * engine.breathPhase),
                        .clear
                    ],
                    center: .center, startRadius: 120, endRadius: 600
                )
                .opacity(engine.brightness)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Breath ring — centerpiece for BREATHWORK / DRIFT, subordinate
            // overlay on BLOOM (lower opacity), and a small overlay on
            // entrainment states when the user has breath enabled.
            if engine.isRunning && (config.breathEnabled || breathOnly) {
                let ringOpacity: Double = {
                    if state.isBloom { return 0.6 }
                    if breathOnly    { return 1.0 }
                    return 0.85
                }()
                BreathGuideView(
                    phase: engine.breathPhase,
                    stageName: engine.breathStageName,
                    tint: state.sessionTint,
                    elapsed: engine.elapsed,
                    enlarged: breathOnly
                )
                .opacity(engine.brightness * ringOpacity)
                .allowsHitTesting(false)
            }

            // Edge progress ring — same as iOS, but at TV scale the
            // corner radius needs to be larger.
            if let p = engine.sessionProgress {
                GradientProgressRing(progress: p, tint: state.sessionTint, cornerRadius: 80)
                    .padding(8)
                    .opacity(engine.brightness)
            }
        }
        .focusable(true)
        .onExitCommand { exit() }
        .onPlayPauseCommand { exit() }
        .onAppear {
            engine.start(config: config) { exit() }
        }
        .onDisappear {
            engine.stop()
        }
    }

    private func exit() {
        engine.stop()
        onExit()
    }
}
// ========== BLOCK 41: TVSessionView (full-bleed, click-to-exit) - END ==========
