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
    private let playbackCoordinator: PlaybackCoordinator
    private let aiSongCoordinator: AISongCoordinator
    private let turnManager: TurnManager

    // Direction change state
    var directionButtonLabel: String = "Different Direction"
    var isGeneratingDirection: Bool = false
    private var cachedDirectionChange: DirectionChange?

    init(
        musicService: MusicService = MusicService.shared,
        sessionService: SessionService = SessionService.shared,
        playbackCoordinator: PlaybackCoordinator? = nil,
        aiSongCoordinator: AISongCoordinator? = nil,
        turnManager: TurnManager? = nil
    ) {
        self.musicService = musicService
        self.sessionService = sessionService
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
            _ = sessionService.queueSong(song, selectedBy: .user, rationale: nil, queueStatus: .upNext)

            // Start pre-fetching AI's next song to play after the user's queued song
            B2BLog.session.info("Starting AI prefetch for next position after user's queued song")
            aiSongCoordinator.startPrefetch(queueStatus: .upNext)
        } else {
            // Nothing playing - play immediately
            B2BLog.session.info("No music playing - starting playback immediately")
            sessionService.addSongToHistory(song, selectedBy: .user, rationale: nil, queueStatus: .playing)

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

        // Queue the next song based on current turn
        let queueStatus = turnManager.determineNextQueueStatus()
        aiSongCoordinator.startPrefetch(queueStatus: queueStatus)
    }

    /// Generate a contextual direction change suggestion for the current session
    func generateDirectionChange() async {
        guard !isGeneratingDirection else {
            B2BLog.ai.debug("Direction generation already in progress, skipping")
            return
        }

        isGeneratingDirection = true
        defer { isGeneratingDirection = false }

        do {
            B2BLog.ai.info("Generating direction change suggestion")
            let directionChange = try await OpenAIClient.shared.generateDirectionChange(
                persona: sessionService.currentPersonaStyleGuide,
                sessionHistory: sessionService.sessionHistory
            )

            cachedDirectionChange = directionChange
            directionButtonLabel = directionChange.buttonLabel

            B2BLog.ai.info("Direction change generated: \(directionChange.buttonLabel)")
        } catch {
            B2BLog.ai.error("Failed to generate direction change: \(error)")
            // Use fallback label
            directionButtonLabel = "Different Direction"
            cachedDirectionChange = DirectionChange(
                directionPrompt: "Select a track that takes the session in a different musical direction while staying true to your persona.",
                buttonLabel: "Different Direction"
            )
        }
    }

    /// Handle user tapping the direction change button
    func handleDirectionChange() async {
        guard let directionChange = cachedDirectionChange else {
            B2BLog.ai.warning("Direction change button tapped but no cached direction available")
            return
        }

        B2BLog.session.info("👤 User requested direction change: \(directionChange.buttonLabel)")
        B2BLog.ai.debug("Direction prompt: \(directionChange.directionPrompt)")

        // Cancel any existing prefetch
        aiSongCoordinator.cancelPrefetch()

        // Clear any AI queued songs (we'll replace with new direction)
        B2BLog.session.info("Clearing AI queue - User requested direction change")
        sessionService.clearAIQueuedSongs()
        sessionService.clearNextAISong()

        // Queue new AI song with direction change
        // Turn remains on user since they didn't select a song themselves
        B2BLog.session.info("Queuing AI song with direction change - turn stays on user")
        aiSongCoordinator.startPrefetch(queueStatus: .queuedIfUserSkips, directionChange: directionChange)

        // Clear cached direction so we generate a fresh one next time
        cachedDirectionChange = nil
        directionButtonLabel = "Different Direction"
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

        // Queue the next song based on current turn (turn was already updated in advanceToNextSong)
        let queueStatus = turnManager.determineNextQueueStatus()
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