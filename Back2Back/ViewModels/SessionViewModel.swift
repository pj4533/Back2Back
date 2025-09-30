//
//  SessionViewModel.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 1 architecture improvements (#20)
//

import Foundation
import MusicKit
import Observation
import Combine
import OSLog

@MainActor
@Observable
final class SessionViewModel {
    static let shared = SessionViewModel()

    private let musicService = MusicService.shared
    private let sessionService = SessionService.shared

    // Coordinators handle specific responsibilities
    private let playbackCoordinator: PlaybackCoordinator
    private let aiSongCoordinator: AISongCoordinator
    private let turnManager: TurnManager

    private init(
        playbackCoordinator: PlaybackCoordinator? = nil,
        aiSongCoordinator: AISongCoordinator? = nil,
        turnManager: TurnManager? = nil
    ) {
        self.playbackCoordinator = playbackCoordinator ?? PlaybackCoordinator()
        self.aiSongCoordinator = aiSongCoordinator ?? AISongCoordinator()
        self.turnManager = turnManager ?? TurnManager()

        B2BLog.session.info("SessionViewModel initialized")

        // Setup playback callback
        self.playbackCoordinator.onSongEnded = { [weak self] in
            await self?.handleSongEnded()
        }
    }

    nonisolated deinit {
        // Coordinators will clean up automatically
    }

    // MARK: - Public Methods

    func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("👤 User selected: \(song.title) by \(song.artistName)")
        B2BLog.session.debug("Current queue before selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Cancel any existing prefetch
        aiSongCoordinator.cancelPrefetch()

        // Clear any AI queued songs (user takes control)
        B2BLog.session.info("Clearing AI queue - User taking control")
        sessionService.clearAIQueuedSongs()
        sessionService.clearNextAISong()

        // Check if something is currently playing
        let isMusicPlaying = musicService.playbackState == .playing || musicService.currentlyPlaying != nil

        if isMusicPlaying {
            // Music is playing - queue the song
            B2BLog.session.info("Music currently playing - queueing user song with 'upNext' status")
            _ = sessionService.queueSong(song, selectedBy: .user, queueStatus: .upNext)

            // Start pre-fetching AI's next song to play after the user's queued song
            B2BLog.session.info("Starting AI prefetch for next position after user's queued song")
            aiSongCoordinator.startPrefetch(queueStatus: .upNext)
        } else {
            // Nothing playing - play immediately
            B2BLog.session.info("No music playing - starting playback immediately")
            sessionService.addSongToHistory(song, selectedBy: .user, queueStatus: .playing)

            // Play the song
            await playCurrentSong(song)

            // Start pre-fetching AI's next song while user's song plays
            B2BLog.session.info("Starting AI prefetch for 'upNext' position")
            aiSongCoordinator.startPrefetch(queueStatus: .upNext)
        }

        B2BLog.session.debug("Queue after user selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
    }

    func handleAIStartFirst() async {
        do {
            if let song = try await aiSongCoordinator.handleAIStartFirst() {
                // Add to history with "playing" status since we'll play it immediately
                sessionService.addSongToHistory(song, selectedBy: .ai, rationale: nil, queueStatus: .playing)

                // Play the song
                await playCurrentSong(song)

                // Queue another AI song as backup in case user doesn't select
                B2BLog.session.info("AI's first song playing - prefetching backup AI track")
                aiSongCoordinator.startPrefetch(queueStatus: .queuedIfUserSkips)
            }
        } catch {
            B2BLog.ai.error("❌ Failed to start AI first: \(error)")
        }
    }

    func skipToQueuedSong(_ sessionSong: SessionSong) async {
        // Cancel any existing prefetch
        aiSongCoordinator.cancelPrefetch()

        // Use turn manager to handle skip
        let song = await turnManager.skipToSong(sessionSong)

        // Play the tapped song
        await playCurrentSong(song)

        // Queue the next song based on who selected the current song
        let queueStatus = turnManager.determineNextQueueStatus(after: sessionSong.selectedBy)
        aiSongCoordinator.startPrefetch(queueStatus: queueStatus)
    }

    // MARK: - Private Methods

    private func playCurrentSong(_ song: Song) async {
        do {
            B2BLog.playback.info("Starting playback: \(song.title)")
            try await musicService.playSong(song)
        } catch {
            B2BLog.playback.error("Failed to play song: \(error)")
        }
    }

    private func handleSongEnded() async {
        // Use turn manager to advance to next song
        guard let (song, selectedBy) = await turnManager.advanceToNextSong() else {
            return
        }

        // Play the song
        await playCurrentSong(song)

        // Queue the next song based on who selected the current song
        let queueStatus = turnManager.determineNextQueueStatus(after: selectedBy)
        aiSongCoordinator.startPrefetch(queueStatus: queueStatus)
    }
}

// MARK: - Extensions for MusicSearchView Compatibility

extension SessionViewModel {
    func handleSongSelection(_ song: Song, isModal: Bool) async {
        if isModal {
            // This is from the modal picker, so it's a user selection
            await handleUserSongSelection(song)
        } else {
            // This is a programmatic selection (shouldn't happen in our flow)
            B2BLog.session.warning("Unexpected non-modal song selection")
        }
    }
}