//
//  SessionViewModel.swift
//  Back2Back
//
//  Created on 2025-09-27.
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
    private let openAIClient = OpenAIClient.shared
    private let sessionService = SessionService.shared
    private let environmentService = EnvironmentService.shared

    private var playbackObserverTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var lastPlaybackTime: TimeInterval = 0

    private init() {
        B2BLog.session.info("SessionViewModel initialized")
        startPlaybackMonitoring()
    }

    nonisolated deinit {
        // Tasks will be cancelled automatically
    }

    // MARK: - Public Methods

    func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("Handling user song selection: \(song.title)")

        // Cancel any existing prefetch
        prefetchTask?.cancel()
        sessionService.clearNextAISong()

        // Add to history
        sessionService.addSongToHistory(song, selectedBy: .user)

        // Play the song
        await playSongAndPrefetchNext(song, selectedBy: .user)
    }

    func triggerAISelection() async {
        guard sessionService.currentTurn == .ai else {
            B2BLog.session.warning("Attempted AI selection when not AI's turn")
            return
        }

        B2BLog.session.info("Triggering immediate AI song selection")

        // Check if we have a pre-fetched song
        if let nextSong = sessionService.nextAISong {
            B2BLog.ai.info("Using pre-fetched AI song")
            await playAISong(nextSong, rationale: nil)
            return
        }

        // Otherwise, select and play immediately
        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            if let song = await searchAndMatchSong(recommendation) {
                await playAISong(song, rationale: recommendation.rationale)
            } else {
                B2BLog.ai.error("Could not find song: \(recommendation.song) by \(recommendation.artist)")
                sessionService.setAIThinking(false)
                // Skip AI turn - user needs to select manually
            }
        } catch {
            B2BLog.ai.error("Failed to get AI selection: \(error)")
            sessionService.setAIThinking(false)
        }
    }

    // MARK: - Private Methods

    private func playSongAndPrefetchNext(_ song: Song, selectedBy: TurnType) async {
        do {
            try await musicService.playSong(song)

            // If user just played, start pre-fetching AI's next song
            if selectedBy == .user {
                prefetchTask = Task.detached { [weak self] in
                    await self?.prefetchAISong()
                }
            }
        } catch {
            B2BLog.playback.error("Failed to play song: \(error)")
        }
    }

    private func playAISong(_ song: Song, rationale: String?) async {
        B2BLog.ai.info("Playing AI-selected song: \(song.title)")

        // Add to history with rationale
        sessionService.addSongToHistory(song, selectedBy: .ai, rationale: rationale)

        // Clear prefetch
        sessionService.clearNextAISong()
        sessionService.setAIThinking(false)

        // Play the song
        await playSongAndPrefetchNext(song, selectedBy: .ai)
    }

    private func selectAISong() async throws -> SongRecommendation {
        B2BLog.ai.info("Selecting next AI song")

        guard environmentService.getOpenAIKey() != nil else {
            throw OpenAIError.apiKeyMissing
        }

        let recommendation = try await openAIClient.selectNextSong(
            persona: sessionService.currentPersonaStyleGuide,
            sessionHistory: sessionService.sessionHistory
        )

        // Check if song has already been played
        if sessionService.hasSongBeenPlayed(artist: recommendation.artist, title: recommendation.song) {
            B2BLog.ai.warning("AI tried to select already-played song, retrying")
            // Try once more with emphasis on no repeats
            let retryPersona = sessionService.currentPersonaStyleGuide + "\n\nIMPORTANT: Never select a song that has already been played in this session."
            return try await openAIClient.selectNextSong(
                persona: retryPersona,
                sessionHistory: sessionService.sessionHistory
            )
        }

        return recommendation
    }

    private func searchAndMatchSong(_ recommendation: SongRecommendation) async -> Song? {
        B2BLog.musicKit.info("Searching for: \(recommendation.song) by \(recommendation.artist)")

        do {
            // Try exact search first
            try await musicService.searchCatalog(
                for: "\(recommendation.artist) \(recommendation.song)"
            )

            var searchResults = musicService.searchResults

            if searchResults.isEmpty {
                // Try with just song title
                B2BLog.musicKit.debug("No exact match, trying broader search")
                try await musicService.searchCatalog(for: recommendation.song)
                searchResults = musicService.searchResults
            }

            // Find best match
            if let bestMatch = findBestMatch(searchResults, artist: recommendation.artist, title: recommendation.song) {
                return bestMatch.song
            }

            // Fallback to first result if no good match
            if let firstResult = searchResults.first {
                B2BLog.musicKit.warning("Using first search result as fallback")
                return firstResult.song
            }

            return nil
        } catch {
            B2BLog.musicKit.error("Search failed: \(error)")
            return nil
        }
    }

    private func findBestMatch(_ results: [MusicSearchResult], artist: String, title: String) -> MusicSearchResult? {
        let lowercasedArtist = artist.lowercased()
        let lowercasedTitle = title.lowercased()

        // Score each result
        let scoredResults = results.compactMap { result -> (result: MusicSearchResult, score: Int)? in
            let song = result.song

            var score = 0

            let resultArtist = song.artistName.lowercased()
            let resultTitle = song.title.lowercased()

            // Exact matches get highest scores
            if resultArtist == lowercasedArtist { score += 100 }
            else if resultArtist.contains(lowercasedArtist) { score += 50 }
            else if lowercasedArtist.contains(resultArtist) { score += 25 }

            if resultTitle == lowercasedTitle { score += 100 }
            else if resultTitle.contains(lowercasedTitle) { score += 50 }
            else if lowercasedTitle.contains(resultTitle) { score += 25 }

            return (result, score)
        }

        // Return best match if score is high enough
        if let best = scoredResults.max(by: { $0.score < $1.score }), best.score >= 100 {
            B2BLog.musicKit.info("Found match with score \(best.score)")
            return best.result
        }

        return nil
    }

    private func prefetchAISong() async {
        B2BLog.ai.debug("Starting AI song prefetch")
        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            if let song = await searchAndMatchSong(recommendation) {
                sessionService.setNextAISong(song)
                B2BLog.ai.info("Successfully pre-fetched AI song: \(song.title)")
            }
        } catch {
            B2BLog.ai.error("Failed to prefetch AI song: \(error)")
        }

        sessionService.setAIThinking(false)
    }

    // MARK: - Playback Monitoring

    private func startPlaybackMonitoring() {
        playbackObserverTask = Task { [weak self] in
            guard let self = self else { return }

            B2BLog.playback.debug("Starting playback monitoring")

            // Create a timer that checks playback state periodically
            while !Task.isCancelled {
                await self.checkPlaybackState()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }

    private func checkPlaybackState() async {
        // Note: We can't access private player directly
        // This monitoring would need to be implemented differently
        // For now, rely on explicit user actions
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