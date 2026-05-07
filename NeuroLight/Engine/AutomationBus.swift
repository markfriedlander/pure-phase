// ========== BLOCK 18: AutomationBus - START ==========
//
//  AutomationBus.swift
//  NeuroLight
//
//  The single coordination point for the debug-only HTTP automation
//  layer. Views register their interactive elements here so they can
//  be triggered by accessibility identifier; views also publish their
//  current screen and the active SessionEngine so the server can read
//  full telemetry.
//
//  Always compiled — the bus is also the path Begin uses to ask the
//  router to present a SessionView, in both Debug and Release builds.
//  Only the HTTP server is DEBUG-gated.
//

import Foundation
import Observation

@MainActor
@Observable
final class AutomationBus {
    static let shared = AutomationBus()

    // MARK: Telemetry — kept current by views as they appear/disappear
    var currentScreen: String = "loading"
    var currentEngine: SessionEngine? = nil
    var currentConfig: SessionConfig? = nil
    var lastEvent: String = ""
    var bootedAt: Date = Date()

    // Breath cue verification
    var breathCueFireCount: Int = 0
    var lastBreathCueStage: String = ""
    var lastBreathCueAt: Date? = nil

    // Audio output verification — measured by a tap on the main mixer.
    // If maxAudioPeak stays at 0 across a session, NOTHING is being
    // emitted from the speaker, regardless of whether buffers were
    // scheduled. This is the only honest signal that audio works.
    var lastAudioPeak: Float = 0
    var maxAudioPeak: Float = 0
    var audioPeakSampleCount: Int = 0
    var audioEngineRunning: Bool = false
    var audioMixerVolume: Float = 0
    var audioCueNodePlaying: Bool = false
    var audioIsoNodePlaying: Bool = false
    var audioAmbientNodePlaying: Bool = false
    var audioSessionCategory: String = ""
    var audioLastError: String = ""

    /// Bumped when a breath cue is fired by SessionView.
    func recordBreathCue(stage: String) {
        breathCueFireCount += 1
        lastBreathCueStage = stage
        lastBreathCueAt = Date()
    }

    func recordAudioPeak(_ peak: Float) {
        lastAudioPeak = peak
        if peak > maxAudioPeak { maxAudioPeak = peak }
        audioPeakSampleCount += 1
    }

    func resetAudioMetrics() {
        lastAudioPeak = 0
        maxAudioPeak = 0
        audioPeakSampleCount = 0
        audioEngineRunning = false
        audioMixerVolume = 0
        audioCueNodePlaying = false
        audioIsoNodePlaying = false
        audioAmbientNodePlaying = false
        audioLastError = ""
    }

    // MARK: Requests — set by the server, observed by ContentView
    var requestedConfigState: String? = nil   // a BrainwaveState.id
    var requestedSession: SessionConfig? = nil
    var requestedRoute: NavigationRoute? = nil
    var dismissTicket: Int = 0                // bump to dismiss session
    var popToRootTicket: Int = 0              // bump to pop the nav stack

    // MARK: Action registry
    // Views call register(_:_:) on appear and unregister(_:) on disappear.
    // The server resolves accessibility identifiers to actions here.
    private var actions: [String: () -> Void] = [:]

    func register(_ id: String, _ action: @escaping () -> Void) {
        actions[id] = action
        lastEvent = "registered \(id)"
    }

    func unregister(_ id: String) {
        actions.removeValue(forKey: id)
    }

    @discardableResult
    func fire(_ id: String) -> Bool {
        guard let action = actions[id] else { return false }
        action()
        lastEvent = "fired \(id)"
        return true
    }

    func registeredActions() -> [String] {
        Array(actions.keys).sorted()
    }

    // MARK: Convenience telemetry snapshot
    struct EngineSnapshot: Codable {
        let isRunning: Bool
        let flickerPhase: Bool
        let breathPhase: Double
        let breathStageName: String
        let sessionProgress: Double?
        let brightness: Double
        let elapsed: Double
        let remaining: Double?
    }

    func engineSnapshot() -> EngineSnapshot? {
        guard let e = currentEngine else { return nil }
        return EngineSnapshot(
            isRunning: e.isRunning,
            flickerPhase: e.flickerPhase,
            breathPhase: e.breathPhase,
            breathStageName: e.breathStageName,
            sessionProgress: e.sessionProgress,
            brightness: e.brightness,
            elapsed: e.elapsed,
            remaining: e.remaining
        )
    }
}
// ========== BLOCK 18: AutomationBus - END ==========
