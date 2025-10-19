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
    // Use concrete @Observable types for SwiftUI observation to work
    // Protocols break observation chain since they can't be @Observable
    private let musicService: MusicService
    private let sessionService: SessionService
    private let openAIClient: any AIRecommendationServiceProtocol

    // Coordinators handle specific responsibilities
    private let playbackCoordinator: PlaybackCoordinator
    private let aiSongCoordinator: AISongCoordinator
    private let turnManager: TurnManager

    // Direction change state
    var isGeneratingDirection: Bool = false
    private(set) var cachedDirectionChange: DirectionChange?
    private var lastDirectionGenerationSongId: String?

    init(
        musicService: MusicService,
        sessionService: SessionService,
        playbackCoordinator: PlaybackCoordinator,
        aiSongCoordinator: AISongCoordinator,
        turnManager: TurnManager,
        openAIClient: any AIRecommendationServiceProtocol
    ) {
        self.musicService = musicService
        self.sessionService = sessionService
        self.playbackCoordinator = playbackCoordinator
        self.aiSongCoordinator = aiSongCoordinator
        self.turnManager = turnManager
        self.openAIClient = openAIClient

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

    /// Generate contextual direction change suggestions for the current session (non-blocking)
    ///
    /// This method generates 2 direction options in the background without blocking the UI.
    /// Results are stored in `cachedDirectionChange` and can be displayed in a menu.
    func generateDirectionChange() {
        // Fire-and-forget pattern to avoid blocking
        Task.detached { @MainActor [weak self] in
            guard let self else { return }

            guard !self.isGeneratingDirection else {
                B2BLog.ai.debug("Direction generation already in progress, skipping")
                return
            }

            // Check if we need to regenerate based on current playing song
            let currentSongId = self.sessionService.sessionHistory.last?.song.id.rawValue
            if let lastSongId = self.lastDirectionGenerationSongId,
               let currentId = currentSongId,
               lastSongId == currentId {
                B2BLog.ai.debug("Direction already generated for current song, skipping")
                return
            }

            self.isGeneratingDirection = true
            defer { self.isGeneratingDirection = false }

            do {
                B2BLog.ai.info("Generating direction change suggestions (2 options)")

                // Pass the previously cached direction to avoid repetition
                let directionChange = try await openAIClient.generateDirectionChange(
                    persona: self.sessionService.currentPersonaStyleGuide,
                    sessionHistory: self.sessionService.sessionHistory,
                    previousDirection: self.cachedDirectionChange
                )

                self.cachedDirectionChange = directionChange
                self.lastDirectionGenerationSongId = currentSongId

                let labels = directionChange.options.map { $0.buttonLabel }.joined(separator: ", ")
                B2BLog.ai.info("Direction changes generated: \(labels)")
            } catch {
                B2BLog.ai.error("Failed to generate direction change: \(error)")
                // Use fallback options
                self.cachedDirectionChange = DirectionChange(options: [
                    DirectionOption(
                        directionPrompt: "Select a track that takes the session in a different musical direction while staying true to your persona.",
                        buttonLabel: "Different direction"
                    ),
                    DirectionOption(
                        directionPrompt: "Explore a contrasting tempo or mood while maintaining the persona's aesthetic.",
                        buttonLabel: "Change the vibe"
                    )
                ])
                self.lastDirectionGenerationSongId = currentSongId
            }
        }
    }

    /// Handle user selecting a specific direction option from the menu
    /// - Parameter option: The direction option the user selected
    func handleDirectionChange(option: DirectionOption) async {
        B2BLog.session.info("👤 User requested direction change: \(option.buttonLabel)")
        B2BLog.ai.debug("Direction prompt: \(option.directionPrompt)")

        // Cancel any existing prefetch and ensure AI thinking state is cleared
        B2BLog.session.debug("Cancelling any in-flight AI song selection")
        aiSongCoordinator.cancelPrefetch()

        // Explicitly reset AI thinking state to handle race conditions
        // (in case the cancelled task hasn't finished its cleanup yet)
        sessionService.setAIThinking(false)

        // Clear any AI queued songs (we'll replace with new direction)
        B2BLog.session.info("Clearing AI queue - User requested direction change")
        sessionService.clearAIQueuedSongs()
        sessionService.clearNextAISong()

        // Convert the selected option to a DirectionChange for the prefetch
        let directionChange = DirectionChange(
            directionPrompt: option.directionPrompt,
            buttonLabel: option.buttonLabel
        )

        // Queue new AI song with direction change
        // Turn remains on user since they didn't select a song themselves
        B2BLog.session.info("Queuing AI song with direction change - turn stays on user")
        aiSongCoordinator.startPrefetch(queueStatus: .queuedIfUserSkips, directionChange: directionChange)

        // Clear cached direction and regenerate a fresh one immediately
        // This allows user to tap again if they don't like the queued track
        clearDirectionCache()
        generateDirectionChange()
    }

    /// Clear the direction change cache and reset to default state
    private func clearDirectionCache() {
        B2BLog.ai.debug("Clearing direction change cache")
        cachedDirectionChange = nil
        lastDirectionGenerationSongId = nil
    }

    /// Reset the entire DJ session
    func resetSession() {
        B2BLog.session.info("👤 User requested session reset")

        // Cancel any AI operations
        aiSongCoordinator.cancelPrefetch()

        // Stop playback and clear music queue
        musicService.stop()

        // Reset session state
        sessionService.resetSession()

        // Clear direction change cache
        clearDirectionCache()

        B2BLog.session.info("✅ Session reset complete")
    }

    // MARK: - Private Methods

    private func playCurrentSong(_ song: Song) async {
        do {
            B2BLog.playback.info("Starting playback: \(song.title)")
            try await musicService.playSong(song)

            // Clear direction cache and regenerate when a new song starts playing
            // This ensures menu always shows fresh suggestions as the session evolves
            clearDirectionCache()

            // Only regenerate if it's the user's turn (menu is visible)
            if sessionService.currentTurn == .user {
                generateDirectionChange()
            }
        } catch {
            B2BLog.playback.error("Failed to play song: \(error)")
        }
    }

    private func handleSongEnded() async {
        // Use turn manager to advance to next song
        guard let (song, _) = await turnManager.advanceToNextSong() else {
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