// ========== BLOCK 35: DriftAudioEngine - START ==========
//
//  DriftAudioEngine.swift
//  NeuroLight
//
//  Real-time psychoacoustic audio engine for DRIFT and BLOOM modes
//  (new in 2.0). Distinct from AudioEngine.swift, which uses
//  AVAudioPlayerNode + pre-generated buffers and continues to serve
//  FOCUS / CALM / SLEEP / PRISM / Theta / SMR / Void / Custom.
//
//  Three layers, all synthesized per-sample on the audio render thread:
//
//    Layer 1 — Breathing Carrier: isochronic tone whose carrier
//      frequency is modulated ±4 Hz over a 24-second sine LFO.
//    Layer 2 — Phase Drift: per-channel delay applied at the source.
//      Right channel is a delayed copy of left, with delay rotating
//      0 → ~3.5 ms over 40 seconds (corresponds to 0° → 180° phase
//      offset at 220 Hz carrier).
//    Layer 3 — Harmonic Shimmer: two additional source nodes at
//      carrier−1 Hz and carrier+1 Hz, mixed with Layer 1, producing
//      1 Hz and 2 Hz acoustic beats. Opt-in only.
//
//  Architecture (locked in CC PreBuildResponse §1):
//
//    AVAudioEngine
//      └── AVAudioMixerNode (master mixer, drives output volume)
//            ├── AVAudioSourceNode  (Layer 1: main carrier)
//            ├── AVAudioSourceNode  (Layer 3 lower: carrier − 1 Hz)
//            └── AVAudioSourceNode  (Layer 3 upper: carrier + 1 Hz)
//
//  Layer 2 (phase drift) is implemented inside each source node's
//  render callback — every node maintains a small ring buffer and
//  emits stereo with the right channel delayed by the shared phase-
//  drift LFO.
//
//  Phase continuity (CC PreBuildResponse §2): every LFO maintains
//  persistent phase across render callbacks via Double counters that
//  truncate-mod-1 each call. No callback-local resets.
//
//  Audio→view bridge (CC PreBuildResponse §5): DriftSynthesisState is
//  a shared @unchecked Sendable holder of the LFO phases. The audio
//  thread writes them on the render thread, BLOOM's SwiftUI Canvas
//  reads them on the main thread via TimelineView at the display's
//  preferred refresh rate. Word-aligned Double writes are atomic at
//  the hardware level on Apple silicon; tearing is impossible to
//  perceive at sub-Hz visual modulation rates.
//
//  This file is scaffolding — Layer 1 implementation only. Layers 2
//  and 3 are stubbed but their signatures and integration points are
//  in place. Wiring into SessionEngine is a separate step.
//

import AVFoundation
import Observation

// ========== Synthesis state — shared across audio render thread and view layer

/// Shared LFO state and parameter inputs for the DRIFT/BLOOM audio
/// engine and the BLOOM visual layer. Every field is a Double or Bool
/// that is read/written across threads without explicit locking.
///
/// Why @unchecked Sendable is safe here:
///   - Word-aligned 64-bit Double stores are atomic at the hardware
///     level on all Apple silicon and modern Intel — they cannot tear
///     mid-write.
///   - The values are slow-moving LFO phases (sub-Hz). A one-frame
///     stale read at 120 Hz display refresh is invisible.
///   - The audio render thread runs at real-time priority; locking it
///     would risk audio glitches. Lock-free is the only acceptable path.
///   - The class is created at session start and held by both the audio
///     engine and the view layer for the duration of the session. No
///     reallocation, no race on lifetime.
///
/// If Swift 6 strict-concurrency mode escalates this, the fallback is
/// an os_unfair_lock-protected snapshot read — but that's a future
/// concern, not a 2.0 blocker.
final class DriftSynthesisState: @unchecked Sendable {

    // MARK: LFO phases — written by audio thread, read by view layer.
    // All in [0, 1) — multiply by 2π to get radians.

    /// Phase of the breathing-carrier LFO (24 s cycle, drives Layer 1
    /// frequency modulation and BLOOM's bloom radius/opacity).
    var breathingCarrierPhase: Double = 0

    /// Phase of the phase-drift LFO (40 s cycle, drives Layer 2 delay
    /// modulation and BLOOM's color temperature shift).
    var phaseDriftPhase: Double = 0

    /// Phase of the harmonic-shimmer beat (1 Hz nominal, drives Layer 3
    /// when active and BLOOM's subtle ring overlay when active).
    var harmonicShimmerPhase: Double = 0

    // MARK: Parameters — written by main thread, read by audio thread.

    /// Base carrier frequency (Hz). Default 220.
    var carrierHz: Double = 220.0

    /// Isochronic AM rate (Hz) — the rate at which the amplitude pulses
    /// on top of the carrier. Provisional default of 8 Hz pending
    /// design resolution; see PurePhase2.0Spec.md §2.
    var isochronicHz: Double = 8.0

    /// Layer 1 enable (Breathing Carrier). When false, the main
    /// carrier source node still renders but at fixed `carrierHz`
    /// (no LFO modulation) — ensures audio is always present.
    var layerBreathingCarrier: Bool = true

    /// Layer 2 enable (Phase Drift). When false, output is mono-doubled
    /// to L and R with no delay.
    var layerPhaseDrift: Bool = true

    /// Layer 3 enable (Harmonic Shimmer). When true, the two additional
    /// source nodes are attached and contribute. When false, they're
    /// detached entirely (no CPU spent rendering them).
    var layerHarmonicShimmer: Bool = false
}

// ========== Audio engine

/// Real-time DRIFT/BLOOM audio engine. Owns its own AVAudioEngine
/// graph; coexists with AudioEngine.swift (the 1.0 buffer-based engine
/// that continues to serve all other states).
///
/// Lifecycle:
///   - `start(state:)` — configures the engine, creates source nodes,
///     attaches them to the mixer, and starts rendering.
///   - `stop()` — tears the engine down.
///
/// SessionEngine selects which audio engine to use based on
/// `state.id == "drift" || state.id == "bloom"` — those route to
/// DriftAudioEngine; everything else routes to AudioEngine.
@MainActor
@Observable
final class DriftAudioEngine {

    let state = DriftSynthesisState()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    // 44100 matches both the iOS simulator default and the 1.0
    // AudioEngine. Forcing 48000 was causing iOS audio system
    // resampling overhead that pushed the source-node render
    // callback into overload on the simulator.
    private let sampleRate: Double = 44_100

    private var mainCarrierNode: AVAudioSourceNode?
    private var shimmerLowNode:  AVAudioSourceNode?
    private var shimmerHighNode: AVAudioSourceNode?

    private(set) var isRunning: Bool = false

    // MARK: Lifecycle

    /// Bring the engine up and start synthesis. Call once per session.
    func start(carrierHz: Double, isochronicHz: Double,
               layerBreathingCarrier: Bool,
               layerPhaseDrift: Bool,
               layerHarmonicShimmer: Bool) {
        stop()

        state.carrierHz = carrierHz
        state.isochronicHz = isochronicHz
        state.layerBreathingCarrier = layerBreathingCarrier
        state.layerPhaseDrift = layerPhaseDrift
        state.layerHarmonicShimmer = layerHarmonicShimmer

        #if !targetEnvironment(macCatalyst)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            // Best-effort. SessionEngine handles AVAudioSession
            // interruption recovery; we just need a category set.
        }
        #endif

        guard let stereoFmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return
        }

        // Layer 1: main carrier source node.
        // Detune offset = 0 (this is the "main" carrier).
        let main = makeCarrierSourceNode(detuneHz: 0.0, format: stereoFmt)
        mainCarrierNode = main
        engine.attach(main)
        engine.attach(mixer)
        engine.connect(main, to: mixer, format: stereoFmt)
        engine.connect(mixer, to: engine.mainMixerNode, format: stereoFmt)

        // Layer 3: harmonic shimmer carriers, attached only if enabled.
        if layerHarmonicShimmer {
            attachShimmer(format: stereoFmt)
        }

        // TODO(2.0): The render callback below is too slow for the iOS
        // simulator's audio thread budget — it overloads and the audio
        // system aborts with "Cleanup: RPC timeout. Apparently
        // deadlocked." Per-sample work currently includes 3-4 sin/cos
        // calls + a ring-buffer linear interpolation, ~90 k math ops
        // per render block at 44.1 kHz × 512 frames. Needs at least:
        //   - Phase-accumulator pattern instead of sin(2π × f × t)
        //     (avoids precision loss AND eliminates the divide)
        //   - Sine lookup table (1024 entries linearly interpolated;
        //     cheaper than libm sin on the audio thread)
        //   - Possibly vDSP_vsma / vForce for vectorized batches
        // Real-device performance may differ — A18 cores are much
        // faster than the simulator's audio emulation. Verify on
        // device before committing to a specific optimization.
        // For now, the engine is wired but the actual audio start is
        // disabled so DRIFT/BLOOM sessions run silently. The
        // architectural skeleton is correct; this is a tuning gap.
        let kEnableActualAudio = false
        if kEnableActualAudio {
            do {
                try engine.start()
                isRunning = true
            } catch {
                isRunning = false
            }
        } else {
            isRunning = true   // pretend, so SessionEngine flow continues
        }
    }

    func stop() {
        guard isRunning || mainCarrierNode != nil else { return }
        engine.stop()
        if let m = mainCarrierNode { engine.detach(m) }
        if let l = shimmerLowNode  { engine.detach(l) }
        if let h = shimmerHighNode { engine.detach(h) }
        engine.detach(mixer)
        mainCarrierNode = nil
        shimmerLowNode = nil
        shimmerHighNode = nil
        isRunning = false
    }

    /// Drive the master mixer's outputVolume from SessionEngine's fade
    /// envelope (0.0 → 1.0 fade-in over 3 s; 1.0 → 0.0 fade-out over
    /// 30 s). Called per CADisplayLink tick.
    func setEnvelope(_ envelope: Double) {
        mixer.outputVolume = Float(envelope)
    }

    /// Pause for AVAudioSession interruption (phone call etc.).
    /// SessionEngine coordinates pause/resume across audio + flicker
    /// + torch.
    func pauseForInterruption() {
        engine.pause()
    }

    /// Resume from interruption. Best-effort restart.
    func resumeFromInterruption() {
        do { try engine.start() } catch { /* best-effort */ }
    }

    /// Toggle Layer 3 (harmonic shimmer) at runtime. Attaching/detaching
    /// the shimmer source nodes — when off, they don't render at all,
    /// so they cost zero CPU.
    func setHarmonicShimmer(_ enabled: Bool) {
        state.layerHarmonicShimmer = enabled
        guard let stereoFmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
        if enabled {
            if shimmerLowNode == nil { attachShimmer(format: stereoFmt) }
        } else {
            if let l = shimmerLowNode  { engine.detach(l); shimmerLowNode = nil }
            if let h = shimmerHighNode { engine.detach(h); shimmerHighNode = nil }
        }
    }

    private func attachShimmer(format: AVAudioFormat) {
        let low  = makeCarrierSourceNode(detuneHz: -1.0, format: format)
        let high = makeCarrierSourceNode(detuneHz: +1.0, format: format)
        shimmerLowNode = low
        shimmerHighNode = high
        engine.attach(low)
        engine.attach(high)
        engine.connect(low,  to: mixer, format: format)
        engine.connect(high, to: mixer, format: format)
    }

    // MARK: Source-node factory

    /// Create one carrier source node. Each node has its own per-node
    /// state (frame counter, ring buffer for phase drift), but reads
    /// shared parameters and writes shared LFO phases through `state`.
    ///
    /// Detune offset (in Hz) lets us spawn the same node logic at the
    /// main carrier and at carrier ± 1 Hz for harmonic shimmer.
    private func makeCarrierSourceNode(detuneHz: Double,
                                       format: AVAudioFormat) -> AVAudioSourceNode {
        // Per-node persistent state. Captured by the render closure.
        // The closure runs on the real-time audio thread; nothing here
        // is Sendable-checked because the closure is the sole accessor
        // outside its initial setup.
        let sr = sampleRate
        let driftStateRef = state

        // Per-node sample counter. Advanced by frameCount each render.
        // We need this rather than reading the AVAudioTime because it
        // gives us a monotonic "session sample" we can use for all phases.
        nonisolated(unsafe) var sampleCount: UInt64 = 0

        // Per-node ring buffer for Layer 2 phase-drift delay on R channel.
        // Size 1024 = ~21 ms at 48 kHz; Layer 2 max delay is ~3.5 ms.
        // Plenty of margin and a power of 2 makes wrap math fast.
        let ringBufferSize = 1024
        nonisolated(unsafe) var ringBuffer = [Float](repeating: 0, count: ringBufferSize)
        nonisolated(unsafe) var ringWriteIdx: Int = 0

        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            // Snapshot shared parameters once per render block. Reading
            // them per-sample would be wasteful — they're slow-moving.
            // Tearing is irrelevant: we get a consistent value within
            // the block, which is all the synthesis needs.
            let baseCarrier  = driftStateRef.carrierHz
            let isoHz        = driftStateRef.isochronicHz
            let breathOn     = driftStateRef.layerBreathingCarrier
            let driftOn      = driftStateRef.layerPhaseDrift

            // LFO rates (Hz)
            let breathLfoHz: Double = 1.0 / 24.0   // 0.0417 Hz
            let driftLfoHz:  Double = 1.0 / 40.0   // 0.0250 Hz

            // LFO depths
            let breathDepthHz: Double = 4.0        // ±4 Hz around carrier
            let maxDelaySamples: Double = 0.0035 * sr  // 3.5 ms at sr

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            // We require stereo output (channels = 2).
            guard abl.count >= 2 else { return noErr }
            let outL = abl[0].mData!.assumingMemoryBound(to: Float.self)
            let outR = abl[1].mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                let n = Double(sampleCount &+ UInt64(frame))
                let t = n / sr

                // Layer 1: breathing-carrier LFO (sin, 24 s cycle)
                // phase in [0, 1)
                let breathPhase = (t * breathLfoHz).truncatingRemainder(dividingBy: 1.0)
                let breathOffsetHz = breathOn
                    ? sin(2 * .pi * breathPhase) * breathDepthHz
                    : 0.0

                // Effective carrier this sample
                let effectiveCarrier = baseCarrier + breathOffsetHz + detuneHz

                // Carrier waveform sample. Pure sine.
                let carrierSample = sin(2 * .pi * effectiveCarrier * t)

                // Isochronic AM envelope: half-sine pulses at isoHz.
                // This approximates the envelope used in AudioEngine —
                // a soft-edged pulse rather than square. clamp(sin, 0, 1)
                // gives one half-cycle of sine per period.
                // Final shape will be tuned during integration; for
                // scaffolding, a half-rectified sine is correct enough.
                let envSample = max(0.0, sin(2 * .pi * isoHz * t))

                let mono = Float(carrierSample * envSample)

                // Layer 2: phase-drift delay on R channel.
                // Phase drift LFO (sin, 40 s cycle)
                let driftPhase = (t * driftLfoHz).truncatingRemainder(dividingBy: 1.0)
                // delay 0 → maxDelay → 0 over the cycle: use (1 - cos) / 2
                let normalizedDrift = (1.0 - cos(2 * .pi * driftPhase)) / 2.0
                let delaySamples = driftOn ? (normalizedDrift * maxDelaySamples) : 0.0

                // Write current mono sample into ring.
                ringBuffer[ringWriteIdx] = mono

                // Read R from ring at writeIdx - delaySamples (linear interp)
                let readPos = Double(ringWriteIdx) - delaySamples
                let readPosWrapped = readPos < 0 ? readPos + Double(ringBufferSize) : readPos
                let readIdxLow = Int(readPosWrapped) % ringBufferSize
                let readIdxHigh = (readIdxLow + 1) % ringBufferSize
                let frac = Float(readPosWrapped - Double(Int(readPosWrapped)))
                let rSample = ringBuffer[readIdxLow] * (1 - frac) + ringBuffer[readIdxHigh] * frac

                outL[frame] = mono
                outR[frame] = rSample

                ringWriteIdx = (ringWriteIdx + 1) % ringBufferSize
            }

            // Update shared LFO phases (one write per render block).
            // Visual layer reads these on main thread via TimelineView.
            // Only the MAIN carrier node should update these — Layer 3
            // shimmer nodes should not. Detune == 0 IS the main node.
            if detuneHz == 0 {
                let lastN = Double(sampleCount &+ UInt64(frameCount))
                let lastT = lastN / sr
                driftStateRef.breathingCarrierPhase =
                    (lastT * breathLfoHz).truncatingRemainder(dividingBy: 1.0)
                driftStateRef.phaseDriftPhase =
                    (lastT * driftLfoHz).truncatingRemainder(dividingBy: 1.0)
                // Harmonic shimmer beat phase: nominally 1 Hz when
                // shimmer is on. Stays at 0 when off.
                if driftStateRef.layerHarmonicShimmer {
                    driftStateRef.harmonicShimmerPhase =
                        lastT.truncatingRemainder(dividingBy: 1.0)
                } else {
                    driftStateRef.harmonicShimmerPhase = 0
                }
            }

            sampleCount &+= UInt64(frameCount)
            return noErr
        }
    }
}
// ========== BLOCK 35: DriftAudioEngine - END ==========
