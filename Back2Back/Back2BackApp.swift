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

        // Pregenerate status messages for selected persona
        pregenerateStatusMessages()
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

    private func pregenerateStatusMessages() {
        Task { @MainActor in
            // Get the currently selected persona
            if let selectedPersona = PersonaService.shared.selectedPersona {
                B2BLog.ai.info("Pregenerating status messages for selected persona: \(selectedPersona.name)")
                StatusMessageService.shared.pregenerateMessages(for: selectedPersona)
            } else {
                B2BLog.ai.debug("No persona selected, skipping status message pregeneration")
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
