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

// ========== Sine lookup table (file-scoped, one-time init)
//
// libm sin() is too slow on the audio render thread when called per
// sample at 44.1 kHz × 4 phases (carrier + envelope + breath LFO +
// drift LFO). The simulator overloaded with the libm path; this LUT
// version is roughly 10–30× faster per call and brings the render
// callback well under the audio thread's time budget.
//
// 4096 entries × linear interpolation between adjacent entries gives
// far more resolution than 16-bit audio quantization can preserve —
// no audible artifacts. Memory cost: 16 KB. Index 4096 holds a copy
// of index 0 so the linear-interp read at the end of the table never
// has to do a modulo.

private let kSineLUTSize: Int = 4096

private let sineLUT: [Float] = {
    var t = [Float](repeating: 0, count: kSineLUTSize + 1)
    for i in 0...kSineLUTSize {
        t[i] = Float(sin(2 * Double.pi * Double(i) / Double(kSineLUTSize)))
    }
    return t
}()

/// Sine-from-phase lookup. `phase` MUST be in [0, 1). The caller is
/// responsible for wrapping (`phase -= floor(phase)`) — no defensive
/// branch here, since this runs per-sample on the audio thread.
@inline(__always)
private func sineLookup(_ phase: Double) -> Float {
    let scaled = phase * Double(kSineLUTSize)
    let idx = Int(scaled)
    let frac = Float(scaled - Double(idx))
    return sineLUT[idx] + (sineLUT[idx + 1] - sineLUT[idx]) * frac
}

/// Cosine-from-phase via the same LUT: `cos(2π × p) = sin(2π × (p + 0.25))`.
/// `phase` MUST be in [0, 1).
@inline(__always)
private func cosineLookup(_ phase: Double) -> Float {
    var p = phase + 0.25
    if p >= 1.0 { p -= 1.0 }
    return sineLookup(p)
}

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

        // The render callback uses a 4096-entry sine LUT and per-source
        // phase accumulators (see makeCarrierSourceNode below) instead
        // of libm `sin(2π × f × t)`. This made the difference between
        // an iOS simulator overload ("Cleanup: RPC timeout. Apparently
        // deadlocked.") and a clean real-time render. Verified on the
        // simulator after the optimization.
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
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
        let isMainNode = (detuneHz == 0)

        // Per-node phase accumulators in [0, 1). One full cycle = 1.0.
        // Phase-accumulator pattern (advancing each sample by f/sr and
        // wrapping with `-= floor(...)`) avoids the precision-loss
        // failure mode of `sin(2π × f × t)` for large t (a 1-hour
        // session at 220 Hz feeds sin() arguments of ~1.4 million,
        // where Double precision starts to fray).
        nonisolated(unsafe) var carrierPhase: Double  = 0
        nonisolated(unsafe) var envelopePhase: Double = 0
        nonisolated(unsafe) var breathLFOPhase: Double = 0
        nonisolated(unsafe) var driftLFOPhase: Double  = 0

        // Per-node ring buffer for Layer 2 phase-drift delay on R channel.
        // Size 1024 = ~23 ms at 44.1 kHz; Layer 2 max delay is ~3.5 ms.
        // Plenty of margin and a power of 2 makes wrap math fast.
        let ringBufferSize = 1024
        nonisolated(unsafe) var ringBuffer = [Float](repeating: 0, count: ringBufferSize)
        nonisolated(unsafe) var ringWriteIdx: Int = 0

        // LFO rates (Hz) — stored once, not recomputed per render block.
        let breathLfoHz: Double = 1.0 / 24.0   // 0.0417 Hz
        let driftLfoHz:  Double = 1.0 / 40.0   // 0.0250 Hz

        // LFO depths
        let breathDepthHz: Double = 4.0        // ±4 Hz around carrier
        let maxDelaySamples: Double = 0.0035 * sr  // 3.5 ms

        // Per-sample LFO phase increments (cycles per sample).
        let breathInc = breathLfoHz / sr
        let driftInc  = driftLfoHz  / sr

        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            // Snapshot shared parameters once per render block. Reading
            // them per-sample would be wasteful — they're slow-moving.
            // Tearing is irrelevant: we get a consistent value within
            // the block, which is all the synthesis needs.
            let baseCarrier = driftStateRef.carrierHz
            let isoHz       = driftStateRef.isochronicHz
            let breathOn    = driftStateRef.layerBreathingCarrier
            let driftOn     = driftStateRef.layerPhaseDrift

            // Per-sample increments for envelope and (nominal) carrier.
            // The carrier increment changes per sample when the breath
            // LFO is active (since effective frequency varies); without
            // breath LFO it's constant.
            let envelopeInc = isoHz / sr

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2 else { return noErr }
            let outL = abl[0].mData!.assumingMemoryBound(to: Float.self)
            let outR = abl[1].mData!.assumingMemoryBound(to: Float.self)

            let ringSizeD = Double(ringBufferSize)
            let frameCountInt = Int(frameCount)

            for frame in 0..<frameCountInt {
                // Layer 1: breathing-carrier LFO drives the carrier
                // frequency offset. ±4 Hz around base over a 24 s cycle.
                let breathOffsetHz: Double
                if breathOn {
                    breathOffsetHz = Double(sineLookup(breathLFOPhase)) * breathDepthHz
                } else {
                    breathOffsetHz = 0
                }

                // Effective carrier this sample (Hz) → per-sample phase
                // increment in cycles. Phase accumulates without precision
                // drift over arbitrary session length.
                let effectiveCarrierHz = baseCarrier + breathOffsetHz + detuneHz
                let carrierInc = effectiveCarrierHz / sr

                // Carrier sample via LUT.
                let carrierSample = sineLookup(carrierPhase)

                // Isochronic AM envelope: half-rectified sine at isoHz.
                let envRaw = sineLookup(envelopePhase)
                let envSample = envRaw > 0 ? envRaw : 0

                let mono = carrierSample * envSample

                // Advance phases for next sample.
                carrierPhase  += carrierInc
                if carrierPhase >= 1.0  { carrierPhase  -= floor(carrierPhase) }
                envelopePhase += envelopeInc
                if envelopePhase >= 1.0 { envelopePhase -= floor(envelopePhase) }
                breathLFOPhase += breathInc
                if breathLFOPhase >= 1.0 { breathLFOPhase -= floor(breathLFOPhase) }
                driftLFOPhase += driftInc
                if driftLFOPhase >= 1.0  { driftLFOPhase -= floor(driftLFOPhase) }

                // Layer 2: phase-drift delay on R channel.
                // Delay rotates 0 → maxDelay → 0 each cycle: (1 − cos)/2.
                let normalizedDrift: Double
                if driftOn {
                    let cosVal = Double(cosineLookup(driftLFOPhase))
                    normalizedDrift = (1.0 - cosVal) * 0.5
                } else {
                    normalizedDrift = 0
                }
                let delaySamples = normalizedDrift * maxDelaySamples

                // Write current sample into ring, then read delayed for R.
                ringBuffer[ringWriteIdx] = mono

                let readPos = Double(ringWriteIdx) - delaySamples
                let readPosWrapped = readPos < 0 ? readPos + ringSizeD : readPos
                let readIdxLow = Int(readPosWrapped) & (ringBufferSize - 1)
                let readIdxHigh = (readIdxLow + 1) & (ringBufferSize - 1)
                let frac = Float(readPosWrapped - Double(Int(readPosWrapped)))
                let rSample = ringBuffer[readIdxLow] * (1 - frac)
                            + ringBuffer[readIdxHigh] * frac

                outL[frame] = mono
                outR[frame] = rSample

                ringWriteIdx = (ringWriteIdx + 1) & (ringBufferSize - 1)
            }

            // Publish LFO phases for the BLOOM visual layer. Only the
            // main carrier node writes — Layer 3 shimmer nodes are
            // render-only consumers, so there's a single source of truth.
            if isMainNode {
                driftStateRef.breathingCarrierPhase = breathLFOPhase
                driftStateRef.phaseDriftPhase       = driftLFOPhase
                if driftStateRef.layerHarmonicShimmer {
                    // Beat phase mirrors envelope phase (1 Hz nominal).
                    driftStateRef.harmonicShimmerPhase = envelopePhase
                } else {
                    driftStateRef.harmonicShimmerPhase = 0
                }
            }

            return noErr
        }
    }
}
// ========== BLOCK 35: DriftAudioEngine - END ==========
