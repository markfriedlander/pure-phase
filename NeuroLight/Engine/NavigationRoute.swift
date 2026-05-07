// ========== BLOCK 26: NavigationRoute - START ==========
//
//  NavigationRoute.swift
//  NeuroLight
//
//  Tiny enum used as values pushed onto the root NavigationStack path.
//  Distinct from SessionConfigView pushes (which use a String state-id)
//  so the destination resolver can disambiguate.
//

import Foundation

enum NavigationRoute: Hashable, Codable {
    case advanced
}
// ========== BLOCK 26: NavigationRoute - END ==========
