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

        // Initialize services
        initializeServices()
    }

    private func initializeServices() {
        B2BLog.general.info("Initializing services...")

        // Initialize EnvironmentService
        let environmentService = EnvironmentService.shared
        B2BLog.general.info("EnvironmentService initialized")

        // Initialize OpenAIClient
        let openAIClient = OpenAIClient.shared
        if openAIClient.isConfigured {
            B2BLog.ai.info("✅ OpenAI API key loaded successfully")
            B2BLog.ai.info("OpenAI client is ready for use")
        } else {
            B2BLog.ai.warning("⚠️ OpenAI API key not configured")
            B2BLog.ai.warning("Set OPENAI_API_KEY in your Xcode scheme's environment variables")
        }

        // Initialize MusicService
        let musicService = MusicService.shared
        B2BLog.musicKit.info("MusicService initialized")

        B2BLog.general.info("All services initialized successfully")
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
