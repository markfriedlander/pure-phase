// ========== BLOCK 3: SessionConfig - START ==========
//
//  SessionConfig.swift
//  NeuroLight
//
//  The full configuration for a single session: which state, how long,
//  what audio, what breath pacing, and which visual modes are active.
//

import Foundation

nonisolated enum SessionDuration: String, CaseIterable, Hashable, Codable, Identifiable {
    case five
    case ten
    case twenty
    case forty
    case open

    var id: String { rawValue }

    /// Length in minutes. `nil` means "no time limit — runs until exit".
    var minutes: Double? {
        switch self {
        case .five:   return 5
        case .ten:    return 10
        case .twenty: return 20
        case .forty:  return 40
        case .open:   return nil
        }
    }

    var displayLabel: String {
        switch self {
        case .five:   return "5 min"
        case .ten:    return "10 min"
        case .twenty: return "20 min"
        case .forty:  return "40 min"
        case .open:   return "Open"
        }
    }

    /// Whether the engine should run a fade-out near the end. Open mode
    /// has no scheduled end, so it never fades.
    var hasFadeOut: Bool {
        minutes != nil
    }
}

nonisolated enum AmbientSoundType: String, CaseIterable, Hashable, Codable, Identifiable {
    case pinkNoise
    case brownNoise
    case drone
    case off

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .pinkNoise:  return "Pink Noise"
        case .brownNoise: return "Brown Noise"
        case .drone:      return "Drone"
        case .off:        return "Off"
        }
    }
}

nonisolated struct SessionConfig: Hashable, Codable {
    var state: BrainwaveState
    var duration: SessionDuration

    var audioEnabled: Bool
    var isoVolume: Double
    var ambientType: AmbientSoundType
    var ambientVolume: Double

    var breathEnabled: Bool
    var breathPattern: BreathPattern

    var colorModeEnabled: Bool
    var torchEnabled: Bool

    /// Breath-only sessions: play short tones at each breath phase
    /// transition. Ignored when state.isBreathwork is false (entrainment
    /// has its own audio bed).
    var breathAudioCues: Bool = false
    var breathCueVolume: Double = 0.45

    /// True if any audio layer is active in this config — isochronic
    /// tone, ambient texture, or breathwork cues. SessionEngine uses
    /// this to decide whether to bring the AudioEngine up at all
    /// (avoiding taking over the audio session when nothing will play).
    var needsAudio: Bool {
        audioEnabled || ambientType != .off || (state.isBreathwork && breathAudioCues)
    }
}

extension SessionConfig {

    /// The universal default starting point for a session. Tweaks happen
    /// in the Session Config screen before the user taps Begin.
    static func `default`(for state: BrainwaveState) -> SessionConfig {
        let isBreathwork = state.id == "breathwork"
        return SessionConfig(
            state: state,
            duration: .ten,
            audioEnabled: !isBreathwork,
            isoVolume: 0.6,
            ambientType: isBreathwork ? .off : .pinkNoise,
            ambientVolume: 0.3,
            breathEnabled: true,
            breathPattern: .default,
            colorModeEnabled: false,
            torchEnabled: false,
            // Breathwork defaults cues ON — silence in a breath-only
            // session is jarring. User can turn them off in config.
            breathAudioCues: isBreathwork,
            breathCueVolume: StorageDefault.breathCueVolume
        )
    }

    /// Build a SessionConfig from whatever the user last set in the
    /// Session Config screen, falling back to the universal default for
    /// any value that was never written. This is what single-tap-to-
    /// start uses on the home and advanced tiles. For Custom state it
    /// reads the live Hz/carrier values; for any state it uses the
    /// stored breath pattern (including the runtime "Custom" pattern).
    @MainActor
    static func fromAppStorage(state: BrainwaveState) -> SessionConfig {
        let d = UserDefaults.standard
        let resolvedState = state.resolvingCustomValues()
        let baseDefault = SessionConfig.default(for: resolvedState)

        let durationRaw = d.string(forKey: StorageKey.preferredDuration) ?? baseDefault.duration.rawValue
        let duration = SessionDuration(rawValue: durationRaw) ?? baseDefault.duration

        let ambientRaw = d.string(forKey: StorageKey.audioAmbientType) ?? baseDefault.ambientType.rawValue
        let ambient = AmbientSoundType(rawValue: ambientRaw) ?? baseDefault.ambientType

        let breathName = d.string(forKey: StorageKey.breathPresetName) ?? baseDefault.breathPattern.name
        let breath = BreathPattern.preset(named: breathName) ?? baseDefault.breathPattern

        return SessionConfig(
            state: resolvedState,
            duration: duration,
            audioEnabled: (d.object(forKey: StorageKey.audioEnabled) as? Bool) ?? baseDefault.audioEnabled,
            isoVolume: (d.object(forKey: StorageKey.audioIsoVolume) as? Double) ?? baseDefault.isoVolume,
            ambientType: ambient,
            ambientVolume: (d.object(forKey: StorageKey.audioAmbientVolume) as? Double) ?? baseDefault.ambientVolume,
            breathEnabled: (d.object(forKey: StorageKey.breathEnabled) as? Bool) ?? baseDefault.breathEnabled,
            breathPattern: breath,
            colorModeEnabled: (d.object(forKey: StorageKey.colorModeEnabled) as? Bool) ?? baseDefault.colorModeEnabled,
            torchEnabled: (d.object(forKey: StorageKey.torchEnabled) as? Bool) ?? baseDefault.torchEnabled,
            breathAudioCues: (d.object(forKey: StorageKey.breathAudioCues) as? Bool) ?? baseDefault.breathAudioCues,
            breathCueVolume: (d.object(forKey: StorageKey.breathCueVolume) as? Double) ?? baseDefault.breathCueVolume
        )
    }
}
// ========== BLOCK 3: SessionConfig - END ==========
