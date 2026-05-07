// ========== BLOCK 25: AdvancedView - START ==========
//
//  AdvancedView.swift
//  NeuroLight
//
//  Five tiles for the exploratory states: Theta, SMR, Psychedelic,
//  Void, Custom. Same single-tap-to-start / long-press-for-config
//  pattern as Home. A muted disclaimer at the top reminds the user
//  these states have less photic-entrainment evidence behind them.
//

import SwiftUI

struct AdvancedView: View {
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
                        .frame(width: 140, height: 1.5)
                        .padding(.top, 18)

                    Text("ADVANCED")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(10)
                        .foregroundColor(.white)
                        .padding(.top, 16)

                    Text("less studied — explore with care")
                        .font(.system(size: 11, weight: .regular))
                        .tracking(2)
                        .foregroundColor(Color(hex: 0x888480))
                        .padding(.top, 8)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)

                    Text("tap to begin · hold to tune")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(3)
                        .foregroundColor(Color(hex: 0x888480).opacity(0.7))
                        .padding(.bottom, 12)

                    VStack(spacing: 0) {
                        tile(state: .theta,        symbol: "sparkles")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .smr,          symbol: "circle.dotted")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .psychedelic,  symbol: "swirl.circle.righthalf.filled")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .voidState,    symbol: "circle")
                        Divider().background(Color.white.opacity(0.06))
                        tile(state: .custom,       symbol: "slider.horizontal.3")
                    }

                    Spacer(minLength: 36)
                }
                .frame(maxWidth: Layout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            bus.currentScreen = "advanced"
            for state in BrainwaveState.advanced {
                let id = state.id
                bus.register("advanced.tile.\(id)") {
                    bus.requestedSession = SessionConfig.fromAppStorage(state: state)
                }
                bus.register("advanced.tile.\(id).config") {
                    bus.requestedConfigState = id
                }
            }
        }
        .onDisappear {
            for state in BrainwaveState.advanced {
                bus.unregister("advanced.tile.\(state.id)")
                bus.unregister("advanced.tile.\(state.id).config")
            }
        }
    }

    @ViewBuilder
    private func tile(state: BrainwaveState, symbol: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(state.sessionTint.gradient)
                .shadow(color: state.sessionTint.startColor.opacity(0.32), radius: 12)
                .frame(height: 60)

            Text(state.displayName)
                .font(.system(size: 12, weight: .semibold))
                .tracking(5)
                .foregroundColor(.white.opacity(0.85))

            Text("\(state.hz, specifier: "%.1f") Hz")
                .font(.system(size: 9, weight: .regular))
                .tracking(2)
                .foregroundColor(Color(hex: 0x888480).opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .tileGesture(
            onTap: { bus.requestedSession = SessionConfig.fromAppStorage(state: state) },
            onLongPress: { bus.requestedConfigState = state.id }
        )
        .accessibilityIdentifier("advanced.tile.\(state.id)")
    }
}
// ========== BLOCK 25: AdvancedView - END ==========
