// ========== BLOCK 10: OnboardingView - START ==========
//
//  OnboardingView.swift
//  NeuroLight
//
//  First-launch warning. Required by safety, gated by a real checkbox
//  (not a tap-through). Once acknowledged, persisted via @AppStorage
//  and never shown again.
//
//  Copy is deliberately bare — no medical claims, no therapeutic
//  language. "Useful for guided breathwork and meditation."
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage(StorageKey.hasSeenOnboarding) private var hasSeenOnboarding: Bool = false
    @State private var accepted: Bool = false
    @Bindable private var bus = AutomationBus.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top accent bar
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xF5A623), Color(hex: 0xE8593C), Color(hex: 0xC0392B)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 220, height: 1.5)
                    .padding(.top, 56)

                Text("PURE PHASE")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(10)
                    .foregroundColor(.white)
                    .padding(.top, 28)

                Spacer()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        Text("what this is")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(3)
                            .foregroundColor(Color(hex: 0x888480))

                        Text("Light, sound, and breath, used together to guide you toward focus, calm, or sleep. Useful for guided breathwork and meditation.")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(5)

                        Text("before you begin")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(3)
                            .foregroundColor(Color(hex: 0x888480))
                            .padding(.top, 10)

                        Text("Pure Phase intentionally uses rapid rhythmic flicker — that's how visual entrainment works. The Focus, Calm, Sleep, and Advanced modes are not designed for users with photosensitivity, seizure history, vestibular disorders, motion sensitivity, or significant vision impairment. The Breathe mode has no flicker and is usable by anyone.\n\nDo not use the entrainment modes while driving or operating machinery. Always use in a safe, seated environment. This is not a medical device and makes no medical claims.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(hex: 0xC0392B))
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 36)
                    .frame(maxWidth: Layout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                Spacer()

                // Acknowledgement
                HStack(spacing: 14) {
                    Button {
                        accepted.toggle()
                    } label: {
                        Image(systemName: accepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(accepted
                                             ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF5A623), Color(hex: 0xC0392B)], startPoint: .leading, endPoint: .trailing))
                                             : AnyShapeStyle(Color(hex: 0x888480)))
                    }
                    .buttonStyle(.plain)

                    Text("i understand and accept these terms")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))
                }
                .padding(.horizontal, 36)
                .accessibilityIdentifier("onboarding.checkbox.row")
                .padding(.bottom, 18)

                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("ENTER")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(8)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xF5A623), Color(hex: 0xE8593C), Color(hex: 0xC0392B)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .opacity(accepted ? 1.0 : 0.25)
                }
                .buttonStyle(.plain)
                .disabled(!accepted)
                .padding(.horizontal, 36)
                .padding(.bottom, 50)
                .animation(.easeInOut(duration: 0.4), value: accepted)
                .accessibilityIdentifier("onboarding.enter")
            }
        }
        .onAppear {
            bus.currentScreen = "onboarding"
            bus.register("onboarding.accept") {
                accepted = true
                hasSeenOnboarding = true
            }
            bus.register("onboarding.toggle") { accepted.toggle() }
            bus.register("onboarding.enter") {
                if accepted { hasSeenOnboarding = true }
            }
        }
        .onDisappear {
            bus.unregister("onboarding.accept")
            bus.unregister("onboarding.toggle")
            bus.unregister("onboarding.enter")
        }
    }
}
// ========== BLOCK 10: OnboardingView - END ==========
