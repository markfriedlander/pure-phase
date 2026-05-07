// ========== BLOCK 7: AppStorage Keys - START ==========
//
//  AppStorage+Keys.swift
//  NeuroLight
//
//  Centralized constants for every @AppStorage key in the app.
//  Single source of truth — never spell a key as a literal anywhere
//  else. Plain UserDefaults.standard is used everywhere; the original
//  iCloud-suite-name bug is fixed by simply not having a suite.
//

import Foundation

enum StorageKey {
    static let hasSeenOnboarding   = "hasSeenOnboarding"
    static let lastUsedStateID     = "lastUsedStateID"
    static let preferredDuration   = "preferredDuration"

    static let audioEnabled        = "audioEnabled"
    static let audioIsoVolume      = "audioIsoVolume"
    static let audioAmbientType    = "audioAmbientType"
    static let audioAmbientVolume  = "audioAmbientVolume"

    static let breathEnabled       = "breathEnabled"
    static let breathPresetName    = "breathPresetName"

    static let colorModeEnabled    = "colorModeEnabled"
    static let torchEnabled        = "torchEnabled"

    // Custom-state user values (used when state.id == "custom").
    static let customHz            = "customHz"
    static let customCarrierHz     = "customCarrierHz"

    // Custom breath pattern (used when breathPresetName == "Custom").
    static let customBreathInhale     = "customBreathInhale"
    static let customBreathInhaleHold = "customBreathInhaleHold"
    static let customBreathExhale    = "customBreathExhale"
    static let customBreathExhaleHold = "customBreathExhaleHold"

    // Breathwork-mode toggles.
    static let breathAudioCues     = "breathAudioCues"
    static let breathCueVolume     = "breathCueVolume"

    // One-time acknowledgment that user knows about rapid flicker
    // despite having Reduce Motion enabled. Persists once granted.
    static let ackReduceMotion     = "ackReduceMotion"
}

enum StorageDefault {
    // Mark-curated defaults (May 2026):
    // - duration: 10 min (Mark's preference; MIT studies used 20–40 but
    //   10 felt less committed for everyday use)
    // - audio on, iso 60%, ambient pink at 30% (combined audiovisual
    //   entrainment is stronger than either alone)
    // - breath on with Coherence (5/0/5/0, strongest HRV evidence)
    // - color mode off, torch off (deliberate opt-ins)
    // - breath cues on by default in breathwork mode (silence is jarring)
    static let preferredDuration: String  = SessionDuration.ten.rawValue
    static let audioEnabled: Bool         = true
    static let audioIsoVolume: Double     = 0.6
    static let audioAmbientType: String   = AmbientSoundType.pinkNoise.rawValue
    static let audioAmbientVolume: Double = 0.3
    static let breathEnabled: Bool        = true
    static let breathPresetName: String   = BreathPattern.coherence.name
    static let colorModeEnabled: Bool     = false
    static let torchEnabled: Bool         = false

    // Custom Hz / carrier defaults match the static .custom state.
    static let customHz: Double         = 10.0
    static let customCarrierHz: Double  = 174.0

    // Custom breath defaults to Coherence.
    static let customBreathInhale: Double      = 5.0
    static let customBreathInhaleHold: Double  = 0.0
    static let customBreathExhale: Double      = 5.0
    static let customBreathExhaleHold: Double  = 0.0

    static let breathAudioCues: Bool   = true   // on by default in breathwork mode
    static let breathCueVolume: Double = 0.7

    /// Resets every persisted Session-config value to its default.
    /// Called by the Restore Defaults button.
    @MainActor
    static func restoreAll() {
        let d = UserDefaults.standard
        d.set(preferredDuration,  forKey: StorageKey.preferredDuration)
        d.set(audioEnabled,       forKey: StorageKey.audioEnabled)
        d.set(audioIsoVolume,     forKey: StorageKey.audioIsoVolume)
        d.set(audioAmbientType,   forKey: StorageKey.audioAmbientType)
        d.set(audioAmbientVolume, forKey: StorageKey.audioAmbientVolume)
        d.set(breathEnabled,      forKey: StorageKey.breathEnabled)
        d.set(breathPresetName,   forKey: StorageKey.breathPresetName)
        d.set(colorModeEnabled,   forKey: StorageKey.colorModeEnabled)
        d.set(torchEnabled,       forKey: StorageKey.torchEnabled)
        d.set(customHz,           forKey: StorageKey.customHz)
        d.set(customCarrierHz,    forKey: StorageKey.customCarrierHz)
        d.set(customBreathInhale,     forKey: StorageKey.customBreathInhale)
        d.set(customBreathInhaleHold, forKey: StorageKey.customBreathInhaleHold)
        d.set(customBreathExhale,     forKey: StorageKey.customBreathExhale)
        d.set(customBreathExhaleHold, forKey: StorageKey.customBreathExhaleHold)
        d.set(breathAudioCues,    forKey: StorageKey.breathAudioCues)
        d.set(breathCueVolume,    forKey: StorageKey.breathCueVolume)
    }
}
// ========== BLOCK 7: AppStorage Keys - END ==========
