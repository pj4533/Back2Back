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

    // Use concrete @Observable types for SwiftUI observation to work
    // Protocols break observation chain since they can't be @Observable
    private let musicService: MusicService
    private let sessionService: SessionService

    // Coordinators handle specific responsibilities
    private let queueSync: QueueSynchronizationService
    private let aiSongCoordinator: AISongCoordinator
    private let turnManager: TurnManager

    init(
        musicService: MusicService = MusicService.shared,
        sessionService: SessionService = SessionService.shared,
        queueSync: QueueSynchronizationService? = nil,
        aiSongCoordinator: AISongCoordinator? = nil,
        turnManager: TurnManager? = nil
    ) {
        self.musicService = musicService
        self.sessionService = sessionService
        self.queueSync = queueSync ?? QueueSynchronizationService.shared
        self.aiSongCoordinator = aiSongCoordinator ?? AISongCoordinator()
        self.turnManager = turnManager ?? TurnManager()

        B2BLog.session.info("SessionViewModel initialized")

        // Setup queue advancement callback
        self.queueSync.onSongAdvanced = { [weak self] in
            await self?.handleSongAdvanced()
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

        // Clear any AI queued songs from SessionService (user takes control)
        B2BLog.session.info("Clearing AI queue - User taking control")
        sessionService.clearAIQueuedSongs()
        sessionService.clearNextAISong()

        // Also clear AI songs from MusicKit queue
        do {
            try await queueSync.removeAISongs()
        } catch {
            B2BLog.session.error("Failed to remove AI songs from MusicKit queue: \(error)")
        }

        // Check if something is currently playing
        let isMusicPlaying = musicService.playbackState == .playing || musicService.currentlyPlaying != nil

        if isMusicPlaying {
            // Music is playing - queue the song in both SessionService and MusicKit
            B2BLog.session.info("Music currently playing - queueing user song with 'upNext' status")
            _ = sessionService.queueSong(song, selectedBy: .user, rationale: nil, queueStatus: .upNext)

            // Add to MusicKit queue
            do {
                try await musicService.queueNextSong(song)
            } catch {
                B2BLog.session.error("Failed to queue song in MusicKit: \(error)")
            }

            // Start pre-fetching AI's next song to play after the user's queued song
            B2BLog.session.info("Starting AI prefetch for next position after user's queued song")
            aiSongCoordinator.startPrefetch(queueStatus: .upNext)
        } else {
            // Nothing playing - start playback
            B2BLog.session.info("No music playing - starting playback immediately")
            sessionService.addSongToHistory(song, selectedBy: .user, rationale: nil, queueStatus: .playing)

            // Start playback (will initialize queue)
            do {
                try await musicService.startPlayback(with: song)
            } catch {
                B2BLog.session.error("Failed to start playback: \(error)")
            }

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

                // Start playback
                do {
                    try await musicService.startPlayback(with: song)
                } catch {
                    B2BLog.session.error("Failed to start playback: \(error)")
                }

                // Note: We don't need to call startPrefetch here because
                // handleSongAdvanced() will be called automatically when playback starts
                // and it will queue the next AI song with the correct status
            }
        } catch {
            B2BLog.ai.error("❌ Failed to start AI first: \(error)")
        }
    }

    func skipToQueuedSong(_ sessionSong: SessionSong) async {
        // Cancel any existing prefetch
        aiSongCoordinator.cancelPrefetch()

        // Find song index in MusicKit queue
        guard let songIndex = queueSync.findSongIndex(sessionSong.song.id.rawValue) else {
            B2BLog.session.error("Song not found in MusicKit queue for skip")
            return
        }

        // Use turn manager to handle skip in SessionService
        _ = await turnManager.skipToSong(sessionSong)

        // Skip to the song in MusicKit queue
        do {
            try await queueSync.skipToEntry(at: songIndex)
        } catch {
            B2BLog.session.error("Failed to skip to queued song in MusicKit: \(error)")
        }

        // Queue the next song based on who selected the current song
        let queueStatus = turnManager.determineNextQueueStatus(after: sessionSong.selectedBy)
        aiSongCoordinator.startPrefetch(queueStatus: queueStatus)
    }

    // MARK: - Private Methods

    /// Handle when MusicKit queue advances to next song automatically
    private func handleSongAdvanced() async {
        B2BLog.session.info("🔄 MusicKit queue advanced - handling transition")

        // Note: updateCurrentlyPlayingSong has already moved the song from queue to history
        // We just need to queue the next AI song based on who selected the current song

        guard let currentSong = sessionService.getCurrentlyPlayingSessionSong() else {
            B2BLog.session.warning("No currently playing song after advancement")
            return
        }

        B2BLog.session.info("✅ Song now playing: \(currentSong.song.title) (selected by \(currentSong.selectedBy.rawValue))")

        // Queue the next song based on who selected the current song
        let queueStatus = turnManager.determineNextQueueStatus(after: currentSong.selectedBy)
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