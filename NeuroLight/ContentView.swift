// ========== BLOCK 21: ContentView (router with automation bus) - START ==========
//
//  ContentView.swift
//  NeuroLight
//
//  Root router. Owns the navigation stack and the session presentation
//  so the debug AutomationBus can drive the whole app from one place.
//
//  iOS-only — the tvOS target provides its own ContentView in
//  NeuroLightTV/ContentView.swift with focus-based navigation and a
//  reduced tile set. Sharing this file across both targets would cause
//  a duplicate type name; the #if guard keeps each platform clean.
//

#if os(iOS)

import SwiftUI

struct ContentView: View {
    @AppStorage(StorageKey.hasSeenOnboarding) private var hasSeenOnboarding: Bool = false

    @State private var navPath = NavigationPath()
    @State private var presentingConfig: SessionConfig? = nil

    /// Cold-start fade-in. SwiftUI initializes this once when the
    /// WindowGroup creates ContentView; navigating around the app
    /// doesn't re-fire it. The first view the user sees rises gently
    /// out of black instead of snapping in.
    @State private var hasAppeared: Bool = false

    @Bindable private var bus = AutomationBus.shared

    var body: some View {
        Group {
            if hasSeenOnboarding {
                NavigationStack(path: $navPath) {
                    HomeView()
                        .navigationDestination(for: String.self) { stateID in
                            if let state = BrainwaveState.state(forID: stateID) {
                                SessionConfigView(state: state)
                            }
                        }
                        .navigationDestination(for: NavigationRoute.self) { route in
                            switch route {
                            case .advanced: AdvancedView()
                            }
                        }
                }
                .preferredColorScheme(.dark)
                .tint(Color(hex: 0xF5A623))
                .background(Color.black)
                .fullScreenCover(
                    isPresented: Binding(
                        get: { presentingConfig != nil },
                        set: { if !$0 { presentingConfig = nil } }
                    )
                ) {
                    if let cfg = presentingConfig {
                        SessionView(config: cfg)
                    }
                }
                .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: hasSeenOnboarding)
        .preferredColorScheme(.dark)
        .onChange(of: bus.requestedConfigState) { _, newValue in
            guard let id = newValue else { return }
            navPath = NavigationPath()
            navPath.append(id)
            DispatchQueue.main.async {
                bus.requestedConfigState = nil
            }
        }
        .onChange(of: bus.requestedRoute) { _, route in
            guard let route = route else { return }
            navPath.append(route)
            DispatchQueue.main.async {
                bus.requestedRoute = nil
            }
        }
        .onChange(of: bus.requestedSession) { _, cfg in
            guard let cfg = cfg else { return }
            presentingConfig = cfg
            DispatchQueue.main.async {
                bus.requestedSession = nil
            }
        }
        .onChange(of: bus.dismissTicket) { _, _ in
            presentingConfig = nil
        }
        .onChange(of: bus.popToRootTicket) { _, _ in
            navPath = NavigationPath()
            presentingConfig = nil
        }
        .onAppear {
            bus.currentScreen = hasSeenOnboarding ? "home" : "onboarding"
            // Slow rise from black on first render — matches the rest
            // of the motion language (nothing snaps).
            withAnimation(.easeOut(duration: 1.2)) {
                hasAppeared = true
            }
        }
        .onChange(of: hasSeenOnboarding) { _, seen in
            bus.currentScreen = seen ? "home" : "onboarding"
        }
    }
}

#Preview { ContentView() }

#endif
// ========== BLOCK 21: ContentView (router with automation bus) - END ==========
