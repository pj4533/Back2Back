//
//  AISongCoordinator.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionViewModel as part of Phase 1 refactoring (#20)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Coordinates AI song selection, matching, and queueing with retry logic
@MainActor
@Observable
final class AISongCoordinator {
    private let openAIClient = OpenAIClient.shared
    private let sessionService = SessionService.shared
    private let environmentService = EnvironmentService.shared
    private let musicService = MusicService.shared
    private let musicMatcher: MusicMatchingProtocol

    private(set) var prefetchTask: Task<Void, Never>?

    // AI Model configuration
    private var aiModelConfig: AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
    }

    init(musicMatcher: MusicMatchingProtocol? = nil) {
        self.musicMatcher = musicMatcher ?? StringBasedMusicMatcher()
        B2BLog.session.debug("AISongCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Start AI first - select and play initial song
    func handleAIStartFirst() async throws -> Song? {
        B2BLog.session.info("🤖 AI starting session first")

        sessionService.setAIThinking(true)
        defer { sessionService.setAIThinking(false) }

        return try await AIRetryStrategy.executeWithRetry(
            operation: {
                let recommendation = try await self.selectAISong()
                B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
                return await self.searchAndMatchSong(recommendation)
            },
            retryOperation: {
                let retryRecommendation = try await self.selectAISong()
                B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")
                return await self.searchAndMatchSong(retryRecommendation)
            }
        )
    }

    /// Prefetch and queue AI song for specified queue position
    func prefetchAndQueueAISong(queueStatus: QueueStatus) async {
        B2BLog.ai.info("🤖 Starting AI song selection for queue position: \(queueStatus)")
        B2BLog.ai.debug("Current session has \(self.sessionService.sessionHistory.count) songs played")
        sessionService.setAIThinking(true)

        do {
            // Use retry strategy to handle song selection and matching
            let result: (Song, String)? = try await AIRetryStrategy.executeWithRetry(
                operation: {
                    let recommendation = try await self.selectAISong()
                    B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
                    B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

                    // Check if user selected a song while AI was thinking
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song while AI was prefetching - cancelling AI selection")
                        return nil
                    }

                    if let song = await self.searchAndMatchSong(recommendation) {
                        // Double-check again after search
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI search - cancelling AI selection")
                            return nil
                        }
                        return (song, recommendation.rationale)
                    }
                    return nil
                },
                retryOperation: {
                    // Check if user selected during the failed attempt
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song during failed search - cancelling AI retry")
                        return nil
                    }

                    let retryRecommendation = try await self.selectAISong()
                    B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")
                    B2BLog.ai.debug("Retry rationale: \(retryRecommendation.rationale)")

                    if let retrySong = await self.searchAndMatchSong(retryRecommendation) {
                        // Final check if user selected during retry
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI retry - cancelling AI selection")
                            return nil
                        }
                        return (retrySong, retryRecommendation.rationale)
                    }
                    return nil
                }
            )

            // If we got a result, queue the song
            if let (song, rationale) = result {
                queueAISong(song, rationale: rationale, queueStatus: queueStatus)
                B2BLog.ai.info("✅ Successfully queued AI song: \(song.title) as \(queueStatus)")
                B2BLog.session.debug("Queue after AI selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
            }

            sessionService.setAIThinking(false)
        } catch {
            B2BLog.ai.error("❌ Failed to fetch and queue AI song: \(error)")
            sessionService.setAIThinking(false)
        }
    }

    /// Cancel any ongoing prefetch task
    func cancelPrefetch() {
        if prefetchTask != nil {
            B2BLog.session.debug("Cancelling existing AI prefetch task")
            prefetchTask?.cancel()
            prefetchTask = nil
        }
    }

    /// Start prefetching in background
    func startPrefetch(queueStatus: QueueStatus) {
        cancelPrefetch()
        prefetchTask = Task.detached { [weak self] in
            await self?.prefetchAndQueueAISong(queueStatus: queueStatus)
        }
    }

    // MARK: - Private Methods

    private func queueAISong(_ song: Song, rationale: String?, queueStatus: QueueStatus) {
        B2BLog.ai.info("Queueing AI song: \(song.title) with status: \(queueStatus)")

        // Add to SessionService queue (not history yet)
        _ = sessionService.queueSong(song, selectedBy: .ai, rationale: rationale, queueStatus: queueStatus)

        // Also add to MusicKit queue
        Task {
            do {
                try await musicService.queueNextSong(song)
                B2BLog.ai.debug("✅ Added AI song to MusicKit queue")
            } catch {
                B2BLog.ai.error("❌ Failed to add AI song to MusicKit queue: \(error)")
            }
        }

        sessionService.setAIThinking(false)
    }

    private func selectAISong() async throws -> SongRecommendation {
        B2BLog.ai.info("Selecting next AI song")

        guard environmentService.getOpenAIKey() != nil else {
            throw OpenAIError.apiKeyMissing
        }

        // Get current persona ID
        guard let currentPersona = PersonaService.shared.selectedPersona else {
            throw OpenAIError.decodingError(NSError(domain: "Back2Back", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persona selected"]))
        }

        let config = aiModelConfig
        let recommendation = try await openAIClient.selectNextSong(
            persona: sessionService.currentPersonaStyleGuide,
            personaId: currentPersona.id,
            sessionHistory: sessionService.sessionHistory,
            config: config
        )

        // Check if song has already been played
        if sessionService.hasSongBeenPlayed(artist: recommendation.artist, title: recommendation.song) {
            B2BLog.ai.warning("AI tried to select already-played song, retrying")
            // Try once more with emphasis on no repeats
            let retryPersona = sessionService.currentPersonaStyleGuide + "\n\nIMPORTANT: Never select a song that has already been played in this session."
            let retryRecommendation = try await openAIClient.selectNextSong(
                persona: retryPersona,
                personaId: currentPersona.id,
                sessionHistory: sessionService.sessionHistory,
                config: config
            )

            // Record the retry recommendation in cache
            PersonaSongCacheService.shared.recordSong(
                personaId: currentPersona.id,
                artist: retryRecommendation.artist,
                songTitle: retryRecommendation.song
            )

            return retryRecommendation
        }

        // Record the recommendation in cache
        PersonaSongCacheService.shared.recordSong(
            personaId: currentPersona.id,
            artist: recommendation.artist,
            songTitle: recommendation.song
        )

        return recommendation
    }

    private func searchAndMatchSong(_ recommendation: SongRecommendation) async -> Song? {
        do {
            return try await musicMatcher.searchAndMatch(recommendation: recommendation)
        } catch {
            B2BLog.musicKit.error("Search and match failed: \(error)")
            return nil
        }
    }

    private func userHasSelectedSong() -> Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }
}
