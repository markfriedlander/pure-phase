// ========== BLOCK 39: TVTileButton (focus-aware) - START ==========
//
//  TVTileButton.swift
//  NeuroLightTV
//
//  Focus-aware tile for the TV home screen. tvOS Buttons get focus
//  automatically; we use the focus state to brighten the glyph and
//  add a subtle scale lift so the user always knows what's selected.
//
//  Visual vocabulary mirrors the iOS IntentTileView: warm glyph
//  centered, label below, color tint pulled from the state's
//  sessionTint. On TV the proportions are bigger and the focus
//  affordance is the dominant interaction signal.
//

import SwiftUI

struct TVTileButton: View {
    let state: BrainwaveState
    let symbolName: String
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: 22) {
                Image(systemName: symbolName)
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(state.sessionTint.gradient)
                    .shadow(
                        color: state.sessionTint.startColor
                            .opacity(isFocused ? 0.6 : 0.2),
                        radius: isFocused ? 24 : 10
                    )
                    .frame(height: 110)

                Text(state.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(6)
                    .foregroundColor(.white.opacity(isFocused ? 1.0 : 0.7))
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .padding(.vertical, 36)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(isFocused ? 0.06 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        state.sessionTint.startColor.opacity(isFocused ? 0.55 : 0),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: isFocused)
        }
        .buttonStyle(.card)
        .accessibilityLabel(state.displayName)
        .accessibilityHint("Click to begin a \(state.displayName) session.")
    }
}
// ========== BLOCK 39: TVTileButton (focus-aware) - END ==========
