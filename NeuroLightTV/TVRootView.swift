// ========== BLOCK 37: TVRootView (tvOS placeholder) - START ==========
//
//  TVRootView.swift
//  NeuroLightTV
//
//  Placeholder root view for the tvOS target. Real tvOS UI lands in a
//  follow-up — this file just makes the target compile and run with
//  visible Pure Phase branding so the project structure can be
//  verified end-to-end.
//
//  Per 2.0 spec, the real tvOS UI will be:
//    Six tiles on a black background — BREATHE / FOCUS / CALM / SLEEP
//    / DRIFT / BLOOM. Single click to start (no long press, no
//    Advanced panel, no config). Click again to exit.
//

import SwiftUI

struct TVRootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xF5A623),
                                 Color(hex: 0xE8593C),
                                 Color(hex: 0xC0392B)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 220, height: 1.5)

                Text("PURE PHASE")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(14)
                    .foregroundColor(.white)

                Text("tvOS — coming soon")
                    .font(.system(size: 14, weight: .regular))
                    .tracking(3)
                    .foregroundColor(Color(hex: 0x888480))
            }
        }
    }
}

#Preview {
    TVRootView()
}
// ========== BLOCK 37: TVRootView (tvOS placeholder) - END ==========
