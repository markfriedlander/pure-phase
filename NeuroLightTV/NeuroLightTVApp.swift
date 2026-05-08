//
//  NeuroLightTVApp.swift
//  NeuroLightTV
//
//  Created by Mark Friedlander on 5/7/26.
//

import SwiftUI

@main
struct NeuroLightTVApp: App {
    init() {
        // Same DEBUG-only automation surface as the iOS app. Lets us
        // drive sessions from the Mac for screenshot capture and
        // verification on the tvOS simulator. Stripped from Release
        // builds entirely (the AutomationServer class itself is wrapped
        // in `#if DEBUG`).
        #if DEBUG
        AutomationServer.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TVRootView()
        }
    }
}
