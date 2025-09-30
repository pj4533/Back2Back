//
//  SessionActionButtons.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI
import OSLog

struct SessionActionButtons: View {
    private let sessionService = SessionService.shared

    let onUserSelectTapped: () -> Void
    let onAIStartTapped: () -> Void

    // Check if user has already selected a song in the queue
    private var hasUserSelectedSong: Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Show both buttons only at the very start (no history and no queue)
            if sessionService.sessionHistory.isEmpty && sessionService.songQueue.isEmpty {
                HStack(spacing: 12) {
                    // User goes first button
                    Button(action: {
                        B2BLog.ui.debug("User tapped select song button")
                        onUserSelectTapped()
                    }) {
                        Label(
                            "I'll Start",
                            systemImage: "person.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // AI goes first button
                    Button(action: {
                        B2BLog.ui.debug("User tapped AI start button")
                        onAIStartTapped()
                    }) {
                        Label(
                            "AI Starts",
                            systemImage: "cpu"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            } else if sessionService.currentTurn == .user && !hasUserSelectedSong {
                // After session has started, only show user selection button on their turn
                Button(action: {
                    B2BLog.ui.debug("User tapped select song button")
                    onUserSelectTapped()
                }) {
                    Label(
                        "Select Your Track",
                        systemImage: "plus.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
