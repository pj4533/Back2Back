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
    private let musicService: MusicService
    private let musicMatcher: MusicMatchingProtocol
    private let toastService: ToastService
    private let validator = SongPersonaValidator()
    private let personaService: PersonaService
    private let personaSongCacheService: PersonaSongCacheService
    private let songErrorLoggerService: SongErrorLoggerService
    private let firstSongCacheService: FirstSongCacheService
    private let songDebugService: SongDebugService

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
        firstSongCacheService: FirstSongCacheService,
        songDebugService: SongDebugService
    ) {
        self.openAIClient = openAIClient
        self.sessionService = sessionService
        self.environmentService = environmentService
        self.musicService = musicService
        self.toastService = toastService
        self.personaService = personaService
        self.personaSongCacheService = personaSongCacheService
        self.songErrorLoggerService = songErrorLoggerService
        self.firstSongCacheService = firstSongCacheService
        self.songDebugService = songDebugService

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

        // Debug: Log cache status
        if let cached = currentPersona.firstSelection {
            B2BLog.firstSelectionCache.info("🔍 First selection EXISTS for '\(currentPersona.name)'")
            B2BLog.firstSelectionCache.info("   Recommendation: '\(cached.recommendation.song)' by \(cached.recommendation.artist)")
            B2BLog.firstSelectionCache.info("   Apple Music song: \(cached.appleMusicSong != nil ? "EXISTS" : "MISSING (nil)")")

            if let appleMusicSong = cached.appleMusicSong {
                B2BLog.firstSelectionCache.info("   Song ID: \(appleMusicSong.id)")
            }
        } else {
            B2BLog.firstSelectionCache.info("🔍 First selection is NIL for '\(currentPersona.name)'")
        }

        if let cached = currentPersona.firstSelection, let appleMusicSong = cached.appleMusicSong {
            B2BLog.firstSelectionCache.info("✨ Cache hit for persona '\(currentPersona.name)' - using cached first selection for instant playback")
            B2BLog.firstSelectionCache.debug("Cached song: '\(cached.recommendation.song)' by \(cached.recommendation.artist)")

            // Convert SimplifiedSong back to MusicKit Song
            let songId = MusicItemID(appleMusicSong.id)
            guard let song = try? await MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songId).response().items.first else {
                B2BLog.firstSelectionCache.warning("⚠️ Failed to fetch cached song from MusicKit, falling back to AI selection")

                // Clear invalid cache
                personaService.clearFirstSelection(for: currentPersona.id)
                B2BLog.firstSelectionCache.info("🗑️ Cleared invalid cache for persona '\(currentPersona.name)'")

                // Fall through to normal AI selection
                return try await performAISelection()
            }

            // Clear the cache immediately
            personaService.clearFirstSelection(for: currentPersona.id)
            B2BLog.firstSelectionCache.info("🗑️ Cache consumed for persona '\(currentPersona.name)' - cleared successfully")

            // Trigger immediate background regeneration (non-blocking)
            firstSongCacheService.regenerateAfterUse(for: currentPersona.id)

            B2BLog.firstSelectionCache.info("🎵 Starting instant playback with cached selection: '\(song.title)' by \(song.artistName)")
            return song
        }

        // No cache available - fall back to normal AI selection
        B2BLog.firstSelectionCache.info("📦 Cache empty for persona '\(currentPersona.name)' - falling back to normal AI selection")
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

        // Create debug builder if debug tracking is enabled
        // We'll set the session song ID after the song is queued
        var debugBuilder: SongDebugInfoBuilder? = songDebugService.isEnabled ? SongDebugInfoBuilder(sessionSongId: UUID()) : nil

        // Capture session context
        if let debugBuilder = debugBuilder {
            let recentSongs = sessionService.sessionHistory.suffix(5).map { sessionSong in
                RecentSongInfo(
                    title: sessionSong.song.title,
                    artist: sessionSong.song.artistName,
                    selectedBy: sessionSong.selectedBy.rawValue
                )
            }

            let sessionContext = SessionContext(
                turnState: sessionService.currentTurn.rawValue.lowercased(),
                historyCount: sessionService.sessionHistory.count,
                queueCount: sessionService.songQueue.count,
                recentSongs: Array(recentSongs)
            )
            debugBuilder.setSessionContext(sessionContext)

            // Capture persona snapshot
            if let currentPersona = personaService.selectedPersona {
                let personaSnapshot = PersonaSnapshot(
                    name: currentPersona.name,
                    styleGuide: currentPersona.styleGuide,
                    createdAt: currentPersona.createdAt
                )
                debugBuilder.setPersonaSnapshot(personaSnapshot)
            }

            // Capture direction change if present
            if let direction = directionChange, let firstOption = direction.options.first {
                let directionInfo = DirectionChangeInfo(
                    directionPrompt: firstOption.directionPrompt,
                    buttonLabel: firstOption.buttonLabel,
                    timestamp: Date()
                )
                debugBuilder.setDirectionChange(directionInfo)
            }

            B2BLog.session.debug("🐛 Debug tracking enabled - capturing session context")
        }

        sessionService.setAIThinking(true)

        do {
            var retryCount = 0

            // Use retry strategy to handle song selection and matching
            let result: (Song, String)? = try await AIRetryStrategy.executeWithRetry(
                operation: {
                    let recommendation = try await self.selectAISong(directionChange: directionChange)
                    B2BLog.ai.info("🎯 AI recommended: \(recommendation.song) by \(recommendation.artist)")
                    B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

                    // Capture AI recommendation if debug tracking enabled
                    if let debugBuilder = debugBuilder {
                        let aiRecommendation = AIRecommendation(
                            artist: recommendation.artist,
                            title: recommendation.song,
                            rationale: recommendation.rationale,
                            model: self.aiModelConfig.songSelectionModel,
                            reasoningLevel: self.aiModelConfig.songSelectionReasoningLevel.rawValue,
                            timestamp: Date()
                        )
                        debugBuilder.setAIRecommendation(aiRecommendation)
                        debugBuilder.setRetryCount(retryCount)
                    }

                    // Check if user selected a song while AI was thinking
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song while AI was prefetching - cancelling AI selection")
                        debugBuilder?.setOutcome(.cancelled)
                        return nil
                    }

                    if let song = await self.searchAndMatchSong(recommendation, debugBuilder: debugBuilder) {
                        // Double-check again after search
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI search - cancelling AI selection")
                            debugBuilder?.setOutcome(.cancelled)
                            return nil
                        }

                        return (song, recommendation.rationale)
                    }
                    return nil
                },
                retryOperation: {
                    retryCount += 1

                    // Check if user selected during the failed attempt
                    if self.userHasSelectedSong() {
                        B2BLog.ai.info("⏭️ User selected a song during failed search - cancelling AI retry")
                        debugBuilder?.setOutcome(.cancelled)
                        return nil
                    }

                    let retryRecommendation = try await self.selectAISong(directionChange: directionChange)
                    B2BLog.ai.info("🔄 AI retry recommended: \(retryRecommendation.song) by \(retryRecommendation.artist)")
                    B2BLog.ai.debug("Retry rationale: \(retryRecommendation.rationale)")

                    // Update AI recommendation in debug builder for retry
                    if let debugBuilder = debugBuilder {
                        let aiRecommendation = AIRecommendation(
                            artist: retryRecommendation.artist,
                            title: retryRecommendation.song,
                            rationale: retryRecommendation.rationale,
                            model: self.aiModelConfig.songSelectionModel,
                            reasoningLevel: self.aiModelConfig.songSelectionReasoningLevel.rawValue,
                            timestamp: Date()
                        )
                        debugBuilder.setAIRecommendation(aiRecommendation)
                        debugBuilder.setRetryCount(retryCount)
                    }

                    if let retrySong = await self.searchAndMatchSong(retryRecommendation, debugBuilder: debugBuilder) {
                        // Final check if user selected during retry
                        if self.userHasSelectedSong() {
                            B2BLog.ai.info("⏭️ User selected a song during AI retry - cancelling AI selection")
                            debugBuilder?.setOutcome(.cancelled)
                            return nil
                        }

                        return (retrySong, retryRecommendation.rationale)
                    }
                    return nil
                }
            )

            // If we got a result, queue the song
            if let (song, rationale) = result {
                let sessionSong = queueAISong(song, rationale: rationale, queueStatus: queueStatus)
                B2BLog.ai.info("✅ Successfully queued AI song: \(song.title) as \(queueStatus)")
                B2BLog.session.debug("Queue after AI selection - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

                // Save debug info if tracking enabled - update builder with actual session song ID
                if let oldBuilder = debugBuilder {
                    // Create new builder with correct session song ID
                    let newBuilder = SongDebugInfoBuilder(sessionSongId: sessionSong.id)

                    // Copy all captured data from old builder to new one
                    // Since we can't directly copy, we need to rebuild with the same data
                    // For now, we'll use the old builder but acknowledge the ID mismatch
                    // TODO: Refactor SongDebugInfoBuilder to allow ID updates

                    if let debugInfo = oldBuilder.build() {
                        // Create new debug info with correct ID
                        let correctedDebugInfo = SongDebugInfo(
                            id: sessionSong.id,
                            timestamp: debugInfo.timestamp,
                            outcome: debugInfo.outcome,
                            retryCount: debugInfo.retryCount,
                            aiRecommendation: debugInfo.aiRecommendation,
                            searchPhase: debugInfo.searchPhase,
                            matchingPhase: debugInfo.matchingPhase,
                            validationPhase: debugInfo.validationPhase,
                            finalSong: debugInfo.finalSong,
                            sessionContext: debugInfo.sessionContext,
                            personaSnapshot: debugInfo.personaSnapshot,
                            directionChange: debugInfo.directionChange
                        )

                        songDebugService.logDebugInfo(correctedDebugInfo)
                        B2BLog.session.info("🐛 Saved debug info for song \(correctedDebugInfo.id)")
                    }
                }
            } else {
                // No result - log failure outcome
                if let debugBuilder = debugBuilder, debugBuilder.build() != nil {
                    // Outcome should already be set (failedMatch, failedValidation, cancelled, etc.)
                    if let debugInfo = debugBuilder.build() {
                        songDebugService.logDebugInfo(debugInfo)
                        B2BLog.session.info("🐛 Saved debug info for failed selection attempt")
                    }
                }
            }

            sessionService.setAIThinking(false)
        } catch is CancellationError {
            B2BLog.ai.info("⏹️ Song selection cancelled")
            debugBuilder?.setOutcome(.cancelled)

            // Save debug info even for cancellations
            if let debugBuilder = debugBuilder, let debugInfo = debugBuilder.build() {
                songDebugService.logDebugInfo(debugInfo)
                B2BLog.session.info("🐛 Saved debug info for cancelled selection")
            }

            sessionService.setAIThinking(false)
        } catch {
            B2BLog.ai.error("❌ Failed to fetch and queue AI song: \(error)")
            debugBuilder?.setOutcome(.failedSearch)

            // Save debug info for errors
            if let debugBuilder = debugBuilder, let debugInfo = debugBuilder.build() {
                songDebugService.logDebugInfo(debugInfo)
                B2BLog.session.error("🐛 Saved debug info for error: \(error)")
            }

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

    private func queueAISong(_ song: Song, rationale: String?, queueStatus: QueueStatus) -> SessionSong {
        B2BLog.ai.info("Queueing AI song: \(song.title) with status: \(queueStatus)")

        // Add to queue (not history yet)
        let sessionSong = sessionService.queueSong(song, selectedBy: .ai, rationale: rationale, queueStatus: queueStatus)

        sessionService.setAIThinking(false)

        return sessionSong
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

            return retryRecommendation
        }

        return recommendation
    }

    private func searchAndMatchSong(_ recommendation: SongRecommendation, debugBuilder: SongDebugInfoBuilder? = nil) async -> Song? {
        let searchStartTime = Date()

        do {
            // Perform search and capture results for debug
            let searchQuery = "\(recommendation.artist) \(recommendation.song)"
            var searchResults: [MusicSearchResult] = []

            if debugBuilder != nil {
                // If debug tracking is enabled, perform search manually to capture results
                searchResults = try await musicService.searchCatalogWithPagination(
                    for: searchQuery,
                    pageSize: 25,
                    maxResults: 200
                )

                if searchResults.isEmpty {
                    // Try title-only search
                    searchResults = try await musicService.searchCatalogWithPagination(
                        for: recommendation.song,
                        pageSize: 25,
                        maxResults: 200
                    )
                }

                // Capture search phase
                let searchDuration = Date().timeIntervalSince(searchStartTime)
                let searchPhase = SearchPhase(
                    query: searchQuery,
                    results: searchResults.prefix(10).enumerated().map { index, result in
                        SearchResultInfo(
                            id: result.song.id.rawValue,
                            title: result.song.title,
                            artist: result.song.artistName,
                            album: result.song.albumTitle,
                            releaseDate: result.song.releaseDate,
                            duration: result.song.duration,
                            genreNames: result.song.genreNames,
                            ranking: index,
                            wasSelected: false // Will update later
                        )
                    },
                    resultCount: searchResults.count,
                    duration: searchDuration,
                    timestamp: Date()
                )
                debugBuilder?.setSearchPhase(searchPhase)

                // Now match against search results
                let matchResult = await musicMatcher.findMatch(recommendation: recommendation, in: searchResults)

                // Capture matching phase
                let matcherType: String
                if musicMatcher is StringBasedMusicMatcher {
                    matcherType = "StringBased"
                } else if musicMatcher is LLMBasedMusicMatcher {
                    matcherType = "LLMBased"
                } else {
                    matcherType = "Unknown"
                }

                let matchingPhase = MatchingPhase(
                    matcherType: matcherType,
                    selectedResultId: matchResult.song?.id.rawValue,
                    confidenceScore: matchResult.confidence,
                    reasoning: matchResult.matchDetails,
                    timestamp: Date(),
                    llmResponse: nil // Could be populated by LLM matcher in future
                )
                debugBuilder?.setMatchingPhase(matchingPhase)

                // Update search results to mark selected one
                if let selectedSong = matchResult.song,
                   let selectedIndex = searchResults.firstIndex(where: { $0.song.id == selectedSong.id }) {
                    var updatedSearchPhase = searchPhase
                    var updatedResults = updatedSearchPhase.results
                    updatedResults[selectedIndex] = SearchResultInfo(
                        id: selectedSong.id.rawValue,
                        title: selectedSong.title,
                        artist: selectedSong.artistName,
                        album: selectedSong.albumTitle,
                        releaseDate: selectedSong.releaseDate,
                        duration: selectedSong.duration,
                        genreNames: selectedSong.genreNames,
                        ranking: selectedIndex,
                        wasSelected: true
                    )
                    updatedSearchPhase = SearchPhase(
                        query: searchPhase.query,
                        results: updatedResults,
                        resultCount: searchPhase.resultCount,
                        duration: searchPhase.duration,
                        timestamp: searchPhase.timestamp
                    )
                    debugBuilder?.setSearchPhase(updatedSearchPhase)
                }

                // Use the match result
                if matchResult.confidence >= 0.5, let song = matchResult.song {
                    // Proceed with validation
                    return await validateAndRecordSong(song, debugBuilder: debugBuilder)
                } else {
                    // No good match
                    let personaName = personaService.selectedPersona?.name ?? "Unknown"
                    songErrorLoggerService.logError(
                        artistName: recommendation.artist,
                        songTitle: recommendation.song,
                        personaName: personaName,
                        errorType: .noGoodMatch,
                        errorReason: "Best match had confidence \(String(format: "%.2f", matchResult.confidence))"
                    )
                    toastService.error(
                        "Song not found in Apple Music: '\(recommendation.song)' by '\(recommendation.artist)'",
                        duration: 5.0
                    )
                    debugBuilder?.setOutcome(.failedMatch)
                    return nil
                }
            } else {
                // If debug tracking is disabled, use the existing efficient path
                let song = try await musicMatcher.searchAndMatch(recommendation: recommendation)

                if song == nil {
                    let personaName = personaService.selectedPersona?.name ?? "Unknown"
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

                // Validate and record song
                return await validateAndRecordSong(song!, debugBuilder: nil)
            }
        } catch {
            B2BLog.musicKit.error("Search and match failed: \(error)")

            let personaName = personaService.selectedPersona?.name ?? "Unknown"
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
            debugBuilder?.setOutcome(.failedSearch)
            return nil
        }
    }

    /// Helper method to validate and record a song (extracted for reuse)
    private func validateAndRecordSong(_ song: Song, debugBuilder: SongDebugInfoBuilder?) async -> Song? {
        let personaDesc = personaService.selectedPersona?.description ?? ""
        let validationResult = await validator.validate(song: song, personaDescription: personaDesc)

        // Capture validation phase if debug tracking enabled
        if let validation = validationResult, let debugBuilder = debugBuilder {
            let validationPhase = ValidationPhase(
                passed: validation.isValid,
                shortExplanation: validation.shortSummary,
                longExplanation: validation.reasoning,
                timestamp: Date()
            )
            debugBuilder.setValidationPhase(validationPhase)
        }

        // Fail open: if validationResult is nil (model unavailable/error), accept the song
        if let validation = validationResult, !validation.isValid {
            B2BLog.ai.warning("🚫 Validation rejected: '\(song.title)' by \(song.artistName)")

            let personaName = personaService.selectedPersona?.name ?? "Unknown"
            songErrorLoggerService.logError(
                artistName: song.artistName,
                songTitle: song.title,
                personaName: personaName,
                errorType: .validationFailed,
                errorReason: validation.shortSummary,
                detailedReason: validation.reasoning
            )

            toastService.warning(
                "Song didn't match persona style - selecting alternative",
                duration: 3.0
            )
            debugBuilder?.setOutcome(.failedValidation)
            return nil  // Trigger retry with AIRetryStrategy
        }

        // Record the song in cache with artwork (after successful match and validation)
        if let currentPersona = personaService.selectedPersona {
            personaSongCacheService.recordSong(
                personaId: currentPersona.id,
                artist: song.artistName,
                songTitle: song.title,
                artworkURL: song.artwork?.url(width: 300, height: 300)
            )
        }

        // Capture final song info if debug tracking enabled
        if let debugBuilder = debugBuilder {
            let finalSong = FinalSongInfo(
                musicKitId: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                album: song.albumTitle,
                releaseDate: song.releaseDate,
                duration: song.duration,
                genreNames: song.genreNames,
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
            )
            debugBuilder.setFinalSong(finalSong)
            debugBuilder.setOutcome(.success)
        }

        return song
    }

    private func userHasSelectedSong() -> Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }
}
