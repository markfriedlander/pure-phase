// ========== BLOCK 31: Layout - START ==========
//
//  Layout.swift
//  NeuroLight
//
//  Single source of truth for layout constants and shared layout
//  modifiers. The session experience (flicker, breath ring, edge
//  progress) is full-bleed and intentionally ignores everything here.
//  Everything else — Home, Advanced, SessionConfig, Onboarding —
//  uses these to stay coherent across iPhone, iPad, Mac, and TV.
//

import SwiftUI

enum Layout {
    /// Maximum content width for Home, Advanced, SessionConfig, and
    /// Onboarding. On any iPhone (≤ 430 pt) the cap is invisible — the
    /// content uses the full screen width. On iPad / Mac / TV the cap
    /// centers the content with black margins, preserving the sparse
    /// aesthetic.
    static let contentMaxWidth: CGFloat = 560
}

/// Wraps content in a ScrollView whose inner frame is at least the
/// available height, so on screens taller than the content the layout
/// vertically centers. On screens where content is already taller than
/// the screen (long iPhone configs), this is invisible — the ScrollView
/// just scrolls as before. The pattern that earns its keep on iPad,
/// Mac, and (future) TV without breaking iPhone.
struct CenteredScrollContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: Layout.contentMaxWidth)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
        }
    }
}
// ========== BLOCK 31: Layout - END ==========
