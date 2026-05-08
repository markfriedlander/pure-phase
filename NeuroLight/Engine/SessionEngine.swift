// ========== BLOCK 5: SessionEngine - START ==========
//
//  SessionEngine.swift
//  NeuroLight
//
//  The single source of timing for an active session. Every visible and
//  audible output — flicker phase, breath phase, audio envelope, torch
//  pulse, progress ring — is computed mathematically from a single
//  elapsed-time number that this engine maintains via CADisplayLink.
//
//  Nothing else in the app keeps its own clock. Views observe the
//  published values; AudioEngine and TorchController are driven from
//  this engine's tick.
//
//  Lifecycle: start(config:onCompletion:) → stop().  No pause in v1.
//

import Foundation
import QuartzCore
import Observation
#if !targetEnvironment(macCatalyst)
import AVFoundation
#endif

@MainActor
@Observable
final class SessionEngine {

    // MARK: Outputs (observed by Views and downstream engines)

    private(set) var isRunning: Bool = false

    /// Mathematical flicker phase — true ⇒ "on" (light or color),
    /// false ⇒ "off" (black). Derived from elapsed time, not toggled.
    private(set) var flickerPhase: Bool = false

    /// 0.0–1.0 within the current breath stage.
    private(set) var breathPhase: Double = 0

    /// Human-readable name of the current breath stage.
    private(set) var breathStageName: String = ""

    /// 0.0–1.0 over the whole session. nil ⇒ Open mode (no end).
    private(set) var sessionProgress: Double? = nil

    /// 0.0–1.0 envelope multiplier covering fade-in (3 s) and
    /// fade-out (30 s). Multiply this into any visible/audible output.
    private(set) var brightness: Double = 0

    private(set) var elapsed: TimeInterval = 0

    /// Seconds remaining; nil in Open mode.
    private(set) var remaining: TimeInterval? = nil

    // MARK: Owned sub-engines

    let audio = AudioEngine()
    let driftAudio = DriftAudioEngine()
    let torch = TorchController()

    /// True when the active session uses the DRIFT/BLOOM audio engine
    /// rather than the 1.0 buffer-based AudioEngine. Set once at start
    /// based on the session config's state.
    private var usingDriftAudio: Bool = false

    // MARK: Internal state

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var config: SessionConfig?
    private var totalDuration: TimeInterval? = nil
    private var completionHandler: (() -> Void)?
    private var lastTorchPhase: Bool = false

    private(set) var isPaused: Bool = false
    private var pausedElapsed: TimeInterval = 0
    private var interruptionObserver: NSObjectProtocol?

    private let fadeInDuration: TimeInterval = 3
    private let fadeOutDuration: TimeInterval = 30

    init() {
        registerInterruptionObserver()
    }
    // No deinit observer cleanup — the [weak self] capture in the
    // observer closure makes a dangling reference safe; SessionEngine
    // outlives the SessionView and is owned by it, so the observer is
    // freed when the view is dismissed.

    // MARK: Lifecycle

    func start(config: SessionConfig, onCompletion: (() -> Void)? = nil) {
        stop()

        self.config = config
        self.completionHandler = onCompletion
        self.totalDuration = config.duration.minutes.map { $0 * 60 }
        self.startTime = CACurrentMediaTime()
        self.elapsed = 0
        self.brightness = 0
        self.flickerPhase = false
        self.breathPhase = 0
        self.breathStageName = ""
        self.sessionProgress = totalDuration == nil ? nil : 0
        self.remaining = totalDuration
        self.lastTorchPhase = false
        self.isRunning = true

        // Audio engine selection. DRIFT and BLOOM use the new real-time
        // synthesis engine (DriftAudioEngine.swift); everything else
        // uses the 1.0 buffer-based AudioEngine.
        //
        // TODO(2.0): The DriftAudioEngine render callback is currently
        // too slow for the iOS simulator's audio thread budget — the
        // simulator aborts the process with "Cleanup: RPC timeout.
        // Apparently deadlocked." after a few seconds. Real-device
        // performance is unverified. Until the render-callback
        // optimization lands (sin lookup table + phase-accumulator
        // pattern + reduced per-sample work), DRIFT and BLOOM run
        // SILENTLY — the visual experience works (black canvas /
        // breath ring / no flicker) but no audio plays. The engine
        // wiring is in place; the math just needs to be fast enough.
        usingDriftAudio = config.state.usesDriftAudioEngine
        if usingDriftAudio {
            // Intentionally NOT calling driftAudio.start here — see
            // TODO above. Restore once the render callback is optimized.
            // driftAudio.start(
            //     carrierHz: config.state.carrierHz,
            //     isochronicHz: config.state.hz,
            //     layerBreathingCarrier: true,
            //     layerPhaseDrift: true,
            //     layerHarmonicShimmer: false
            // )
        } else if config.needsAudio {
            // Start the 1.0 AudioEngine if ANY audio layer is wanted —
            // isochronic tone, ambient texture, or breathwork cues.
            // Earlier this gated only on `audioEnabled` (the iso flag),
            // which silently broke breathwork mode where iso is off but
            // cues should still play.
            audio.start(config: config)
        }

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        torch.forceOff()
        audio.stop()
        driftAudio.stop()
        usingDriftAudio = false
        isRunning = false
        isPaused = false
        flickerPhase = false
        brightness = 0
        config = nil
        totalDuration = nil
        completionHandler = nil
    }

    // MARK: Pause / resume — for audio session interruptions

    /// Suspend the entire session: stop the display link (no more
    /// flicker math), force the torch off, pause audio. Called when an
    /// AVAudioSession interruption begins (phone call, Siri, another
    /// app starts playing). Brightness goes to 0 so the screen reads
    /// as black during the interruption, not frozen on the last frame.
    func pauseForInterruption() {
        guard isRunning, !isPaused else { return }
        pausedElapsed = elapsed
        displayLink?.invalidate()
        displayLink = nil
        torch.forceOff()
        lastTorchPhase = false
        if usingDriftAudio {
            driftAudio.pauseForInterruption()
        } else {
            audio.pauseForInterruption()
        }
        flickerPhase = false
        brightness = 0
        isPaused = true
    }

    /// Resume after an interruption ends with iOS suggesting resume.
    /// Adjusts startTime so the elapsed counter picks up exactly where
    /// it paused — no jump in audio buffer or breath cycle position.
    func resumeFromInterruption() {
        guard isRunning, isPaused else { return }
        startTime = CACurrentMediaTime() - pausedElapsed
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        if usingDriftAudio {
            driftAudio.resumeFromInterruption()
        } else {
            audio.resumeFromInterruption()
        }
        isPaused = false
    }

    private func registerInterruptionObserver() {
        #if !targetEnvironment(macCatalyst)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
        #endif
    }

    private func handleInterruption(_ notification: Notification) {
        #if !targetEnvironment(macCatalyst)
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }

        switch type {
        case .began:
            pauseForInterruption()
        case .ended:
            let optionsRaw = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) {
                resumeFromInterruption()
            }
        @unknown default:
            break
        }
        #endif
    }

    // MARK: Tick (one call per display refresh)

    @objc private func tick() {
        guard isRunning, !isPaused, let config = config else { return }

        let t = CACurrentMediaTime() - startTime
        elapsed = t
        brightness = computeBrightness(elapsed: t, total: totalDuration)

        let effectiveHz = computeEffectiveHz(state: config.state, elapsed: t)
        flickerPhase = sin(2 * .pi * effectiveHz * t) > 0

        if config.breathEnabled {
            let (phase, stage) = computeBreath(pattern: config.breathPattern, elapsed: t)
            breathPhase = phase
            breathStageName = stage
        }

        if let total = totalDuration {
            sessionProgress = min(t / total, 1.0)
            remaining = max(total - t, 0)
        } else {
            sessionProgress = nil
            remaining = nil
        }

        // Push fade envelope to whichever audio engine is active.
        // Float volume on the mixer; same value drives both engines.
        if usingDriftAudio {
            driftAudio.setEnvelope(brightness)
        } else {
            audio.setEnvelope(brightness)
        }

        // Drive the torch only on edges (avoid hammering the hardware).
        if config.torchEnabled && torch.isAvailable {
            let shouldFire = flickerPhase && brightness > 0.05
            if shouldFire != lastTorchPhase {
                torch.setOn(shouldFire)
                lastTorchPhase = shouldFire
            }
        }

        // Natural completion.
        if let total = totalDuration, t >= total {
            let handler = completionHandler
            stop()
            handler?()
        }
    }

    // MARK: Math

    /// Brightness ramps in over fadeInDuration, sits at 1.0, and ramps
    /// out over fadeOutDuration before a timed session ends. In Open
    /// mode the fade-out is skipped (the user controls the end).
    private func computeBrightness(elapsed t: TimeInterval, total: TimeInterval?) -> Double {
        if t < fadeInDuration {
            return max(0, t / fadeInDuration)
        }
        if let total = total, total > fadeInDuration + fadeOutDuration {
            let timeLeft = total - t
            if timeLeft < fadeOutDuration {
                return max(0, timeLeft / fadeOutDuration)
            }
        }
        return 1
    }

    /// Most states use a fixed Hz. PRISM mode (renamed from Psychedelic
    /// in 2.0) wobbles ±20% on a 15-second cycle — kept from the
    /// original app per spec.
    private func computeEffectiveHz(state: BrainwaveState, elapsed t: TimeInterval) -> Double {
        guard state.driftEnabled else { return state.hz }
        let drift = 1.0 + 0.2 * sin(t * 2 * .pi / 15.0)
        return state.hz * drift
    }

    /// Walk the breath pattern's four stages, return current stage name
    /// and 0.0–1.0 progress within that stage.
    private func computeBreath(pattern: BreathPattern, elapsed t: TimeInterval) -> (Double, String) {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return (0, "") }
        let inCycle = t.truncatingRemainder(dividingBy: cycle)

        let stages: [(name: String, duration: TimeInterval)] = [
            ("Inhale", pattern.inhale),
            ("Hold",   pattern.inhaleHold),
            ("Exhale", pattern.exhale),
            ("Hold",   pattern.exhaleHold)
        ]

        var cursor: TimeInterval = 0
        for stage in stages {
            if stage.duration <= 0 { continue }
            if inCycle < cursor + stage.duration {
                let phase = (inCycle - cursor) / stage.duration
                return (phase, stage.name)
            }
            cursor += stage.duration
        }
        return (0, "Inhale")
    }
}
// ========== BLOCK 5: SessionEngine - END ==========
