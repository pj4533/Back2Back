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
    private var lastSongId: String? = nil
    private var hasTriggeredEndOfSong: Bool = false

    // AI Model configuration
    private var aiModelConfig: AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
    }

    private init() {
        B2BLog.session.info("SessionViewModel initialized")
        startPlaybackMonitoring()
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
            prefetchTask = Task.detached { [weak self] in
                await self?.prefetchAndQueueAISong(queueStatus: .upNext)
            }
        } else {
            // Nothing playing - play immediately
            B2BLog.session.info("No music playing - starting playback immediately")
            sessionService.addSongToHistory(song, selectedBy: .user, queueStatus: .playing)

            // Play the song
            await playCurrentSong(song)

            // Start pre-fetching AI's next song while user's song plays
            B2BLog.session.info("Starting AI prefetch for 'upNext' position")
            prefetchTask = Task.detached { [weak self] in
                await self?.prefetchAndQueueAISong(queueStatus: .upNext)
            }
        }

        B2BLog.session.debug("Queue after user selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
    }

    func handleAIStartFirst() async {
        B2BLog.session.info("🤖 AI starting session first")

        // AI selects and plays immediately (nothing else is in queue/history)
        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")

            if let song = await searchAndMatchSong(recommendation) {
                // Add to history with "playing" status since we'll play it immediately
                sessionService.addSongToHistory(song, selectedBy: .ai, rationale: recommendation.rationale, queueStatus: .playing)

                // Play the song
                await playCurrentSong(song)

                // Clear AI thinking state - now it's the user's turn to select
                sessionService.setAIThinking(false)

                // Queue another AI song as backup in case user doesn't select
                // This ensures music never stops playing
                // Use queuedIfUserSkips so it only plays if user doesn't make a selection
                B2BLog.session.info("AI's first song playing - prefetching backup AI track")
                prefetchTask = Task.detached { [weak self] in
                    await self?.prefetchAndQueueAISong(queueStatus: .queuedIfUserSkips)
                }
            } else {
                // No good match found - retry with a new AI recommendation
                B2BLog.ai.warning("⚠️ No good match found for AI start, retrying with new selection")

                do {
                    let retryRecommendation = try await selectAISong()
                    B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")

                    if let retrySong = await searchAndMatchSong(retryRecommendation) {
                        // Add to history with "playing" status
                        sessionService.addSongToHistory(retrySong, selectedBy: .ai, rationale: retryRecommendation.rationale, queueStatus: .playing)

                        // Play the song
                        await playCurrentSong(retrySong)

                        // Clear AI thinking state
                        sessionService.setAIThinking(false)

                        // Queue backup AI track
                        B2BLog.session.info("AI retry song playing - prefetching backup AI track")
                        prefetchTask = Task.detached { [weak self] in
                            await self?.prefetchAndQueueAISong(queueStatus: .queuedIfUserSkips)
                        }
                    } else {
                        B2BLog.ai.error("❌ AI retry also failed to find matching song for start - giving up")
                        sessionService.setAIThinking(false)
                    }
                } catch {
                    B2BLog.ai.error("❌ Failed to get AI retry recommendation for start: \(error)")
                    sessionService.setAIThinking(false)
                }
            }
        } catch {
            B2BLog.ai.error("❌ Failed to start AI first: \(error)")
            sessionService.setAIThinking(false)
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

            // If this was an AI song that just started playing, we're no longer "thinking"
            // The turn is now the user's turn (they can select while this AI song plays)
            if nextSong.selectedBy == .ai {
                B2BLog.session.info("🤖 AI song now playing, clearing AI thinking state")
                sessionService.setAIThinking(false)
            }

            // If this was an AI song, queue another AI song to continue
            if nextSong.selectedBy == .ai {
                B2BLog.session.info("🤖 AI song playing, queueing another AI selection to continue")
                prefetchTask = Task.detached { [weak self] in
                    await self?.prefetchAndQueueAISong(queueStatus: .upNext)
                }
            } else {
                B2BLog.session.info("👤 User song playing, queueing AI selection as 'upNext'")
                prefetchTask = Task.detached { [weak self] in
                    await self?.prefetchAndQueueAISong(queueStatus: .upNext)
                }
            }
        } else {
            B2BLog.session.warning("⚠️ No queued song available - waiting for user selection")
            // User needs to select manually
            // Make sure AI thinking is cleared so user can select
            sessionService.setAIThinking(false)
        }
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

    private func queueAISong(_ song: Song, rationale: String?, queueStatus: QueueStatus) {
        B2BLog.ai.info("Queueing AI song: \(song.title) with status: \(queueStatus)")

        // Add to queue (not history yet)
        _ = sessionService.queueSong(song, selectedBy: .ai, rationale: rationale, queueStatus: queueStatus)

        sessionService.setAIThinking(false)
    }

    private func selectAISong() async throws -> SongRecommendation {
        B2BLog.ai.info("Selecting next AI song")

        guard environmentService.getOpenAIKey() != nil else {
            throw OpenAIError.apiKeyMissing
        }

        let config = aiModelConfig
        let recommendation = try await openAIClient.selectNextSong(
            persona: sessionService.currentPersonaStyleGuide,
            sessionHistory: sessionService.sessionHistory,
            config: config
        )

        // Check if song has already been played
        if sessionService.hasSongBeenPlayed(artist: recommendation.artist, title: recommendation.song) {
            B2BLog.ai.warning("AI tried to select already-played song, retrying")
            // Try once more with emphasis on no repeats
            let retryPersona = sessionService.currentPersonaStyleGuide + "\n\nIMPORTANT: Never select a song that has already been played in this session."
            return try await openAIClient.selectNextSong(
                persona: retryPersona,
                sessionHistory: sessionService.sessionHistory,
                config: config
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
                B2BLog.musicKit.debug("No results from combined search, trying title-only search")
                try await musicService.searchCatalog(for: recommendation.song)
                searchResults = musicService.searchResults
            }

            if searchResults.isEmpty {
                B2BLog.musicKit.warning("No search results found for: \(recommendation.song) by \(recommendation.artist)")
                return nil
            }

            // Prioritize Apple's TopResults (first 3 results are typically the most relevant)
            // Apple's search algorithm has already ranked these as best matches
            let topResults = Array(searchResults.prefix(3))
            B2BLog.musicKit.debug("Checking top \(topResults.count) results first")

            if let bestMatch = findBestMatch(topResults, artist: recommendation.artist, title: recommendation.song) {
                B2BLog.musicKit.info("✅ Found match in top results: '\(bestMatch.song.title)' by \(bestMatch.song.artistName)")
                return bestMatch.song
            }

            // Fall back to full results if top results didn't have a good match
            B2BLog.musicKit.debug("No match in top results, checking all \(searchResults.count) results")
            if let bestMatch = findBestMatch(searchResults, artist: recommendation.artist, title: recommendation.song) {
                B2BLog.musicKit.info("✅ Found match in full results: '\(bestMatch.song.title)' by \(bestMatch.song.artistName)")
                return bestMatch.song
            }

            // Return nil instead of blindly accepting first result
            // This allows the AI to retry with a different recommendation
            B2BLog.musicKit.warning("❌ No good match found for: '\(recommendation.song)' by '\(recommendation.artist)'")
            B2BLog.musicKit.debug("First result was: '\(searchResults.first?.song.title ?? "none")' by '\(searchResults.first?.song.artistName ?? "none")'")
            return nil
        } catch {
            B2BLog.musicKit.error("Search failed: \(error)")
            return nil
        }
    }

    // MARK: - String Normalization Helpers

    /// Normalizes a string for matching by handling diacritics, featuring artists, and parentheticals
    private func normalizeString(_ string: String) -> String {
        var normalized = string.lowercased()

        // Handle featuring artists - remove common variations
        normalized = normalized.replacingOccurrences(of: " feat. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " ft. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " featuring ", with: " ")
        normalized = normalized.replacingOccurrences(of: " with ", with: " ")

        // Normalize "The" prefix (common in artist names)
        if normalized.hasPrefix("the ") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove common punctuation that varies (& vs and, periods, hyphens in abbreviations)
        normalized = normalized.replacingOccurrences(of: " & ", with: " and ")
        normalized = normalized.replacingOccurrences(of: "&", with: " and ")

        // Remove periods from abbreviations (T.S.U. → TSU)
        normalized = normalized.replacingOccurrences(of: ".", with: "")

        // Normalize unicode characters (é → e, ñ → n, etc.)
        normalized = normalized.folding(options: .diacriticInsensitive, locale: .current)

        // Normalize multiple spaces to single space
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespaces)

        return normalized
    }

    /// Strips parentheticals and part numbers from titles
    /// Removes: "(Remastered)", "(Live)", "(Radio Edit)", "Pt. 1", "Part 1", etc.
    private func stripParentheticals(_ string: String) -> String {
        var cleaned = string

        // Remove parentheticals: (Remastered), (Live), etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )

        // Remove "Pt. 1", "Pt. 2", "Part 1", "Part 2", etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+Pt\.?\s*\d+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+Part\s+\d+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func findBestMatch(_ results: [MusicSearchResult], artist: String, title: String) -> MusicSearchResult? {
        // Normalize search terms
        let normalizedArtist = normalizeString(artist)
        let normalizedTitle = normalizeString(stripParentheticals(title))

        B2BLog.musicKit.debug("Looking for match - Artist: '\(normalizedArtist)', Title: '\(normalizedTitle)'")

        // Score each result
        let scoredResults = results.compactMap { result -> (result: MusicSearchResult, artistScore: Int, titleScore: Int, totalScore: Int)? in
            let song = result.song

            var artistScore = 0
            var titleScore = 0

            // Normalize result strings
            let resultArtist = normalizeString(song.artistName)
            let resultTitle = normalizeString(stripParentheticals(song.title))

            // Score artist match
            if resultArtist == normalizedArtist { artistScore = 100 }
            else if resultArtist.contains(normalizedArtist) { artistScore = 50 }
            else if normalizedArtist.contains(resultArtist) { artistScore = 25 }

            // Score title match
            if resultTitle == normalizedTitle { titleScore = 100 }
            else if resultTitle.contains(normalizedTitle) { titleScore = 50 }
            else if normalizedTitle.contains(resultTitle) { titleScore = 25 }

            let totalScore = artistScore + titleScore

            // Log details for debugging
            if totalScore >= 25 {
                B2BLog.musicKit.debug("  Candidate: '\(resultTitle)' by '\(resultArtist)' - Artist:\(artistScore) Title:\(titleScore) Total:\(totalScore)")
            }

            return (result, artistScore, titleScore, totalScore)
        }

        // CRITICAL: Require BOTH artist AND title to have some match
        // This prevents matching "I Love You" by "Trippie Redd" when looking for "I Love You" by "The Darling Dears"
        // We need at least a partial match (25+) in BOTH fields, plus a good total score
        if let best = scoredResults.max(by: { $0.totalScore < $1.totalScore }),
           best.artistScore >= 25,  // Artist must have at least partial match
           best.titleScore >= 25,   // Title must have at least partial match
           best.totalScore >= 100 { // Total score must be decent

            B2BLog.musicKit.info("✅ Found match with Artist:\(best.artistScore) Title:\(best.titleScore) Total:\(best.totalScore)")
            B2BLog.musicKit.info("   '\(best.result.song.title)' by \(best.result.song.artistName)")
            return best.result
        }

        B2BLog.musicKit.warning("❌ No match found meeting criteria (need Artist≥25, Title≥25, Total≥100)")
        if let best = scoredResults.max(by: { $0.totalScore < $1.totalScore }) {
            B2BLog.musicKit.debug("   Best candidate was: Artist:\(best.artistScore) Title:\(best.titleScore) Total:\(best.totalScore)")
            B2BLog.musicKit.debug("   '\(best.result.song.title)' by \(best.result.song.artistName)")
        }

        return nil
    }

    private func prefetchAndQueueAISong(queueStatus: QueueStatus) async {
        B2BLog.ai.info("🤖 Starting AI song selection for queue position: \(queueStatus)")
        B2BLog.ai.debug("Current session has \(self.sessionService.sessionHistory.count) songs played")
        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
            B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

            // Check if user selected a song while AI was thinking
            // If user has selected, we should abort this prefetch
            let userHasSelected = sessionService.songQueue.contains { $0.selectedBy == .user }
            if userHasSelected {
                B2BLog.ai.info("⏭️ User selected a song while AI was prefetching - cancelling AI selection")
                sessionService.setAIThinking(false)
                return
            }

            if let song = await searchAndMatchSong(recommendation) {
                // Double-check again after search (in case user selected during search)
                let userHasSelectedAfterSearch = sessionService.songQueue.contains { $0.selectedBy == .user }
                if userHasSelectedAfterSearch {
                    B2BLog.ai.info("⏭️ User selected a song during AI search - cancelling AI selection")
                    sessionService.setAIThinking(false)
                    return
                }

                queueAISong(song, rationale: recommendation.rationale, queueStatus: queueStatus)
                B2BLog.ai.info("✅ Successfully queued AI song: \(song.title) as \(queueStatus)")
                B2BLog.session.debug("Queue after AI selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
            } else {
                // No good match found - retry with a new AI recommendation
                B2BLog.ai.warning("⚠️ No good match found for AI recommendation, retrying with new selection")

                // Check if user selected during the failed attempt
                let userHasSelected = sessionService.songQueue.contains { $0.selectedBy == .user }
                if userHasSelected {
                    B2BLog.ai.info("⏭️ User selected a song during failed search - cancelling AI retry")
                    sessionService.setAIThinking(false)
                    return
                }

                // Retry once with a new recommendation
                do {
                    let retryRecommendation = try await selectAISong()
                    B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")
                    B2BLog.ai.debug("Retry rationale: \(retryRecommendation.rationale)")

                    if let retrySong = await searchAndMatchSong(retryRecommendation) {
                        // Final check if user selected during retry
                        let userHasSelectedAfterRetry = sessionService.songQueue.contains { $0.selectedBy == .user }
                        if userHasSelectedAfterRetry {
                            B2BLog.ai.info("⏭️ User selected a song during AI retry - cancelling AI selection")
                            sessionService.setAIThinking(false)
                            return
                        }

                        queueAISong(retrySong, rationale: retryRecommendation.rationale, queueStatus: queueStatus)
                        B2BLog.ai.info("✅ Successfully queued AI retry song: \(retrySong.title) as \(queueStatus)")
                        B2BLog.session.debug("Queue after AI retry - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
                    } else {
                        B2BLog.ai.error("❌ AI retry also failed to find matching song - giving up")
                        sessionService.setAIThinking(false)
                    }
                } catch {
                    B2BLog.ai.error("❌ Failed to get AI retry recommendation: \(error)")
                    sessionService.setAIThinking(false)
                }
            }
        } catch {
            B2BLog.ai.error("❌ Failed to fetch and queue AI song: \(error)")
            sessionService.setAIThinking(false)
        }
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
        // Monitor the MusicService's currentlyPlaying state
        if let nowPlaying = musicService.currentlyPlaying {
            let currentSongId = nowPlaying.song.id.rawValue
            // Get real-time playback position directly from the player
            let currentPlaybackTime = musicService.getCurrentPlaybackTime()
            let progress = nowPlaying.duration > 0 ? (currentPlaybackTime / nowPlaying.duration) : 0

            // Check if this is a new song
            if currentSongId != lastSongId {
                B2BLog.playback.info("🎵 New song detected: \(nowPlaying.song.title)")
                lastSongId = currentSongId
                hasTriggeredEndOfSong = false
                lastPlaybackTime = currentPlaybackTime

                // CRITICAL: Update the queue status to show this song is now playing
                sessionService.updateCurrentlyPlayingSong(songId: currentSongId)

                return
            }

            // Log current state for debugging (less frequently)
            if Int(currentPlaybackTime) % 10 == 0 && Int(currentPlaybackTime) != Int(lastPlaybackTime) {
                B2BLog.playback.trace("Playback - \(nowPlaying.song.title): \(Int(currentPlaybackTime))s/\(Int(nowPlaying.duration))s (\(Int(progress * 100))%)")
            }

            // Detailed logging when approaching song end
            if progress >= 0.90 && progress < 0.99 {
                B2BLog.playback.debug("📊 Near song end: \(nowPlaying.song.title) - Progress: \(String(format: "%.1f%%", progress * 100)) (\(Int(currentPlaybackTime))s/\(Int(nowPlaying.duration))s)")
                B2BLog.playback.debug("  - hasTriggeredEndOfSong: \(self.hasTriggeredEndOfSong)")
                B2BLog.playback.debug("  - Playback state: \(String(describing: self.musicService.playbackState))")
                B2BLog.playback.debug("  - Is playing: \(nowPlaying.isPlaying)")
            }

            // Check if song has ended (100% complete or very close) and we haven't triggered yet
            // Lower threshold to 97% to catch songs that might not reach exactly 99%
            if progress >= 0.97 && !hasTriggeredEndOfSong && nowPlaying.duration > 0 {
                B2BLog.playback.info("🎵 Song ending detected at \(String(format: "%.1f%%", progress * 100)) - advancing to next song")
                hasTriggeredEndOfSong = true
                B2BLog.playback.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

                // Mark current song as played before transitioning
                sessionService.markCurrentSongAsPlayed()

                // Advance to next queued song (this will set the new song as playing)
                await triggerAISelection()
            }

            lastPlaybackTime = currentPlaybackTime

        } else if lastSongId != nil {
            // Was playing but now nothing - song ended or playback stopped
            B2BLog.playback.debug("🔍 No current playback detected (lastSongId: \(self.lastSongId ?? "nil"), hasTriggeredEndOfSong: \(self.hasTriggeredEndOfSong))")

            if !hasTriggeredEndOfSong {
                B2BLog.playback.info("⏹️ Playback stopped or ended unexpectedly, advancing queue")
                B2BLog.playback.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

                hasTriggeredEndOfSong = true

                // Mark current song as played before transitioning
                sessionService.markCurrentSongAsPlayed()

                // Try to advance queue (this will set the new song as playing)
                await triggerAISelection()
            }

            lastSongId = nil
            lastPlaybackTime = 0
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