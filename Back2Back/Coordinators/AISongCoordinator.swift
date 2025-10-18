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
    private let openAIClient: any AIRecommendationServiceProtocol
    private let sessionService: SessionService
    private let environmentService: EnvironmentService
    private let musicMatcher: MusicMatchingProtocol
    private let toastService: ToastService
    private let validator = SongPersonaValidator()
    private let personaService: PersonaService
    private let personaSongCacheService: PersonaSongCacheService
    private let songErrorLoggerService: SongErrorLoggerService
    private let firstSongCacheService: FirstSongCacheService

    private(set) var prefetchTask: Task<Void, Never>?

    // AI Model configuration
    private var aiModelConfig: AIModelConfig {
        guard let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
              let config = try? JSONDecoder().decode(AIModelConfig.self, from: data) else {
            return .default
        }
        return config
    }

    init(
        openAIClient: any AIRecommendationServiceProtocol,
        sessionService: SessionService,
        environmentService: EnvironmentService,
        musicService: MusicService,
        musicMatcher: MusicMatchingProtocol? = nil,
        toastService: ToastService,
        personaService: PersonaService,
        personaSongCacheService: PersonaSongCacheService,
        songErrorLoggerService: SongErrorLoggerService,
        firstSongCacheService: FirstSongCacheService
    ) {
        self.openAIClient = openAIClient
        self.sessionService = sessionService
        self.environmentService = environmentService
        self.toastService = toastService
        self.personaService = personaService
        self.personaSongCacheService = personaSongCacheService
        self.songErrorLoggerService = songErrorLoggerService
        self.firstSongCacheService = firstSongCacheService

        // Use provided matcher, or select based on configuration
        if let matcher = musicMatcher {
            self.musicMatcher = matcher
        } else {
            // Read configuration to determine which matcher to use
            let config = Self.loadAIModelConfig()
            self.musicMatcher = Self.createMatcher(
                for: config.musicMatcher,
                musicService: musicService,
                personaService: personaService,
                songErrorLoggerService: songErrorLoggerService
            )
        }
        B2BLog.session.debug("AISongCoordinator initialized with \(type(of: self.musicMatcher)) matcher")
    }

    /// Factory method to create appropriate music matcher based on configuration
    private static func createMatcher(
        for type: MusicMatcherType,
        musicService: MusicService,
        personaService: PersonaService,
        songErrorLoggerService: SongErrorLoggerService
    ) -> MusicMatchingProtocol {
        switch type {
        case .stringBased:
            B2BLog.session.info("Using String-Based music matcher")
            return StringBasedMusicMatcher(
                musicService: musicService,
                personaService: personaService,
                songErrorLoggerService: songErrorLoggerService
            )
        case .llmBased:
            B2BLog.session.info("Using LLM-Based music matcher (Apple Intelligence)")
            return LLMBasedMusicMatcher(
                musicService: musicService,
                personaService: personaService,
                songErrorLoggerService: songErrorLoggerService
            )
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
    /// Checks for cached first selection for instant playback
    func handleAIStartFirst() async throws -> Song? {
        B2BLog.session.info("🤖 AI starting session first")

        // Check for cached first selection
        guard let currentPersona = personaService.selectedPersona else {
            throw OpenAIError.decodingError(NSError(domain: "Back2Back", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persona selected"]))
        }

        if let cached = currentPersona.firstSelection, let appleMusicSong = cached.appleMusicSong {
            B2BLog.session.info("✨ Using cached first selection for instant playback")

            // Convert SimplifiedSong back to MusicKit Song
            let songId = MusicItemID(appleMusicSong.id)
            guard let song = try? await MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songId).response().items.first else {
                B2BLog.session.warning("Failed to fetch cached song from MusicKit, falling back to AI selection")

                // Clear invalid cache
                personaService.clearFirstSelection(for: currentPersona.id)

                // Fall through to normal AI selection
                return try await performAISelection()
            }

            // Clear the cache immediately
            personaService.clearFirstSelection(for: currentPersona.id)

            // Trigger immediate background regeneration (non-blocking)
            firstSongCacheService.regenerateAfterUse(for: currentPersona.id)

            B2BLog.session.info("🎵 Instant playback with cached selection: \(song.title) by \(song.artistName)")
            return song
        }

        // No cache available - fall back to normal AI selection
        B2BLog.session.info("No cached first selection available, proceeding with AI selection")
        return try await performAISelection()
    }

    /// Performs standard AI selection with retry logic
    private func performAISelection() async throws -> Song? {
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
    func prefetchAndQueueAISong(queueStatus: QueueStatus, directionChange: DirectionChange? = nil) async {
        B2BLog.ai.info("🤖 Starting AI song selection for queue position: \(queueStatus)")
        if let direction = directionChange, let firstOption = direction.options.first {
            B2BLog.ai.info("🎯 Applying direction change: \(firstOption.buttonLabel)")
        }
        B2BLog.ai.debug("Current session has \(self.sessionService.sessionHistory.count) songs played")

        // Check if task was cancelled before starting
        guard !Task.isCancelled else {
            B2BLog.ai.info("⏹️ Task cancelled before starting")
            return
        }

        sessionService.setAIThinking(true)

        do {
            // Use retry strategy to handle song selection and matching
            let result: (Song, String)? = try await AIRetryStrategy.executeWithRetry(
                operation: {
                    let recommendation = try await self.selectAISong(directionChange: directionChange)
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

                    let retryRecommendation = try await self.selectAISong(directionChange: directionChange)
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
        } catch is CancellationError {
            B2BLog.ai.info("⏹️ Song selection cancelled")
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
    func startPrefetch(queueStatus: QueueStatus, directionChange: DirectionChange? = nil) {
        // Properly cancel existing task before starting new one
        prefetchTask?.cancel()

        prefetchTask = Task {
            await withTaskCancellationHandler {
                await self.prefetchAndQueueAISong(queueStatus: queueStatus, directionChange: directionChange)
            } onCancel: {
                // Immediate cleanup on cancellation
                Task { @MainActor in
                    self.sessionService.setAIThinking(false)
                    B2BLog.ai.info("⏹️ Prefetch task cancelled via cancellation handler")
                }
            }
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
        guard let currentPersona = personaService.selectedPersona else {
            throw OpenAIError.decodingError(NSError(domain: "Back2Back", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persona selected"]))
        }

        // Get config (no resolution needed - using configured model directly)
        let config = aiModelConfig

        let recommendation = try await openAIClient.selectNextSong(
            persona: sessionService.currentPersonaStyleGuide,
            personaId: currentPersona.id,
            sessionHistory: sessionService.sessionHistory,
            directionChange: directionChange,
            config: config
        )

        // Check if song has already been played
        if sessionService.hasSongBeenPlayed(artist: recommendation.artist, title: recommendation.song) {
            B2BLog.ai.warning("AI tried to select already-played song, retrying")

            // Log error for debugging
            songErrorLoggerService.logError(
                artistName: recommendation.artist,
                songTitle: recommendation.song,
                personaName: currentPersona.name,
                errorType: .alreadyPlayed,
                errorReason: "Song was already played in current session"
            )

            // Try once more with emphasis on no repeats
            let retryPersona = sessionService.currentPersonaStyleGuide + "\n\nIMPORTANT: Never select a song that has already been played in this session."
            let retryRecommendation = try await openAIClient.selectNextSong(
                persona: retryPersona,
                personaId: currentPersona.id,
                sessionHistory: sessionService.sessionHistory,
                directionChange: directionChange,
                config: config
            )

            // Record the retry recommendation in cache
            personaSongCacheService.recordSong(
                personaId: currentPersona.id,
                artist: retryRecommendation.artist,
                songTitle: retryRecommendation.song
            )

            return retryRecommendation
        }

        // Record the recommendation in cache
        personaSongCacheService.recordSong(
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
                let personaName = personaService.selectedPersona?.name ?? "Unknown"

                // Log error for debugging
                songErrorLoggerService.logError(
                    artistName: recommendation.artist,
                    songTitle: recommendation.song,
                    personaName: personaName,
                    errorType: .notFoundInAppleMusic,
                    errorReason: "No search results found in Apple Music"
                )

                toastService.error(
                    "Song not found in Apple Music: '\(recommendation.song)' by '\(recommendation.artist)'",
                    duration: 5.0
                )
                return nil
            }

            // ✨ NEW: Validate song matches persona before accepting
            if let matchedSong = song {
                let personaDesc = personaService.selectedPersona?.description ?? ""
                let validationResult = await validator.validate(song: matchedSong, personaDescription: personaDesc)

                // Fail open: if validationResult is nil (model unavailable/error), accept the song
                if let validation = validationResult, !validation.isValid {
                    B2BLog.ai.warning("🚫 Validation rejected: '\(matchedSong.title)' by \(matchedSong.artistName)")

                    let personaName = personaService.selectedPersona?.name ?? "Unknown"

                    // Log error for debugging with both short and detailed reasons
                    songErrorLoggerService.logError(
                        artistName: matchedSong.artistName,
                        songTitle: matchedSong.title,
                        personaName: personaName,
                        errorType: .validationFailed,
                        errorReason: validation.shortSummary,
                        detailedReason: validation.reasoning
                    )

                    toastService.warning(
                        "Song didn't match persona style - selecting alternative",
                        duration: 3.0
                    )
                    return nil  // Trigger retry with AIRetryStrategy
                }
            }

            return song
        } catch {
            B2BLog.musicKit.error("Search and match failed: \(error)")

            let personaName = personaService.selectedPersona?.name ?? "Unknown"

            // Log error for debugging
            songErrorLoggerService.logError(
                artistName: recommendation.artist,
                songTitle: recommendation.song,
                personaName: personaName,
                errorType: .searchError,
                errorReason: error.localizedDescription
            )

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
