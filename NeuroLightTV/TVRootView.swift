// ========== BLOCK 37: TVRootView (router) - START ==========
//
//  TVRootView.swift
//  NeuroLightTV
//
//  Top-level router for the tvOS app. Three states:
//    1. Onboarding — first-launch safety acknowledgement (same gate
//       as iOS, but with TV-friendly focus-based interaction).
//    2. Home — six tiles (BREATHE / FOCUS / CALM / SLEEP / DRIFT /
//       BLOOM). Single click starts a session with the saved defaults.
//       No long press, no Advanced, no config — TV is lean-back.
//    3. Session — full-bleed visual experience, reuses SessionEngine
//       and the cross-platform display components (BloomBackgroundView,
//       BreathGuideView, GradientProgressRing).
//
//  Click the Siri Remote during a session to exit. Menu button does
//  the same.
//

import SwiftUI

struct TVRootView: View {
    @AppStorage(StorageKey.hasSeenOnboarding) private var hasSeenOnboarding: Bool = false
    @State private var presentingConfig: SessionConfig? = nil
    @Bindable private var bus = AutomationBus.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
        .onChange(of: bus.requestedSession) { _, cfg in
            // The DEBUG automation surface drives sessions from the Mac
            // (used for screenshot capture and verification). Mirror the
            // iOS ContentView pattern: set the local presenting state,
            // then clear the request flag.
            guard let cfg = cfg else { return }
            presentingConfig = cfg
            DispatchQueue.main.async {
                bus.requestedSession = nil
            }
        }
        .onChange(of: bus.dismissTicket) { _, _ in
            presentingConfig = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if let cfg = presentingConfig {
            TVSessionView(config: cfg, onExit: { presentingConfig = nil })
                .transition(.opacity)
        } else if hasSeenOnboarding {
            TVHomeView { state in
                presentingConfig = SessionConfig.fromAppStorage(state: state)
            }
            .transition(.opacity)
        } else {
            TVOnboardingView { hasSeenOnboarding = true }
                .transition(.opacity)
        }
    }
}

#Preview {
    TVRootView()
}
// ========== BLOCK 37: TVRootView (router) - END ==========
