//
//  SessionViewModel.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored on 2025-09-30 to use coordinators
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

    // Coordinators
    private var playbackCoordinator: PlaybackCoordinator!
    private let aiSongCoordinator: AISongCoordinator
    private let turnManager: TurnManager

    private var prefetchTask: Task<Void, Never>?

    private init() {
        // Initialize coordinators (except playbackCoordinator which needs self reference)
        self.turnManager = TurnManager(sessionService: sessionService)
        self.aiSongCoordinator = AISongCoordinator(sessionService: sessionService)

        // Initialize playback coordinator after self is fully initialized
        self.playbackCoordinator = PlaybackCoordinator(
            musicService: musicService,
            sessionService: sessionService,
            onSongEnded: { [weak self] in
                await self?.triggerAISelection()
            }
        )

        B2BLog.session.info("SessionViewModel initialized with coordinators")
        playbackCoordinator.startMonitoring()
    }

    nonisolated deinit {
        // Tasks will be cancelled automatically
    }

    // MARK: - Public Methods

    func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("👤 User selected: \(song.title) by \(song.artistName)")
        B2BLog.session.debug("Current queue before selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Cancel any existing prefetch
        if prefetchTask != nil {
            B2BLog.session.debug("Cancelling existing AI prefetch task")
            prefetchTask?.cancel()
        }

        // Clear any AI queued songs (user takes control)
        if turnManager.shouldClearAIQueueOnUserSelection() {
            B2BLog.session.info("Clearing AI queue - User taking control")
            sessionService.clearAIQueuedSongs()
            sessionService.clearNextAISong()
        }

        // Check if something is currently playing
        let isMusicPlaying = musicService.playbackState == .playing || musicService.currentlyPlaying != nil

        if isMusicPlaying {
            // Music is playing - queue the song
            B2BLog.session.info("Music currently playing - queueing user song with 'upNext' status")
            _ = sessionService.queueSong(song, selectedBy: .user, queueStatus: .upNext)

            // Start pre-fetching AI's next song to play after the user's queued song
            let queueStatus = turnManager.getQueueStatusAfterSong(selectedBy: .user)
            B2BLog.session.info("Starting AI prefetch for next position after user's queued song")
            prefetchTask = Task.detached { [weak self] in
                await self?.aiSongCoordinator.prefetchAndQueueAISong(queueStatus: queueStatus)
            }
        } else {
            // Nothing playing - play immediately
            B2BLog.session.info("No music playing - starting playback immediately")
            sessionService.addSongToHistory(song, selectedBy: .user, queueStatus: .playing)

            // Play the song
            await playCurrentSong(song)

            // Start pre-fetching AI's next song while user's song plays
            let queueStatus = turnManager.getQueueStatusAfterSong(selectedBy: .user)
            B2BLog.session.info("Starting AI prefetch for 'upNext' position")
            prefetchTask = Task.detached { [weak self] in
                await self?.aiSongCoordinator.prefetchAndQueueAISong(queueStatus: queueStatus)
            }
        }

        B2BLog.session.debug("Queue after user selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
    }

    func handleAIStartFirst() async {
        if let song = await aiSongCoordinator.selectAndPlayAISongToStart() {
            // Add to history with "playing" status since we'll play it immediately
            sessionService.addSongToHistory(song, selectedBy: .ai, rationale: nil, queueStatus: .playing)

            // Play the song
            await playCurrentSong(song)

            // Queue another AI song as backup in case user doesn't select
            let queueStatus = turnManager.getQueueStatusAfterSong(selectedBy: .ai)
            B2BLog.session.info("AI's first song playing - prefetching backup AI track")
            prefetchTask = Task.detached { [weak self] in
                await self?.aiSongCoordinator.prefetchAndQueueAISong(queueStatus: queueStatus)
            }
        }
    }

    func triggerAISelection() async {
        // This is now called when songs end automatically
        B2BLog.session.info("🔄 Auto-advancing to next queued song")
        B2BLog.session.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Check if we have a queued song ready
        if let nextSong = sessionService.getNextQueuedSong() {
            B2BLog.session.info("🎵 Found queued song: \(nextSong.song.title) by \(nextSong.song.artistName) (selected by \(nextSong.selectedBy.rawValue))")

            // Move the song from queue to history before playing
            sessionService.moveQueuedSongToHistory(nextSong.id)

            // Play the song
            await playCurrentSong(nextSong.song)

            // Clear AI thinking if appropriate
            if turnManager.shouldClearAIThinkingOnPlay(selectedBy: nextSong.selectedBy) {
                B2BLog.session.info("🤖 AI song now playing, clearing AI thinking state")
                sessionService.setAIThinking(false)
            }

            // Queue next AI song based on turn logic
            if turnManager.shouldQueueAnotherAISong(after: nextSong.selectedBy) {
                let queueStatus = turnManager.getQueueStatusAfterSong(selectedBy: nextSong.selectedBy)
                B2BLog.session.info("Queueing next AI selection with status: \(queueStatus)")
                prefetchTask = Task.detached { [weak self] in
                    await self?.aiSongCoordinator.prefetchAndQueueAISong(queueStatus: queueStatus)
                }
            }
        } else {
            B2BLog.session.warning("⚠️ No queued song available - waiting for user selection")
            // User needs to select manually
            // Make sure AI thinking is cleared so user can select
            sessionService.setAIThinking(false)
        }
    }

    func skipToQueuedSong(_ sessionSong: SessionSong) async {
        B2BLog.session.info("⏩ User tapped to skip to queued song: \(sessionSong.song.title)")
        B2BLog.session.debug("Queue state before skip - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Cancel any existing prefetch
        if prefetchTask != nil {
            B2BLog.session.debug("Cancelling existing AI prefetch task")
            prefetchTask?.cancel()
        }

        // Mark the currently playing song as played (if there is one)
        sessionService.markCurrentSongAsPlayed()

        // Remove all songs before this one from the queue (they're being skipped)
        sessionService.removeQueuedSongsBeforeSong(sessionSong.id)

        // Move the tapped song from queue to history
        sessionService.moveQueuedSongToHistory(sessionSong.id)

        // Play the tapped song
        await playCurrentSong(sessionSong.song)

        // Clear AI thinking if appropriate
        if turnManager.shouldClearAIThinkingOnPlay(selectedBy: sessionSong.selectedBy) {
            B2BLog.session.info("🤖 Skipped to AI song, clearing AI thinking state")
            sessionService.setAIThinking(false)
        }

        // Queue the next song based on turn logic
        if turnManager.shouldQueueAnotherAISong(after: sessionSong.selectedBy) {
            let queueStatus = turnManager.getQueueStatusAfterSong(selectedBy: sessionSong.selectedBy)
            B2BLog.session.info("Queueing next AI selection with status: \(queueStatus)")
            prefetchTask = Task.detached { [weak self] in
                await self?.aiSongCoordinator.prefetchAndQueueAISong(queueStatus: queueStatus)
            }
        }

        B2BLog.session.debug("Queue state after skip - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
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