// ========== BLOCK 24: HomeView (tap=start, long-press=config) - START ==========
//
//  HomeView.swift
//  NeuroLight
//
//  Three glyphs on black. Single tap on any glyph starts a session
//  immediately using the current saved settings. Long press opens the
//  Session Config screen for that state. ADVANCED affordance pushes
//  AdvancedView.
//

import SwiftUI

struct HomeView: View {
    @Bindable private var bus = AutomationBus.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xF5A623), Color(hex: 0xE8593C), Color(hex: 0xC0392B)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: 180, height: 1.5)
                        .padding(.top, 24)
                        .accessibilityHidden(true)

                    Text("PURE PHASE")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(10)
                        .foregroundColor(.white)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                    Text("tap to begin · hold to tune")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(3)
                        .foregroundColor(Color(hex: 0x888480).opacity(0.7))
                        .padding(.bottom, 16)

                    // BREATHE → FOCUS → CALM → SLEEP — warm-to-deep order.
                    VStack(spacing: 0) {
                        tile(state: .breathwork, symbol: "wind",         id: "breathwork")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .focus,      symbol: "viewfinder",   id: "focus")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .calm,       symbol: "water.waves",  id: "calm")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .sleep,      symbol: "moon.fill",    id: "sleep")
                    }

                    NavigationLink(value: NavigationRoute.advanced) {
                        Text("ADVANCED")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(5)
                            .foregroundColor(Color(hex: 0x888480).opacity(0.85))
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.advanced")
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
                .frame(maxWidth: Layout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            bus.currentScreen = "home"
            registerTileActions()
            bus.register("home.advanced") {
                bus.requestedRoute = .advanced
            }
        }
        .onDisappear {
            unregisterTileActions()
            bus.unregister("home.advanced")
        }
    }

    @ViewBuilder
    private func tile(state: BrainwaveState, symbol: String, id: String) -> some View {
        IntentTileView(state: state, symbolName: symbol)
            .tileGesture(
                onTap: { bus.requestedSession = SessionConfig.fromAppStorage(state: state) },
                onLongPress: { bus.requestedConfigState = state.id }
            )
            .accessibilityIdentifier("home.tile.\(id)")
    }

    private var homeTileStates: [BrainwaveState] {
        BrainwaveState.primary + [.breathwork]
    }

    private func registerTileActions() {
        for state in homeTileStates {
            let id = state.id
            bus.register("home.tile.\(id)") {
                bus.requestedSession = SessionConfig.fromAppStorage(state: state)
            }
            bus.register("home.tile.\(id).config") {
                bus.requestedConfigState = id
            }
        }
    }

    private func unregisterTileActions() {
        for state in homeTileStates {
            bus.unregister("home.tile.\(state.id)")
            bus.unregister("home.tile.\(state.id).config")
        }
    }
}
// ========== BLOCK 24: HomeView (tap=start, long-press=config) - END ==========
