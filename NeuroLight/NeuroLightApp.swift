//
//  NeuroLightApp.swift
//  NeuroLight
//
//  iOS app entry point. Guarded `#if os(iOS)` because the tvOS target
//  shares this same source folder and provides its own `@main` in
//  NeuroLightTV/NeuroLightTVApp.swift.
//

#if os(iOS)

import SwiftUI

@main
struct NeuroLightApp: App {
    init() {
        #if DEBUG
        AutomationServer.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#endif
