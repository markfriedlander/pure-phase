// ========== BLOCK 28: SessionView (breathwork branch + cues) - START ==========

// iOS-only view. The tvOS target shares this folder via a
// PBXFileSystemSynchronizedRootGroup but uses its own UI in
// NeuroLightTV/. The #if guard prevents tvOS compile errors
// from APIs (Slider, UIImpactFeedbackGenerator, navigation
// bar modifiers, etc.) that are iOS-only on this codebase.
#if os(iOS)
//
//  SessionView.swift
//  NeuroLight
//
//  The full-screen session experience.
//
//  Two modes:
//   • Entrainment — flicker layer (solid or gradient) opacity-driven by
//     engine.brightness, breath ring overlay, optional torch.
//   • Breathwork  — no flicker, no torch. The breath ring is enlarged
//     and centered with a soft warm halo behind it. Optional breath
//     audio cues fire at each phase transition.
//
//  Tap reveals exit + remaining time, auto-hides after 3 s.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SessionView: View {
    let config: SessionConfig

    @State private var engine = SessionEngine()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StorageKey.ackReduceMotion) private var ackReduceMotion: Bool = false
    @State private var overlayVisible: Bool = false
    @State private var overlayHideTask: Task<Void, Never>?
    @State private var lastBreathStage: String = ""
    @State private var savedScreen: String = "home"
    @State private var showingReduceMotionGate: Bool = false
    @Bindable private var bus = AutomationBus.shared

    var body: some View {
        let state = config.state
        // Breath-style rendering covers BREATHWORK, DRIFT, and BLOOM —
        // no flicker, prominent ring, soft halo. BLOOM additionally
        // gets a responsive Canvas behind the ring (not yet wired —
        // see Docs/PurePhase2.0Spec.md §3).
        let breathOnly = state.usesBreathStyleRendering

        ZStack {
            Color.black.ignoresSafeArea()

            // ENTRAINMENT FLICKER LAYER — only when this state has flicker.
            if state.hasFlicker {
                Group {
                    if config.colorModeEnabled {
                        state.sessionTint.gradient
                    } else {
                        state.sessionTint.startColor
                    }
                }
                .opacity(engine.flickerPhase ? engine.brightness : 0)
                .modifier(PrismHueModifier(active: state.driftEnabled, elapsed: engine.elapsed))
                .ignoresSafeArea()
            }

            // BLOOM RESPONSIVE BACKGROUND — full-screen radial bloom
            // driven by the audio synthesis LFO phases. Replaces the
            // halo for BLOOM specifically; halo still applies to
            // BREATHWORK and DRIFT (where it's the only background).
            if state.isBloom {
                BloomBackgroundView(
                    driftState: engine.driftAudio.state,
                    envelope: engine.brightness
                )
            }

            // BREATHWORK / DRIFT HALO — soft warm radial behind the ring,
            // pulsing very gently with the breath. Not used for BLOOM
            // since BLOOM has its own richer responsive background.
            if breathOnly && !state.isBloom {
                RadialGradient(
                    colors: [
                        state.sessionTint.startColor.opacity(0.18 + 0.05 * engine.breathPhase),
                        .clear
                    ],
                    center: .center, startRadius: 60, endRadius: 360
                )
                .opacity(engine.brightness)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // BREATH GUIDE — overlay in entrainment, centerpiece in
            // breathwork. On BLOOM the breath ring rides at reduced
            // opacity so the responsive bloom is the focal point and
            // the ring is a reference rather than the centerpiece.
            if engine.isRunning && (config.breathEnabled || breathOnly) {
                let ringOpacity: Double = {
                    if state.isBloom    { return 0.6 }   // subordinate to bloom
                    if breathOnly       { return 1.0 }   // BREATHWORK / DRIFT — centerpiece
                    return 0.85                          // entrainment overlay
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

            // EDGE PROGRESS
            if let p = engine.sessionProgress {
                GradientProgressRing(progress: p, tint: state.sessionTint, cornerRadius: 55)
                    .padding(2)
                    .opacity(engine.brightness)
            }

            // OVERLAY
            if overlayVisible {
                VStack {
                    HStack {
                        Text(timeString(engine.remaining))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 22)
                            .padding(.top, 18)
                        Spacer()
                        Button {
                            engine.stop()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                        .accessibilityLabel("Exit session")
                        .accessibilityIdentifier("session.exit")
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { revealOverlay() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            savedScreen = bus.currentScreen
            bus.currentScreen = "session.\(state.id)"
            bus.currentEngine = engine
            bus.currentConfig = config
            bus.register("session.exit") {
                engine.stop()
                dismiss()
            }
            #if !targetEnvironment(macCatalyst)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            // Reduce Motion gate: only for entrainment modes (flicker).
            // Breathwork is exempt — it has no rapid motion. Once
            // acknowledged, it never asks again on this device.
            if !state.isBreathwork && reduceMotion && !ackReduceMotion {
                showingReduceMotionGate = true
            } else {
                startEngine()
            }
        }
        .alert("Reduce Motion is enabled", isPresented: $showingReduceMotionGate) {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            Button("Continue") {
                ackReduceMotion = true
                startEngine()
            }
        } message: {
            Text("Pure Phase uses rapid rhythmic flicker — that's the entrainment mechanism. You have Reduce Motion enabled. Continue this session?")
        }
        .onDisappear {
            engine.stop()
            bus.unregister("session.exit")
            bus.currentEngine = nil
            bus.currentConfig = nil
            // Restore the screen the underlying view had — don't
            // assume "home". The push stack might be on Advanced.
            bus.currentScreen = savedScreen
            #if !targetEnvironment(macCatalyst)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        // Fire a breath audio cue on phase transition, breathwork only.
        .onChange(of: engine.breathStageName) { _, newStage in
            // Master fade envelope (mixer.outputVolume = brightness)
            // already quiets cues during fade-in/out, so we don't gate
            // here. Only suppress empty transitions and same-stage echoes.
            guard breathOnly,
                  config.breathAudioCues,
                  !newStage.isEmpty,
                  newStage != lastBreathStage else {
                lastBreathStage = newStage
                return
            }
            engine.audio.playBreathCue(stage: newStage, volume: config.breathCueVolume)
            bus.recordBreathCue(stage: newStage)
            lastBreathStage = newStage
        }
        .animation(.easeInOut(duration: 0.6), value: overlayVisible)
        .preferredColorScheme(.dark)
    }

    private func startEngine() {
        engine.start(config: config) {
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
    }

    private func revealOverlay() {
        overlayVisible = true
        overlayHideTask?.cancel()
        overlayHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { overlayVisible = false }
            }
        }
    }

    private func timeString(_ remaining: TimeInterval?) -> String {
        guard let r = remaining else { return "OPEN" }
        let total = Int(r.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Optional warm hue drift for PRISM state (renamed from Psychedelic
/// in 2.0). Stays in the red-orange-magenta range — never blue or green.
private struct PrismHueModifier: ViewModifier {
    let active: Bool
    let elapsed: TimeInterval
    func body(content: Content) -> some View {
        if active {
            content.hueRotation(.degrees(sin(elapsed * 0.7) * 22))
        } else {
            content
        }
    }
}
#endif
// ========== BLOCK 28: SessionView (breathwork branch + cues) - END ==========
