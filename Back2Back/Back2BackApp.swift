//
//  Back2BackApp.swift
//  Back2Back
//
//  Created by PJ Gray on 9/25/25.
//

import SwiftUI
import OSLog

@main
struct Back2BackApp: App {
    init() {
        B2BLog.general.info("🎶 Back2Back App Launched")
        B2BLog.general.info("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        B2BLog.general.info("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    B2BLog.ui.debug("Main ContentView appeared")
                }
        }
    }
}
