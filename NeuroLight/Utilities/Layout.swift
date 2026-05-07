// ========== BLOCK 31: Layout - START ==========
//
//  Layout.swift
//  NeuroLight
//
//  Single source of truth for layout constants. Update here, propagate
//  everywhere. Currently just the content max-width cap that constrains
//  navigational and configuration views on iPad / Mac. The session
//  experience itself (flicker, breath ring, edge progress) is full-bleed
//  and intentionally ignores this cap.
//

import CoreGraphics

enum Layout {
    /// Maximum content width for Home, Advanced, SessionConfig, and
    /// Onboarding. On any iPhone (≤ 430 pt) the cap is invisible — the
    /// content uses the full screen width. On iPad / Mac the cap centers
    /// the content with black margins, preserving the sparse aesthetic.
    static let contentMaxWidth: CGFloat = 560
}
// ========== BLOCK 31: Layout - END ==========
