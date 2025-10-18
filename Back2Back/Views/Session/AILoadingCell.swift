//
//  AILoadingCell.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//  Fixed Timer leak by using TimelineView instead of Timer.scheduledTimer
//

import SwiftUI
import OSLog

struct AILoadingCell: View {
    @Environment(\.services) private var services
    @State private var loadingStates: [(String, String)] = [
        ("brain.head.profile", "Analyzing the vibe..."),
        ("music.note.list", "Searching the catalog..."),
        ("sparkles", "Finding the perfect track...")
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.0)) { context in
            let currentPhase = Int(context.date.timeIntervalSince1970 / 2.0) % loadingStates.count

            HStack(spacing: 12) {
                // Turn indicator - animated CPU icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, options: .repeating)
                    )

                // Loading content
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: loadingStates[currentPhase].0)
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .symbolEffect(.bounce, options: .repeating)

                        Text(loadingStates[currentPhase].1)
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.pink.opacity(0.1),
                                Color.orange.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .pink.opacity(0.4), .orange.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .task {
                await loadStatusMessages()
            }
        }
    }

    // MARK: - Private Methods

    /// Load status messages for the current persona using Foundation Models
    /// Uses fire-and-forget pattern from StatusMessageService for non-blocking generation
    private func loadStatusMessages() async {
        guard let services = services else {
            B2BLog.ai.debug("Services not available, using default status messages")
            setDefaultMessages()
            return
        }

        guard let persona = services.personaService.selectedPersona else {
            B2BLog.ai.debug("No persona selected, using default status messages")
            setDefaultMessages()
            return
        }

        B2BLog.ai.debug("Loading status messages for persona: \(persona.name)")

        // Get messages (will use cache or generate in background)
        let messages = services.statusMessageService.getStatusMessages(for: persona)

        // Update loading states with persona-specific messages
        loadingStates = [
            ("brain.head.profile", messages.message1),
            ("music.note.list", messages.message2),
            ("sparkles", messages.message3)
        ]

        B2BLog.ai.debug("Status messages loaded: '\(messages.message1)', '\(messages.message2)', '\(messages.message3)'")

        // Increment usage count for regeneration tracking
        services.statusMessageService.incrementUsageCount(for: persona.id)
    }

    private func setDefaultMessages() {
        loadingStates = [
            ("brain.head.profile", "Analyzing the vibe..."),
            ("music.note.list", "Searching the catalog..."),
            ("sparkles", "Finding the perfect track...")
        ]
    }
}
