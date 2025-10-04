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
    private let sessionViewModel = SessionViewModel.shared

    let onUserSelectTapped: () -> Void
    let onAIStartTapped: () -> Void
    let onDirectionChangeTapped: () -> Void

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
                // After session has started, show user selection button and direction change button on their turn
                HStack(spacing: 12) {
                    // User selection button
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

                    // Direction change button
                    Button(action: {
                        B2BLog.ui.debug("User tapped direction change button: \(sessionViewModel.directionButtonLabel)")
                        onDirectionChangeTapped()
                    }) {
                        HStack {
                            if sessionViewModel.isGeneratingDirection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(sessionViewModel.directionButtonLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(sessionViewModel.isGeneratingDirection)
                }
                .task {
                    // Generate direction change when buttons appear
                    await sessionViewModel.generateDirectionChange()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
