//
//  SessionActionButtons.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView.swift
//

import SwiftUI
import OSLog

struct SessionActionButtons: View {
    let sessionHasStarted: Bool
    let currentTurn: TurnType
    let hasUserSelectedSong: Bool
    let onUserSelectTapped: () -> Void
    let onAIStartTapped: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Show both buttons only at the very start (no history and no queue)
            if !sessionHasStarted {
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
            } else if currentTurn == .user && !hasUserSelectedSong {
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
