// ========== BLOCK 16: IntentTileView (presentation-only) - START ==========
//
//  IntentTileView.swift
//  NeuroLight
//
//  Pure presentation. Hit testing belongs to the parent (NavigationLink).
//  This view contains no Button, no gestures — wrapping it in a Button
//  or attaching gestures would compete with the NavigationLink for
//  taps and silently swallow them, which is what shipped originally.
//

import SwiftUI

struct IntentTileView: View {
    let state: BrainwaveState
    let symbolName: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(state.sessionTint.gradient)
                .shadow(color: state.sessionTint.startColor.opacity(0.32), radius: 14)
                .frame(height: 80)
                .accessibilityHidden(true)  // glyph is decorative; the label below carries the meaning

            Text(state.displayName)
                .font(.system(size: 13, weight: .semibold))
                .tracking(6)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double tap to begin a session.")
    }

    /// Per-state spoken label, more descriptive than the visible
    /// wordmark. Used for VoiceOver only.
    private var accessibilityLabelText: String {
        switch state.id {
        case "breathwork":  return "Breathe — guided breathwork, no flicker"
        case "focus":       return "Focus — 40 hertz visual flicker, gamma frequency"
        case "calm":        return "Calm — 10 hertz visual flicker, alpha frequency"
        case "sleep":       return "Sleep — 2 hertz visual flicker, delta frequency"
        case "theta":       return "Theta — 6 hertz, advanced"
        case "smr":         return "SMR — 13.5 hertz, advanced"
        case "psychedelic": return "Psychedelic — 8 hertz, advanced"
        case "void":        return "Void — half hertz, experimental"
        case "custom":      return "Custom — user-defined frequency, advanced"
        default:            return state.displayName
        }
    }
}
// ========== BLOCK 16: IntentTileView (presentation-only) - END ==========
