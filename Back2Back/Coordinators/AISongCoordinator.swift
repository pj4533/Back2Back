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
    private let musicMatcher: MusicMatchingProtocol
    private let toastService = ToastService.shared

    private(set) var prefetchTask: Task<Void, Never>?
    private var prefetchTaskId: UUID?

    // AI Model configuration
    private var aiModelConfig: AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
    }

    init(musicMatcher: MusicMatchingProtocol? = nil) {
        // Use provided matcher, or select based on configuration
        if let matcher = musicMatcher {
            self.musicMatcher = matcher
        } else {
            // Read configuration to determine which matcher to use
            let config = Self.loadAIModelConfig()
            self.musicMatcher = Self.createMatcher(for: config.musicMatcher)
        }
        B2BLog.session.debug("AISongCoordinator initialized with \(type(of: self.musicMatcher)) matcher")
    }

    /// Factory method to create appropriate music matcher based on configuration
    private static func createMatcher(for type: MusicMatcherType) -> MusicMatchingProtocol {
        switch type {
        case .stringBased:
            B2BLog.session.info("Using String-Based music matcher")
            return StringBasedMusicMatcher()
        case .llmBased:
            B2BLog.session.info("Using LLM-Based music matcher (Apple Intelligence)")
            return LLMBasedMusicMatcher()
        }
    }

    /// Load AI model configuration from UserDefaults
    private static func loadAIModelConfig() -> AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
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
    func prefetchAndQueueAISong(queueStatus: QueueStatus, directionChange: DirectionChange? = nil, taskId: UUID) async {
        B2BLog.ai.info("🤖 Starting AI song selection for queue position: \(queueStatus)")
        if let direction = directionChange, let firstOption = direction.options.first {
            B2BLog.ai.info("🎯 Applying direction change: \(firstOption.buttonLabel)")
        }
        B2BLog.ai.debug("Current session has \(self.sessionService.sessionHistory.count) songs played")

        // Check if this task is still valid before starting
        guard taskId == prefetchTaskId else {
            B2BLog.ai.info("⏹️ Task \(taskId) superseded by newer task, stopping")
            return
        }

        sessionService.setAIThinking(true)

        do {
            // Use retry strategy to handle song selection and matching
            let result: (Song, String)? = try await AIRetryStrategy.executeWithRetry(
                operation: {
                    // Check if task is still valid
                    guard taskId == self.prefetchTaskId else {
                        B2BLog.ai.info("⏹️ Task \(taskId) superseded during operation, stopping")
                        return nil
                    }

                    let recommendation = try await self.selectAISong(directionChange: directionChange)
                    B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
                    B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

                    // Check if user selected a song while AI was thinking
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song while AI was prefetching - cancelling AI selection")
                        return nil
                    }

                    // Check if task is still valid after AI selection
                    guard taskId == self.prefetchTaskId else {
                        B2BLog.ai.info("⏹️ Task \(taskId) superseded after AI selection, stopping")
                        return nil
                    }

                    if let song = await self.searchAndMatchSong(recommendation) {
                        // Double-check again after search
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI search - cancelling AI selection")
                            return nil
                        }

                        // Final task validity check
                        guard taskId == self.prefetchTaskId else {
                            B2BLog.ai.info("⏹️ Task \(taskId) superseded after search, stopping")
                            return nil
                        }

                        return (song, recommendation.rationale)
                    }
                    return nil
                },
                retryOperation: {
                    // Check if task is still valid before retry
                    guard taskId == self.prefetchTaskId else {
                        B2BLog.ai.info("⏹️ Task \(taskId) superseded before retry, stopping")
                        return nil
                    }

                    // Check if user selected during the failed attempt
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song during failed search - cancelling AI retry")
                        return nil
                    }

                    let retryRecommendation = try await self.selectAISong(directionChange: directionChange)
                    B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")
                    B2BLog.ai.debug("Retry rationale: \(retryRecommendation.rationale)")

                    // Check if task is still valid after retry AI selection
                    guard taskId == self.prefetchTaskId else {
                        B2BLog.ai.info("⏹️ Task \(taskId) superseded after retry selection, stopping")
                        return nil
                    }

                    if let retrySong = await self.searchAndMatchSong(retryRecommendation) {
                        // Final check if user selected during retry
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI retry - cancelling AI selection")
                            return nil
                        }

                        // Final task validity check
                        guard taskId == self.prefetchTaskId else {
                            B2BLog.ai.info("⏹️ Task \(taskId) superseded after retry search, stopping")
                            return nil
                        }

                        return (retrySong, retryRecommendation.rationale)
                    }
                    return nil
                }
            )

            // Final check before queueing
            guard taskId == prefetchTaskId else {
                B2BLog.ai.info("⏹️ Task \(taskId) superseded before queueing, stopping")
                sessionService.setAIThinking(false)
                return
            }

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
            prefetchTaskId = nil
        }
    }

    /// Start prefetching in background
    func startPrefetch(queueStatus: QueueStatus, directionChange: DirectionChange? = nil) {
        // Don't cancel existing task here - just invalidate its ID
        // This prevents race conditions where the new task checks Task.isCancelled
        if prefetchTask != nil {
            B2BLog.session.debug("Superseding existing AI prefetch task with new task")
        }

        let taskId = UUID()
        prefetchTaskId = taskId

        prefetchTask = Task.detached { [weak self] in
            await self?.prefetchAndQueueAISong(queueStatus: queueStatus, directionChange: directionChange, taskId: taskId)
        }
    }

    // MARK: - Private Methods

    private func queueAISong(_ song: Song, rationale: String?, queueStatus: QueueStatus) {
        B2BLog.ai.info("Queueing AI song: \(song.title) with status: \(queueStatus)")

        // Add to queue (not history yet)
        _ = sessionService.queueSong(song, selectedBy: .ai, rationale: rationale, queueStatus: queueStatus)

        sessionService.setAIThinking(false)
    }

    private func selectAISong(directionChange: DirectionChange? = nil) async throws -> SongRecommendation {
        B2BLog.ai.info("Selecting next AI song")

        guard environmentService.getOpenAIKey() != nil else {
            throw OpenAIError.apiKeyMissing
        }

        // Get current persona ID
        guard let currentPersona = PersonaService.shared.selectedPersona else {
            throw OpenAIError.decodingError(NSError(domain: "Back2Back", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persona selected"]))
        }

        // Determine if this is the first song
        let isFirstSong = sessionService.sessionHistory.isEmpty

        // Get config and resolve for automatic mode (handles both model and reasoning level)
        let config = aiModelConfig
        let resolvedConfig = config.resolveConfiguration(isFirstSong: isFirstSong)

        let recommendation = try await openAIClient.selectNextSong(
            persona: sessionService.currentPersonaStyleGuide,
            personaId: currentPersona.id,
            sessionHistory: sessionService.sessionHistory,
            directionChange: directionChange,
            config: resolvedConfig
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
                directionChange: directionChange,
                config: resolvedConfig
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
            let song = try await musicMatcher.searchAndMatch(recommendation: recommendation)

            // Show toast if no match found
            if song == nil {
                toastService.error(
                    "Song not found in Apple Music: '\(recommendation.song)' by '\(recommendation.artist)'",
                    duration: 5.0
                )
            }

            return song
        } catch {
            B2BLog.musicKit.error("Search and match failed: \(error)")
            toastService.error(
                "Failed to search Apple Music: \(error.localizedDescription)",
                duration: 4.0
            )
            return nil
        }
    }

    private func userHasSelectedSong() -> Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }
}
