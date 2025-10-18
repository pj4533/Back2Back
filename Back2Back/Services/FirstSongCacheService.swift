//
//  FirstSongCacheService.swift
//  Back2Back
//
//  Created for GitHub issue #79
//  Manages pre-caching of first song selections for instant "AI Starts" playback
//

import Foundation
import MusicKit
import OSLog

@MainActor
class FirstSongCacheService {
    private let personaService: PersonaService
    private let musicService: MusicServiceProtocol
    private let openAIClient: OpenAIClient
    private let musicMatcher: MusicMatchingProtocol

    // Track in-progress operations to prevent duplicates
    private var activeRefreshTasks: [UUID: Task<Void, Never>] = [:]

    init(
        personaService: PersonaService,
        musicService: MusicServiceProtocol,
        openAIClient: OpenAIClient,
        musicMatcher: MusicMatchingProtocol
    ) {
        self.personaService = personaService
        self.musicService = musicService
        self.openAIClient = openAIClient
        self.musicMatcher = musicMatcher

        B2BLog.general.info("FirstSongCacheService initialized")
    }

    /// Refreshes missing first selections for all personas
    /// Called on app launch and when app becomes active
    func refreshMissingSelections() async {
        B2BLog.general.info("Refreshing missing first selections for all personas")

        for persona in personaService.personas {
            // Only generate if firstSelection is nil
            if persona.firstSelection == nil {
                B2BLog.general.info("Generating missing first selection for persona: \(persona.name)")

                // Spawn background task (don't block)
                Task.detached(priority: .low) { [weak self] in
                    await self?.refreshFirstSelectionIfNeeded(for: persona.id)
                }
            }
        }
    }

    /// Generates a first selection for the given persona if one doesn't exist
    func refreshFirstSelectionIfNeeded(for personaId: UUID) async {
        // Prevent duplicate refresh tasks
        if activeRefreshTasks[personaId] != nil {
            B2BLog.general.debug("Refresh task already in progress for persona \(personaId)")
            return
        }

        // Check if persona still needs a first selection
        guard let persona = personaService.personas.first(where: { $0.id == personaId }),
              persona.firstSelection == nil else {
            B2BLog.general.debug("Persona \(personaId) already has first selection or doesn't exist")
            return
        }

        let refreshTask = Task {
            do {
                let cached = try await generateFirstSelection(for: persona)

                // Update persona with cached selection
                await MainActor.run {
                    personaService.updateFirstSelection(for: personaId, selection: cached)
                    B2BLog.general.info("✅ First selection cached for persona: \(persona.name)")
                }
            } catch {
                B2BLog.general.error("Failed to generate first selection for persona \(persona.name): \(error)")
            }

            // Remove from active tasks
            await MainActor.run {
                activeRefreshTasks[personaId] = nil
            }
        }

        activeRefreshTasks[personaId] = refreshTask
        await refreshTask.value
    }

    /// Generates a first selection for the given persona
    /// Always uses GPT-5 with low reasoning for consistent quality
    func generateFirstSelection(for persona: Persona) async throws -> CachedFirstSelection {
        B2BLog.ai.info("Generating first selection for persona: \(persona.name)")

        // Always use GPT-5 with low reasoning (no automatic mode)
        let config = AIModelConfig(
            songSelectionModel: "gpt-5",
            songSelectionReasoningLevel: .low
        )

        // Generate recommendation using OpenAIClient
        let recommendation = try await openAIClient.selectNextSong(
            persona: persona.styleGuide,
            personaId: persona.id,
            sessionHistory: [], // Empty for first selection
            directionChange: nil,
            config: config
        )

        B2BLog.ai.info("AI recommended: '\(recommendation.song)' by \(recommendation.artist)")

        // Search and match song in Apple Music
        let appleMusicSong = try await searchAndMatchSong(recommendation: recommendation, persona: persona)

        // Create CachedFirstSelection
        let cached = CachedFirstSelection(
            recommendation: recommendation,
            cachedAt: Date(),
            appleMusicSong: appleMusicSong
        )

        B2BLog.ai.info("✅ First selection generated and matched successfully")

        return cached
    }

    /// Regenerates first selection after it's been consumed
    /// Spawns low-priority background task immediately (non-blocking)
    func regenerateAfterUse(for personaId: UUID) {
        B2BLog.general.info("🔄 Triggering immediate regeneration for persona \(personaId)")

        Task.detached(priority: .low) { [weak self] in
            guard let self = self else { return }

            // Prevent duplicate regeneration tasks
            let hasDuplicateTask = await MainActor.run {
                self.activeRefreshTasks[personaId] != nil
            }

            if hasDuplicateTask {
                B2BLog.general.debug("Regeneration task already in progress for persona \(personaId)")
                return
            }

            let refreshTask = Task {
                // Get persona
                guard let persona = await MainActor.run(body: {
                    self.personaService.personas.first(where: { $0.id == personaId })
                }) else {
                    B2BLog.general.error("Persona \(personaId) not found for regeneration")
                    return
                }

                do {
                    let cached = try await self.generateFirstSelection(for: persona)

                    // Update persona with new cached selection
                    await MainActor.run {
                        self.personaService.updateFirstSelection(for: personaId, selection: cached)
                        B2BLog.general.info("✅ First selection regenerated for persona: \(persona.name)")
                    }
                } catch {
                    B2BLog.general.error("Failed to regenerate first selection for persona \(persona.name): \(error)")
                }

                // Remove from active tasks
                await MainActor.run {
                    self.activeRefreshTasks[personaId] = nil
                }
            }

            await MainActor.run {
                self.activeRefreshTasks[personaId] = refreshTask
            }

            await refreshTask.value
        }
    }

    /// Invalidates the cached first selection if the given song matches it
    /// Called when a song is played during normal session
    func invalidateFirstSelection(for personaId: UUID, song: SessionSong) {
        guard let persona = personaService.personas.first(where: { $0.id == personaId }),
              let cached = persona.firstSelection else {
            return
        }

        // Check if the played song matches the cached first selection
        let matchesArtist = song.song.artistName.lowercased() == cached.recommendation.artist.lowercased()
        let matchesTitle = song.song.title.lowercased() == cached.recommendation.song.lowercased()

        if matchesArtist && matchesTitle {
            B2BLog.general.info("🗑️ Played song matches cached first selection, invalidating cache")

            // Clear the cached selection
            personaService.clearFirstSelection(for: personaId)

            // Trigger immediate regeneration
            regenerateAfterUse(for: personaId)
        }
    }

    // MARK: - Private Helpers

    /// Searches Apple Music and matches the AI recommendation
    private func searchAndMatchSong(recommendation: SongRecommendation, persona: Persona) async throws -> SimplifiedSong? {
        B2BLog.ai.info("Searching Apple Music for: '\(recommendation.song)' by \(recommendation.artist)")

        // Use the music matcher to find and match the song
        guard let song = try await musicMatcher.searchAndMatch(recommendation: recommendation) else {
            B2BLog.ai.warning("No match found in Apple Music for first selection")
            return nil
        }

        B2BLog.ai.info("✅ Matched: '\(song.title)' by \(song.artistName)")

        // Create SimplifiedSong
        let artworkURL = song.artwork?.url(width: 300, height: 300)?.absoluteString

        return SimplifiedSong(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            artworkURL: artworkURL
        )
    }
}
