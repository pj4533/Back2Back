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

        // Services will be initialized lazily when first accessed
        // Check OpenAI configuration status only
        checkOpenAIConfiguration()
    }

    private func checkOpenAIConfiguration() {
        // Only check configuration without forcing initialization
        Task { @MainActor in
            if OpenAIClient.shared.isConfigured {
                B2BLog.ai.info("✅ OpenAI API key configured")
            } else {
                B2BLog.ai.warning("⚠️ OpenAI API key not configured")
                B2BLog.ai.warning("Set OPENAI_API_KEY in your Xcode scheme's environment variables")
            }
        }
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
