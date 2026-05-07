//
//  NeuroLightApp.swift
//  NeuroLight
//

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
