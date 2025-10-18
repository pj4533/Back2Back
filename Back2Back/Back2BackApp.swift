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
    // Create service container with dependency injection
    @State private var services: ServiceContainer

    init() {
        // Initialize service container
        let container = ServiceContainer()
        _services = State(initialValue: container)

        B2BLog.general.info("🎶 Back2Back App Launched")
        B2BLog.general.info("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        B2BLog.general.info("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")

        // Check OpenAI configuration and pregenerate status messages
        Task { @MainActor in
            container.checkOpenAIConfiguration()
            container.pregenerateStatusMessages()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withServices(services)
                .onAppear {
                    B2BLog.ui.debug("Main ContentView appeared")
                }
        }
    }
}
