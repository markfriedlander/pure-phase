// ========== BLOCK 30: TileGesture (Button + simultaneous LongPress) - START ==========
//
//  TileGesture.swift
//  NeuroLight
//
//  Tap = start, long press (~½ s) = open config.
//
//  Implementation: a Button (which plays nicely with the enclosing
//  ScrollView's pan gesture) provides the tap. A simultaneous
//  LongPressGesture rides alongside; when it fires it sets a flag so
//  the Button's tap action knows to skip its own work. A press-state
//  custom ButtonStyle provides the subtle scale + opacity feedback
//  without interfering with hit-testing.
//
//  History: a previous version composed DragGesture + LongPressGesture
//  + TapGesture all on a non-button view. That fought ScrollView's pan
//  and broke navigation outright on device — sim was misleading because
//  the test path bypassed gestures entirely (the API fires actions
//  directly via the bus). Lesson: ALWAYS validate gestures with real
//  touches, not just the action registry.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    func tileGesture(onTap: @escaping () -> Void, onLongPress: @escaping () -> Void) -> some View {
        self.modifier(TileGestureModifier(onTap: onTap, onLongPress: onLongPress))
    }
}

private struct TileGestureModifier: ViewModifier {
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var didLongPress: Bool = false

    func body(content: Content) -> some View {
        Button {
            // If a long press already fired during this touch, swallow
            // the tap. Reset the flag so the next touch starts fresh.
            if didLongPress {
                didLongPress = false
            } else {
                onTap()
            }
        } label: {
            content
        }
        .buttonStyle(TilePressStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    didLongPress = true
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    onLongPress()
                }
        )
        // VoiceOver users can't easily hold to long-press, so we expose
        // "Configure" as a custom action. The default tap action runs
        // onTap (start session); the rotor-selectable Configure runs
        // onLongPress (open the config screen for this state).
        .accessibilityAction(named: Text("Configure")) {
            onLongPress()
        }
    }
}

/// Subtle press feedback — slight scale + opacity dim. Replaces the
/// custom DragGesture(minimumDistance: 0) approach which was eating
/// touches that ScrollView needed for panning.
private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}
// ========== BLOCK 30: TileGesture (Button + simultaneous LongPress) - END ==========
