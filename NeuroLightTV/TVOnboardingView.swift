// ========== BLOCK 40: TVOnboardingView (safety gate) - START ==========
//
//  TVOnboardingView.swift
//  NeuroLightTV
//
//  First-launch safety acknowledgement on tvOS. Same legal/safety
//  content as iOS, restructured for focus-based navigation: one big
//  ENTER button at the bottom that the user clicks to acknowledge
//  and proceed.
//
//  The bystander-warning copy matters even more on TV — the flicker
//  fills the room's visual field. We surface that explicitly.
//

import SwiftUI

struct TVOnboardingView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xF5A623),
                                 Color(hex: 0xE8593C),
                                 Color(hex: 0xC0392B)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 320, height: 2)

                Text("PURE PHASE")
                    .font(.system(size: 56, weight: .bold))
                    .tracking(20)
                    .foregroundColor(.white)
            }
            .padding(.top, 80)

            Spacer()

            // Body copy
            VStack(alignment: .leading, spacing: 36) {
                Text("what this is")
                    .font(.system(size: 20, weight: .medium))
                    .tracking(5)
                    .foregroundColor(Color(hex: 0x888480))

                Text("Light, sound, and breath, used together to guide you toward focus, calm, or sleep. Useful for guided breathwork and meditation.")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(8)

                Text("before you begin")
                    .font(.system(size: 20, weight: .medium))
                    .tracking(5)
                    .foregroundColor(Color(hex: 0x888480))
                    .padding(.top, 24)

                Text("Pure Phase intentionally uses rapid rhythmic flicker — that's how visual entrainment works. The Focus, Calm, Sleep, Drift, and Bloom modes are not designed for users with photosensitivity, seizure history, vestibular disorders, motion sensitivity, or significant vision impairment. The Breathe mode has no flicker and is usable by anyone.\n\nOn a TV the flicker fills the room's visual field — anyone in the room is exposed, not just the person interacting. Make sure others present are comfortable before starting an entrainment session. Drift and Bloom are non-stroboscopic and safe for photosensitive viewers.\n\nThis is not a medical device and makes no medical claims.")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(hex: 0xC0392B))
                    .lineSpacing(7)
            }
            .padding(.horizontal, 200)
            .frame(maxWidth: 1400)

            Spacer()

            // Single ENTER button — TV equivalent of the iOS checkbox + ENTER.
            Button(action: onAccept) {
                Text("I UNDERSTAND — ENTER")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(8)
                    .foregroundColor(.white)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 80)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xF5A623),
                                     Color(hex: 0xE8593C),
                                     Color(hex: 0xC0392B)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.card)
            .padding(.bottom, 80)
        }
    }
}
// ========== BLOCK 40: TVOnboardingView (safety gate) - END ==========
