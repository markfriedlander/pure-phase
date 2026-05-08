// ========== BLOCK 38: TVHomeView (six tiles, focus-based) - START ==========
//
//  TVHomeView.swift
//  NeuroLightTV
//
//  Six tiles arranged horizontally on a black background. Single
//  click on any tile starts a session immediately with the user's
//  saved settings (or app defaults if no iPhone has tuned them).
//
//  Tile order: BREATHE / FOCUS / CALM / SLEEP / DRIFT / BLOOM. The
//  primary states first, then the two psychoacoustic modes. PRISM,
//  Theta, SMR, Void, Custom are not surfaced on TV in 2.0 — TV is
//  lean-back, defaults-only.
//

import SwiftUI

struct TVHomeView: View {
    let onTileTap: (BrainwaveState) -> Void

    /// Tiles in the order they appear on TV. Matches the spec.
    private let tiles: [(state: BrainwaveState, symbol: String)] = [
        (.breathwork, "wind"),
        (.focus,      "viewfinder"),
        (.calm,       "water.waves"),
        (.sleep,      "moon.fill"),
        (.drift,      "waveform"),
        (.bloom,      "sun.max"),
    ]

    var body: some View {
        VStack(spacing: 64) {
            header
            tileRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 80)
    }

    private var header: some View {
        VStack(spacing: 22) {
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

            Text("click any to begin")
                .font(.system(size: 18, weight: .regular))
                .tracking(4)
                .foregroundColor(Color(hex: 0x888480).opacity(0.85))
        }
    }

    private var tileRow: some View {
        HStack(spacing: 28) {
            ForEach(tiles, id: \.state.id) { tile in
                TVTileButton(
                    state: tile.state,
                    symbolName: tile.symbol,
                    action: { onTileTap(tile.state) }
                )
            }
        }
    }
}
// ========== BLOCK 38: TVHomeView (six tiles, focus-based) - END ==========
