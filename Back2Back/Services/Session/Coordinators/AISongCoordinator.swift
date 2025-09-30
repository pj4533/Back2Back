//
//  AISongCoordinator.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Handles AI song selection, matching, and queueing with retry logic
//

import Foundation
import MusicKit
import OSLog

@MainActor
@Observable
final class AISongCoordinator {
    private let openAIClient: OpenAIClient
    private let sessionService: SessionService
    private let environmentService: EnvironmentService
    private let musicMatcher: MusicMatchingProtocol

    // AI Model configuration
    private var aiModelConfig: AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
    }

    init(
        openAIClient: OpenAIClient? = nil,
        sessionService: SessionService? = nil,
        environmentService: EnvironmentService? = nil,
        musicMatcher: MusicMatchingProtocol? = nil
    ) {
        self.openAIClient = openAIClient ?? .shared
        self.sessionService = sessionService ?? .shared
        self.environmentService = environmentService ?? .shared
        self.musicMatcher = musicMatcher ?? StringBasedMusicMatcher()
        B2BLog.session.debug("AISongCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Selects an AI song and plays it immediately (for starting session)
    func selectAndPlayAISongToStart() async -> Song? {
        B2BLog.ai.info("🤖 AI starting session first")

        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")

            if let song = await searchAndMatchSong(recommendation) {
                sessionService.setAIThinking(false)
                return song
            } else {
                // No good match found - retry with a new AI recommendation
                B2BLog.ai.warning("⚠️ No good match found for AI start, retrying with new selection")

                let retryResult = try await retryAISelection()
                sessionService.setAIThinking(false)
                return retryResult
            }
        } catch {
            B2BLog.ai.error("❌ Failed to start AI first: \(error)")
            sessionService.setAIThinking(false)
            return nil
        }
    }

    /// Prefetches and queues an AI song with the specified queue status
    func prefetchAndQueueAISong(queueStatus: QueueStatus) async {
        B2BLog.ai.info("🤖 Starting AI song selection for queue position: \(queueStatus)")
        B2BLog.ai.debug("Current session has \(self.sessionService.sessionHistory.count) songs played")
        sessionService.setAIThinking(true)

        do {
            let recommendation = try await selectAISong()
            B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
            B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

            // Check if user selected a song while AI was thinking
            if userHasSelectedWhileAIThinking() {
                B2BLog.ai.info("⏭️ User selected a song while AI was prefetching - cancelling AI selection")
                sessionService.setAIThinking(false)
                return
            }

            if let song = await searchAndMatchSong(recommendation) {
                // Double-check again after search (in case user selected during search)
                if userHasSelectedWhileAIThinking() {
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
                if userHasSelectedWhileAIThinking() {
                    B2BLog.ai.info("⏭️ User selected a song during failed search - cancelling AI retry")
                    sessionService.setAIThinking(false)
                    return
                }

                // Retry once with a new recommendation
                if let retrySong = try await retryAISelection() {
                    // Final check if user selected during retry
                    if userHasSelectedWhileAIThinking() {
                        B2BLog.ai.info("⏭️ User selected a song during AI retry - cancelling AI selection")
                        sessionService.setAIThinking(false)
                        return
                    }

                    queueAISong(retrySong, rationale: nil, queueStatus: queueStatus)
                    B2BLog.ai.info("✅ Successfully queued AI retry song: \(retrySong.title) as \(queueStatus)")
                    B2BLog.session.debug("Queue after AI retry - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")
                } else {
                    B2BLog.ai.error("❌ AI retry also failed to find matching song - giving up")
                    sessionService.setAIThinking(false)
                }
            }
        } catch {
            B2BLog.ai.error("❌ Failed to fetch and queue AI song: \(error)")
            sessionService.setAIThinking(false)
        }
    }

    // MARK: - Private Methods

    /// Consolidated retry logic for AI song selection
    private func retryAISelection() async throws -> Song? {
        do {
            let retryRecommendation = try await selectAISong()
            B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")

            if let retrySong = await searchAndMatchSong(retryRecommendation) {
                return retrySong
            } else {
                B2BLog.ai.error("❌ AI retry also failed to find matching song")
                return nil
            }
        } catch {
            B2BLog.ai.error("❌ Failed to get AI retry recommendation: \(error)")
            throw error
        }
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

    private func queueAISong(_ song: Song, rationale: String?, queueStatus: QueueStatus) {
        B2BLog.ai.info("Queueing AI song: \(song.title) with status: \(queueStatus)")

        // Add to queue (not history yet)
        _ = sessionService.queueSong(song, selectedBy: .ai, rationale: rationale, queueStatus: queueStatus)

        sessionService.setAIThinking(false)
    }

    private func userHasSelectedWhileAIThinking() -> Bool {
        return sessionService.songQueue.contains { $0.selectedBy == .user }
    }
}
