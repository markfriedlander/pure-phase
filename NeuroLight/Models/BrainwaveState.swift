// ========== BLOCK 1: BrainwaveState - START ==========
//
//  BrainwaveState.swift
//  NeuroLight
//
//  Defines the catalog of brainwave entrainment states. Three primary
//  evidence-backed states (Focus / Calm / Sleep) plus an advanced tier.
//

import SwiftUI

nonisolated enum EvidenceTier: String, Hashable, Codable {
    case primary
    case advanced
}

nonisolated struct BrainwaveState: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let hz: Double
    let description: String
    let evidenceTier: EvidenceTier
    let sessionTint: SessionTint
    let allowTorch: Bool
    let driftEnabled: Bool
    let carrierHz: Double
}

nonisolated struct SessionTint: Hashable, Codable {
    let startHex: UInt32
    let endHex: UInt32

    var startColor: Color { Color(hex: startHex) }
    var endColor: Color { Color(hex: endHex) }
    var dominantColor: Color { startColor }
    var gradient: LinearGradient {
        LinearGradient(
            colors: [startColor, endColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    nonisolated init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

extension BrainwaveState {

    // Primary tier — evidence-backed, surfaced on home screen.

    static let focus = BrainwaveState(
        id: "focus",
        displayName: "FOCUS",
        hz: 40.0,
        description: "Gamma entrainment for sustained attention and cognitive clarity.",
        evidenceTier: .primary,
        sessionTint: SessionTint(startHex: 0xF5A623, endHex: 0xC0392B),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 220.0
    )

    static let calm = BrainwaveState(
        id: "calm",
        displayName: "CALM",
        hz: 10.0,
        description: "Alpha entrainment for relaxed, non-anxious awareness.",
        evidenceTier: .primary,
        sessionTint: SessionTint(startHex: 0xD9824A, endHex: 0x8B3A2A),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 174.0
    )

    static let sleep = BrainwaveState(
        id: "sleep",
        displayName: "SLEEP",
        hz: 2.0,
        description: "Delta entrainment to ease the transition into sleep.",
        evidenceTier: .primary,
        sessionTint: SessionTint(startHex: 0x8B2E1F, endHex: 0x1A0503),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 136.0
    )

    // Advanced tier — exploratory, behind the Advanced panel.

    static let theta = BrainwaveState(
        id: "theta",
        displayName: "THETA",
        hz: 6.0,
        description: "Deep meditative and dreamlike states. Photic evidence is limited.",
        evidenceTier: .advanced,
        sessionTint: SessionTint(startHex: 0xC4682E, endHex: 0x6B2818),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 160.0
    )

    static let smr = BrainwaveState(
        id: "smr",
        displayName: "SMR",
        hz: 13.5,
        description: "Calm alertness. Strong neurofeedback data, less photic evidence.",
        evidenceTier: .advanced,
        sessionTint: SessionTint(startHex: 0xE8C547, endHex: 0xA8841F),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 196.0
    )

    // PRISM (renamed from Psychedelic in 2.0). Behavior identical —
    // 8 Hz, ±20% drift on a 15 s cycle, warm hue rotation. Renamed for
    // a cleaner one-syllable tile label and to avoid the loaded
    // connotations of the prior name. Identifier changed too so all
    // string-keyed lookups and the automation surface use "prism".
    static let prism = BrainwaveState(
        id: "prism",
        displayName: "PRISM",
        hz: 8.0,
        description: "Visual drift in the theta range. Experiential, not clinical.",
        evidenceTier: .advanced,
        sessionTint: SessionTint(startHex: 0xE8593C, endHex: 0xA01F4C),
        allowTorch: true,
        driftEnabled: true,
        carrierHz: 180.0
    )

    static let voidState = BrainwaveState(
        id: "void",
        displayName: "VOID",
        hz: 0.5,
        description: "Sub-delta stillness. Almost no photic research. Experimental.",
        evidenceTier: .advanced,
        sessionTint: SessionTint(startHex: 0x3A1410, endHex: 0x080302),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 110.0
    )

    static let custom = BrainwaveState(
        id: "custom",
        displayName: "CUSTOM",
        hz: 10.0,
        description: "User-defined frequency and carrier.",
        evidenceTier: .advanced,
        sessionTint: SessionTint(startHex: 0xF5A623, endHex: 0xE8593C),
        allowTorch: true,
        driftEnabled: false,
        carrierHz: 174.0
    )

    /// Breath-only mode. No flicker, no torch, no isochronic tone — just
    /// the breath ring (with optional audio cues) and an optional
    /// ambient texture. Treated as a state for routing/automation
    /// uniformity, but `isBreathwork` flips the rendering branch.
    static let breathwork = BrainwaveState(
        id: "breathwork",
        displayName: "BREATHE",
        hz: 0,
        description: "Breath pacing without entrainment. The ring is the whole session.",
        evidenceTier: .primary,
        sessionTint: SessionTint(startHex: 0xE8AA5F, endHex: 0xC07432),
        allowTorch: false,
        driftEnabled: false,
        carrierHz: 0
    )

    static let primary: [BrainwaveState] = [.focus, .calm, .sleep]
    static let advanced: [BrainwaveState] = [.theta, .smr, .prism, .voidState, .custom]
    static let all: [BrainwaveState] = primary + advanced + [.breathwork]

    static func state(forID id: String) -> BrainwaveState? {
        all.first { $0.id == id }
    }

    // These are pure value-type checks — explicitly nonisolated so they
    // can be called from any context (including the nonisolated autoclosures
    // used in `SessionConfig.needsAudio`).
    nonisolated var isBreathwork: Bool { id == "breathwork" }
    nonisolated var isCustom: Bool { id == "custom" }

    /// For Custom state, returns a copy with the user's stored Hz and
    /// carrier. For all others, returns self unchanged.
    @MainActor
    func resolvingCustomValues() -> BrainwaveState {
        guard isCustom else { return self }
        let d = UserDefaults.standard
        let hz = (d.object(forKey: StorageKey.customHz) as? Double) ?? StorageDefault.customHz
        let carrier = (d.object(forKey: StorageKey.customCarrierHz) as? Double) ?? StorageDefault.customCarrierHz
        return BrainwaveState(
            id: id,
            displayName: displayName,
            hz: hz,
            description: description,
            evidenceTier: evidenceTier,
            sessionTint: sessionTint,
            allowTorch: allowTorch,
            driftEnabled: driftEnabled,
            carrierHz: carrier
        )
    }
}
// ========== BLOCK 1: BrainwaveState - END ==========
