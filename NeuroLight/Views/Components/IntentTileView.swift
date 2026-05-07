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

            Text(state.displayName)
                .font(.system(size: 13, weight: .semibold))
                .tracking(6)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .contentShape(Rectangle())
    }
}
// ========== BLOCK 16: IntentTileView (presentation-only) - END ==========
