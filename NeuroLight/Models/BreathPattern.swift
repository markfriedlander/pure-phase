// ========== BLOCK 2: BreathPattern - START ==========
//
//  BreathPattern.swift
//  NeuroLight
//
//  Defines a four-phase breath cycle (inhale / inhale-hold / exhale /
//  exhale-hold) and the canonical preset patterns. Holds may be zero.
//

import Foundation

nonisolated struct BreathPattern: Hashable, Codable, Identifiable {
    let name: String
    let inhale: TimeInterval
    let inhaleHold: TimeInterval
    let exhale: TimeInterval
    let exhaleHold: TimeInterval

    var id: String { name }

    var cycleDuration: TimeInterval {
        inhale + inhaleHold + exhale + exhaleHold
    }

    var bpm: Double {
        guard cycleDuration > 0 else { return 0 }
        return 60.0 / cycleDuration
    }
}

extension BreathPattern {

    static let coherence = BreathPattern(
        name: "Coherence",
        inhale: 5, inhaleHold: 0, exhale: 5, exhaleHold: 0
    )

    static let fourSevenEight = BreathPattern(
        name: "4-7-8",
        inhale: 4, inhaleHold: 7, exhale: 8, exhaleHold: 0
    )

    static let box = BreathPattern(
        name: "Box",
        inhale: 4, inhaleHold: 4, exhale: 4, exhaleHold: 4
    )

    static let slowWave = BreathPattern(
        name: "Slow Wave",
        inhale: 6, inhaleHold: 0, exhale: 6, exhaleHold: 0
    )

    static let presets: [BreathPattern] = [.coherence, .fourSevenEight, .box, .slowWave]
    static let `default`: BreathPattern = .coherence

    /// Built from the user's saved custom durations. Falls back to
    /// Coherence values if nothing has been saved yet.
    @MainActor
    static func custom() -> BreathPattern {
        let d = UserDefaults.standard
        return BreathPattern(
            name: "Custom",
            inhale:     (d.object(forKey: StorageKey.customBreathInhale)     as? Double) ?? StorageDefault.customBreathInhale,
            inhaleHold: (d.object(forKey: StorageKey.customBreathInhaleHold) as? Double) ?? StorageDefault.customBreathInhaleHold,
            exhale:     (d.object(forKey: StorageKey.customBreathExhale)     as? Double) ?? StorageDefault.customBreathExhale,
            exhaleHold: (d.object(forKey: StorageKey.customBreathExhaleHold) as? Double) ?? StorageDefault.customBreathExhaleHold
        )
    }

    /// Includes the dynamic Custom pattern. Use this in Views that show
    /// every available choice; use `presets` when you need just the
    /// fixed canon (e.g. in the model layer's static catalog).
    @MainActor
    static func allChoices() -> [BreathPattern] {
        presets + [custom()]
    }

    /// Looks up by name. "Custom" returns the live custom pattern.
    @MainActor
    static func preset(named name: String) -> BreathPattern? {
        if name == "Custom" { return custom() }
        return presets.first { $0.name == name }
    }
}
// ========== BLOCK 2: BreathPattern - END ==========
