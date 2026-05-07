// ========== BLOCK 29: AudioEngine (cues + interruption) - START ==========
//
//  AudioEngine.swift
//  NeuroLight
//
//  Three layers of procedurally generated audio:
//
//   • Isochronic tone — audible carrier amplitude-modulated at the
//     brainwave target rate. The entrainment signal. Skipped in
//     breathwork mode.
//   • Ambient texture — pink/brown noise or a sustained drone.
//   • Breath cues (breathwork only) — a short pitched tone at each
//     phase transition. Inhale rises, exhale falls, hold sustains low.
//
//  All layers feed a master mixer whose outputVolume is driven by the
//  SessionEngine's fade envelope every tick — that gives us 3-second
//  fade-in and 30-second fade-out for free across every channel.
//
//  Interruptions (phone call, other audio) pause us cleanly. Resume on
//  end-of-interruption is best-effort: we restart the engine but don't
//  worry about phase realignment — the user won't notice.
//
//  No audio files. Everything is synthesized at start().
//

import AVFoundation
import Observation

@MainActor
@Observable
final class AudioEngine {

    private let engine = AVAudioEngine()
    private let isochronicNode = AVAudioPlayerNode()
    private let ambientNode    = AVAudioPlayerNode()
    private let cueNode        = AVAudioPlayerNode()
    private let mixer          = AVAudioMixerNode()

    private(set) var isRunning: Bool = false
    private(set) var wasInterrupted: Bool = false

    private let sampleRate: Double = 44_100
    private var nodesAttached: Bool = false
    private var lastConfig: SessionConfig? = nil
    private var format: AVAudioFormat? = nil

    // Pre-built cue buffers — created once per session in start(), then
    // reused on every transition. Keeps the cue path off the main-thread
    // PCM-synthesis hot loop.
    private var inhaleCue: AVAudioPCMBuffer? = nil
    private var exhaleCue: AVAudioPCMBuffer? = nil
    private var holdCue: AVAudioPCMBuffer? = nil

    // No interruption observer here — SessionEngine owns interruption
    // handling so it can pause/resume flicker, torch, and audio together.
    // It calls pauseForInterruption() / resumeFromInterruption() below.

    /// True when iOS reports another app is currently producing audio.
    /// Views can read this before starting a session and offer the user
    /// the choice to keep their music playing.
    static var isOtherAudioPlaying: Bool {
        #if !targetEnvironment(macCatalyst)
        return AVAudioSession.sharedInstance().isOtherAudioPlaying
        #else
        return false
        #endif
    }

    // MARK: Lifecycle

    func start(config: SessionConfig) {
        stop()
        lastConfig = config
        AutomationBus.shared.resetAudioMetrics()

        #if !targetEnvironment(macCatalyst)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
            AutomationBus.shared.audioSessionCategory = session.category.rawValue
        } catch {
            AutomationBus.shared.audioLastError = "session setup: \(error.localizedDescription)"
        }
        #endif

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        self.format = fmt

        engine.attach(isochronicNode)
        engine.attach(ambientNode)
        engine.attach(cueNode)
        engine.attach(mixer)
        engine.connect(isochronicNode, to: mixer, format: fmt)
        engine.connect(ambientNode,    to: mixer, format: fmt)
        engine.connect(cueNode,        to: mixer, format: fmt)
        engine.connect(mixer, to: engine.mainMixerNode, format: fmt)
        nodesAttached = true

        isochronicNode.volume = Float(config.isoVolume)
        ambientNode.volume    = Float(config.ambientVolume)
        cueNode.volume        = Float(config.breathCueVolume)
        mixer.outputVolume    = 0  // SessionEngine ramps via setEnvelope

        // Isochronic — entrainment only. Breathwork sessions skip this.
        if config.audioEnabled && !config.state.isBreathwork {
            if let isoBuf = makeIsochronicBuffer(
                carrierHz: config.state.carrierHz,
                pulseHz: config.state.hz,
                format: fmt
            ) {
                isochronicNode.scheduleBuffer(isoBuf, at: nil, options: .loops, completionHandler: nil)
            }
        }

        // Ambient — available in both modes.
        if config.ambientType != .off,
           let ambBuf = makeAmbientBuffer(type: config.ambientType, format: fmt) {
            ambientNode.scheduleBuffer(ambBuf, at: nil, options: .loops, completionHandler: nil)
        }

        // Pre-build breath cue buffers once. Avoids ~1–2 ms of PCM
        // synthesis on the main thread at every breath transition,
        // which produced a perceptible micro-stutter at loop boundaries.
        if config.state.isBreathwork {
            inhaleCue = makeCueBuffer(stage: "Inhale", format: fmt)
            exhaleCue = makeCueBuffer(stage: "Exhale", format: fmt)
            holdCue   = makeCueBuffer(stage: "Hold",   format: fmt)
        }

        // Prepare the engine before starting — this is recommended on
        // iOS to make sure all nodes are wired and rendering is ready.
        engine.prepare()

        #if DEBUG
        // Install a tap on the main mixer ONLY in debug builds so we
        // can verify audio output amplitude via /state. The tap fires
        // on the audio render thread; we throttle the @MainActor hop
        // so it doesn't compete for frame time with 40 Hz Focus
        // flicker. Larger buffer (4096 ≈ 93 ms at 44.1 kHz) means
        // ~10 callbacks per second instead of ~50, plus we only
        // forward every 2nd peak — net ~5 main-thread updates / sec.
        let tapFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        var tapCount = 0
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
            let peak = AudioEngine.peakAmplitude(buffer)
            tapCount += 1
            guard tapCount % 2 == 0 else { return }
            Task { @MainActor in
                AutomationBus.shared.recordAudioPeak(peak)
            }
        }
        #endif

        do {
            try engine.start()
            AutomationBus.shared.audioEngineRunning = engine.isRunning
            if config.audioEnabled && !config.state.isBreathwork {
                isochronicNode.play()
            }
            if config.ambientType != .off {
                ambientNode.play()
            }
            // Cue node is started lazily inside playBreathCue — calling
            // play() on a player node with no scheduled buffers can
            // make subsequent scheduleBuffer(at: nil) miss the timing
            // window. Schedule-then-play is the safer order.
            AutomationBus.shared.audioIsoNodePlaying = isochronicNode.isPlaying
            AutomationBus.shared.audioAmbientNodePlaying = ambientNode.isPlaying
            AutomationBus.shared.audioCueNodePlaying = cueNode.isPlaying
            isRunning = true
        } catch {
            AutomationBus.shared.audioLastError = "engine start: \(error.localizedDescription)"
            isRunning = false
        }
    }

    /// Live audio diagnostics read at query time — no caching lag.
    func liveDiagnostics() -> [String: Any] {
        var d: [String: Any] = [
            "engineRunning": engine.isRunning,
            "isoNodePlaying": isochronicNode.isPlaying,
            "ambientNodePlaying": ambientNode.isPlaying,
            "cueNodePlaying": cueNode.isPlaying,
            "engineAttached": nodesAttached,
            "isoBufferSampleRate": isochronicNode.engine != nil ? "attached" : "detached"
        ]
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        d["mainMixerSampleRate"] = outputFormat.sampleRate
        d["mainMixerChannels"] = Int(outputFormat.channelCount)
        #if !targetEnvironment(macCatalyst)
        let session = AVAudioSession.sharedInstance()
        d["liveCategory"] = session.category.rawValue
        d["liveMode"] = session.mode.rawValue
        d["isOtherAudioPlaying"] = session.isOtherAudioPlaying
        d["outputVolume"] = session.outputVolume
        d["currentRoute"] = session.currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
        #endif
        return d
    }

    private static func peakAmplitude(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var peak: Float = 0
        for c in 0..<channelCount {
            let ptr = data[c]
            for i in 0..<frameCount {
                let v = abs(ptr[i])
                if v > peak { peak = v }
            }
        }
        return peak
    }

    func stop() {
        if isRunning {
            #if DEBUG
            engine.mainMixerNode.removeTap(onBus: 0)
            #endif
            isochronicNode.stop()
            ambientNode.stop()
            cueNode.stop()
            engine.stop()
        }

        if nodesAttached {
            engine.detach(isochronicNode)
            engine.detach(ambientNode)
            engine.detach(cueNode)
            engine.detach(mixer)
            nodesAttached = false
        }

        isRunning = false
        lastConfig = nil
        format = nil
        inhaleCue = nil
        exhaleCue = nil
        holdCue = nil

        #if !targetEnvironment(macCatalyst)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// Called every SessionEngine tick — applies the master fade
    /// envelope to the mixer's output volume.
    func setEnvelope(_ value: Double) {
        let v = Float(max(0, min(1, value)))
        mixer.outputVolume = v
        AutomationBus.shared.audioMixerVolume = v
    }

    // MARK: Breath cues

    /// Schedule a short pitched cue tone for the given breath stage.
    /// Inhale rises (260→440 Hz), exhale falls (440→260 Hz), hold is a
    /// sustained low tone (220 Hz). All ~200 ms with soft attack/decay.
    /// Buffers are pre-built in start() — this is just a schedule call.
    func playBreathCue(stage: String, volume: Double) {
        guard isRunning else { return }
        let buf: AVAudioPCMBuffer?
        switch stage {
        case "Inhale": buf = inhaleCue
        case "Exhale": buf = exhaleCue
        case "Hold":   buf = holdCue
        default:       buf = nil
        }
        guard let buffer = buf else { return }
        cueNode.volume = Float(max(0, min(1, volume)))
        // Schedule first, then start (or kick) the player.
        cueNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !cueNode.isPlaying {
            cueNode.play()
        }
        AutomationBus.shared.audioCueNodePlaying = cueNode.isPlaying
    }

    private func makeCueBuffer(stage: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let kind: CueKind
        switch stage {
        case "Inhale": kind = .rising
        case "Exhale": kind = .falling
        case "Hold":   kind = .sustainedLow
        default:       return nil
        }

        let duration: Double = (kind == .sustainedLow) ? 0.18 : 0.22
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?.pointee else { return nil }

        let total = Int(frameCount)
        let attack = min(0.012, duration * 0.2)
        let release = min(0.060, duration * 0.4)
        let attackFrames = Int(attack * sampleRate)
        let releaseFrames = Int(release * sampleRate)

        for i in 0..<total {
            let t = Double(i) / sampleRate
            let progress = t / duration

            let freq: Double
            switch kind {
            case .rising:        freq = 260 + (440 - 260) * progress
            case .falling:       freq = 440 - (440 - 260) * progress
            case .sustainedLow:  freq = 220
            }

            // Phase integration so frequency sweep is glitch-free
            // (we approximate by sampling the instantaneous frequency).
            let phase = 2.0 * .pi * freq * t
            var sample = sin(phase)

            // Soft envelope (attack/release) to avoid click.
            var env = 1.0
            if i < attackFrames {
                env = Double(i) / Double(attackFrames)
            } else if i > total - releaseFrames {
                env = Double(total - i) / Double(releaseFrames)
            }
            sample *= env * 0.85
            data[i] = Float(sample)
        }
        return buffer
    }

    private enum CueKind { case rising, falling, sustainedLow }

    // MARK: Isochronic buffer

    private func makeIsochronicBuffer(
        carrierHz: Double,
        pulseHz: Double,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard pulseHz > 0, carrierHz > 0 else { return nil }
        let cyclesPerLoop = max(1, Int(round(pulseHz)))
        let bufferDuration = Double(cyclesPerLoop) / pulseHz
        let frameCount = AVAudioFrameCount(bufferDuration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?.pointee else { return nil }

        let pulsePeriod = 1.0 / pulseHz
        let onDuration = pulsePeriod * 0.5
        let attack = min(0.002, onDuration * 0.2)
        let decay = attack
        let twoPiC = 2.0 * .pi * carrierHz

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let phaseInPulse = t.truncatingRemainder(dividingBy: pulsePeriod)
            let env: Double
            if phaseInPulse < attack {
                env = phaseInPulse / attack
            } else if phaseInPulse < onDuration - decay {
                env = 1
            } else if phaseInPulse < onDuration {
                env = (onDuration - phaseInPulse) / decay
            } else {
                env = 0
            }
            data[i] = Float(sin(twoPiC * t) * env * 0.6)
        }
        return buffer
    }

    // MARK: Ambient buffers

    private func makeAmbientBuffer(
        type: AmbientSoundType,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        switch type {
        case .off:        return nil
        case .pinkNoise:  return makeNoiseBuffer(.pink, format: format)
        case .brownNoise: return makeNoiseBuffer(.brown, format: format)
        case .drone:      return makeDroneBuffer(format: format)
        }
    }

    private enum NoiseKind { case pink, brown }

    private func makeNoiseBuffer(_ kind: NoiseKind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let bufferDuration: Double = 10
        let frameCount = AVAudioFrameCount(bufferDuration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?.pointee else { return nil }
        let total = Int(frameCount)

        switch kind {
        case .pink:
            let numRows = 16
            var rows = [Double](repeating: 0, count: numRows)
            var runningSum: Double = 0
            var counter: UInt32 = 0
            for i in 0..<total {
                counter &+= 1
                let row = min(counter.trailingZeroBitCount, numRows - 1)
                let newValue = Double.random(in: -1...1)
                runningSum -= rows[row]
                runningSum += newValue
                rows[row] = newValue
                let white = Double.random(in: -1...1)
                let pink = (runningSum + white) / Double(numRows + 1)
                data[i] = Float(pink * 0.4)
            }
        case .brown:
            var lastOut: Double = 0
            for i in 0..<total {
                let white = Double.random(in: -1...1)
                lastOut = (lastOut + 0.02 * white) * 0.995
                data[i] = Float(lastOut * 6.0)
            }
        }

        let fadeFrames = min(2048, total / 4)
        for i in 0..<fadeFrames {
            let f = Float(i) / Float(fadeFrames)
            data[i] *= f
            data[total - 1 - i] *= f
        }
        return buffer
    }

    private func makeDroneBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let droneHz: Double = 110
        let frameCount = AVAudioFrameCount(sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?.pointee else { return nil }
        let twoPiC = 2.0 * .pi * droneHz
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            data[i] = Float(sin(twoPiC * t) * 0.3)
        }
        return buffer
    }

    // MARK: Pause / resume (driven by SessionEngine on interruption)

    func pauseForInterruption() {
        guard isRunning else { return }
        isochronicNode.pause()
        ambientNode.pause()
        cueNode.pause()
        engine.pause()
        wasInterrupted = true
    }

    func resumeFromInterruption() {
        guard wasInterrupted else { return }
        wasInterrupted = false
        #if !targetEnvironment(macCatalyst)
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        #endif
        try? engine.start()
        isochronicNode.play()
        ambientNode.play()
        cueNode.play()
    }
}
// ========== BLOCK 29: AudioEngine (cues + interruption) - END ==========
