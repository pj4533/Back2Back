//
//  SessionActionButtons.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI
import OSLog
import Observation

struct SessionActionButtons: View {
    @Bindable private var sessionService: SessionService
    @Bindable private var sessionViewModel: SessionViewModel

    let onUserSelectTapped: () -> Void
    let onAIStartTapped: () -> Void
    let onDirectionOptionSelected: (DirectionOption) -> Void

    init(
        sessionService: SessionService,
        sessionViewModel: SessionViewModel,
        onUserSelectTapped: @escaping () -> Void,
        onAIStartTapped: @escaping () -> Void,
        onDirectionOptionSelected: @escaping (DirectionOption) -> Void
    ) {
        self._sessionService = Bindable(wrappedValue: sessionService)
        self._sessionViewModel = Bindable(wrappedValue: sessionViewModel)
        self.onUserSelectTapped = onUserSelectTapped
        self.onAIStartTapped = onAIStartTapped
        self.onDirectionOptionSelected = onDirectionOptionSelected
    }

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

                    // Direction change menu
                    Menu {
                        Section("Nudge toward...") {
                            ForEach(sessionViewModel.cachedDirectionChange?.options ?? []) { option in
                                Button(option.buttonLabel) {
                                    B2BLog.ui.debug("User selected direction option: \(option.buttonLabel)")
                                    onDirectionOptionSelected(option)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Nudge The DJ")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(sessionViewModel.isGeneratingDirection || sessionViewModel.cachedDirectionChange?.options.isEmpty ?? true)
                }
                .task {
                    // Generate direction change options when buttons appear (non-blocking)
                    sessionViewModel.generateDirectionChange()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
