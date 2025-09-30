//
//  SessionView.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored on 2025-09-30 to use extracted components
//

import SwiftUI
import MusicKit

struct SessionView: View {
    // For @Observable objects, access directly without property wrappers
    // SwiftUI automatically tracks property access and updates the view
    private let sessionService = SessionService.shared
    private let sessionViewModel = SessionViewModel.shared
    private let musicService = MusicService.shared

    @State private var showSongPicker = false
    @State private var showNowPlaying = false

    // Check if user has already selected a song in the queue
    private var hasUserSelectedSong: Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }

    private var sessionHasStarted: Bool {
        !sessionService.sessionHistory.isEmpty || !sessionService.songQueue.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SessionHeaderView(
                currentTurn: sessionService.currentTurn,
                personaName: sessionService.currentPersonaName,
                showNowPlayingButton: musicService.currentlyPlaying != nil,
                onNowPlayingTapped: { showNowPlaying = true }
            )

            // Session history and queue
            if !sessionHasStarted && !sessionService.isAIThinking {
                ContentUnavailableView(
                    "No Songs Yet",
                    systemImage: "music.note.list",
                    description: Text("Start your DJ session by selecting the first track")
                )
                .frame(maxHeight: .infinity)
            } else {
                SessionHistoryListView(
                    sessionHistory: sessionService.sessionHistory,
                    songQueue: sessionService.songQueue,
                    isAIThinking: sessionService.isAIThinking
                )
            }

            // Bottom controls
            SessionActionButtons(
                sessionHasStarted: sessionHasStarted,
                currentTurn: sessionService.currentTurn,
                hasUserSelectedSong: hasUserSelectedSong,
                onUserSelectTapped: { showSongPicker = true },
                onAIStartTapped: {
                    Task {
                        await handleAIStartFirst()
                    }
                }
            )
        }
        .sheet(isPresented: $showSongPicker) {
            NavigationStack {
                MusicSearchView(
                    onSongSelected: { song in
                        Task {
                            await handleUserSongSelection(song)
                        }
                        showSongPicker = false
                    }
                )
                .navigationTitle("Select a Track")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showSongPicker = false
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }

    @MainActor
    private func handleUserSongSelection(_ song: Song) async {
        // Use SessionViewModel to handle the selection
        // This will automatically queue the AI's next song
        await sessionViewModel.handleUserSongSelection(song)

        // No need to manually trigger AI selection anymore -
        // it will happen automatically when the user's song ends
    }

    @MainActor
    private func handleAIStartFirst() async {
        // Let the SessionViewModel handle AI starting first
        await sessionViewModel.handleAIStartFirst()
    }
}

#Preview {
    SessionView()
}