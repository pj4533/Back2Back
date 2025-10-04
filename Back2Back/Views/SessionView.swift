//
//  SessionView.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 1 architecture improvements (#20)
//

import SwiftUI
import MusicKit
import OSLog

struct SessionView: View {
    private let sessionViewModel = SessionViewModel.shared

    @State private var showSongPicker = false
    @State private var showNowPlaying = false

    var body: some View {
        VStack(spacing: 0) {
            SessionHeaderView(onNowPlayingTapped: { showNowPlaying = true })

            SessionHistoryListView()

            SessionActionButtons(
                onUserSelectTapped: { showSongPicker = true },
                onAIStartTapped: {
                    Task { await handleAIStartFirst() }
                },
                onDirectionChangeTapped: {
                    Task { await handleDirectionChange() }
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
        B2BLog.session.info("User selected song: \(song.title)")
        await sessionViewModel.handleUserSongSelection(song)
    }

    @MainActor
    private func handleAIStartFirst() async {
        B2BLog.session.info("User requested AI to start first")
        await sessionViewModel.handleAIStartFirst()
    }

    @MainActor
    private func handleDirectionChange() async {
        B2BLog.session.info("User requested direction change")
        await sessionViewModel.handleDirectionChange()
    }
}

#Preview {
    SessionView()
}