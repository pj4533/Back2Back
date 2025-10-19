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

/// Errors that can occur during first song cache operations
enum FirstSongCacheError: Error {
    case generationFailed
}

@MainActor
class FirstSongCacheService {
    private let personaService: PersonaService
    private let musicService: MusicServiceProtocol
    private let aiSongCoordinator: AISongCoordinator

    // Track in-progress operations to prevent duplicates
    private var activeRefreshTasks: [UUID: Task<Void, Never>] = [:]

    init(
        personaService: PersonaService,
        musicService: MusicServiceProtocol,
        aiSongCoordinator: AISongCoordinator
    ) {
        self.personaService = personaService
        self.musicService = musicService
        self.aiSongCoordinator = aiSongCoordinator

        // Observe notification for first selection consumption
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFirstSelectionConsumed(_:)),
            name: .firstSelectionConsumed,
            object: nil
        )

        B2BLog.firstSelectionCache.info("FirstSongCacheService initialized with notification observer")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Handle notification when first selection is consumed
    @objc private func handleFirstSelectionConsumed(_ notification: Notification) {
        guard let personaId = notification.userInfo?["personaId"] as? UUID else {
            B2BLog.firstSelectionCache.error("❌ firstSelectionConsumed notification missing personaId")
            return
        }

        B2BLog.firstSelectionCache.info("📬 Received firstSelectionConsumed notification for persona \(personaId)")
        regenerateAfterUse(for: personaId)
    }

    /// Refreshes missing first selections for all personas
    /// Called on app launch and when app becomes active
    func refreshMissingSelections() async {
        B2BLog.firstSelectionCache.info("🔄 Refreshing missing first selections for all personas")
        B2BLog.firstSelectionCache.info("   Total personas to check: \(self.personaService.personas.count)")

        var personasWithCache = 0
        var personasNeedingCache = 0

        for persona in self.personaService.personas {
            // Only generate if firstSelection is nil
            if persona.firstSelection == nil {
                personasNeedingCache += 1
                B2BLog.firstSelectionCache.info("📦 Cache MISSING for persona '\(persona.name)' (ID: \(persona.id)) - spawning background cache generation")

                // Spawn background task (don't block)
                Task.detached(priority: .low) { [weak self] in
                    await self?.refreshFirstSelectionIfNeeded(for: persona.id)
                }
            } else {
                personasWithCache += 1
                B2BLog.firstSelectionCache.info("✅ Cache EXISTS for persona '\(persona.name)' - skipping")
                if let cachedSong = persona.firstSelection {
                    B2BLog.firstSelectionCache.debug("   Cached: '\(cachedSong.recommendation.song)' by \(cachedSong.recommendation.artist)")
                }
            }
        }

        B2BLog.firstSelectionCache.info("📊 Cache status summary: \(personasWithCache) with cache, \(personasNeedingCache) need generation")
    }

    /// Generates a first selection for the given persona if one doesn't exist
    func refreshFirstSelectionIfNeeded(for personaId: UUID) async {
        B2BLog.firstSelectionCache.info("🔍 refreshFirstSelectionIfNeeded called for persona \(personaId)")

        // Prevent duplicate refresh tasks
        if activeRefreshTasks[personaId] != nil {
            B2BLog.firstSelectionCache.warning("⚠️ Refresh task already in progress for persona \(personaId) - skipping duplicate")
            return
        }

        // Check if persona still needs a first selection
        guard let persona = personaService.personas.first(where: { $0.id == personaId }) else {
            B2BLog.firstSelectionCache.error("❌ Persona \(personaId) not found in personas array")
            return
        }

        if persona.firstSelection != nil {
            B2BLog.firstSelectionCache.info("✅ Persona '\(persona.name)' already has first selection - skipping generation")
            return
        }

        B2BLog.firstSelectionCache.info("🚀 Starting cache generation task for persona '\(persona.name)'")

        let refreshTask = Task {
            do {
                B2BLog.firstSelectionCache.info("🎲 Calling generateFirstSelection for persona '\(persona.name)'")
                let cached = try await generateFirstSelection(for: persona)

                // Update persona with cached selection
                await MainActor.run {
                    B2BLog.firstSelectionCache.info("💾 Saving cached first selection to PersonaService for '\(persona.name)'")
                    personaService.updateFirstSelection(for: personaId, selection: cached)
                    B2BLog.firstSelectionCache.info("✅ First selection cached for persona '\(persona.name)': '\(cached.recommendation.song)' by \(cached.recommendation.artist)")
                }
            } catch {
                B2BLog.firstSelectionCache.error("❌ Failed to generate first selection for persona '\(persona.name)': \(error.localizedDescription)")
                B2BLog.firstSelectionCache.error("   Error details: \(String(describing: error))")
            }

            // Remove from active tasks
            await MainActor.run {
                B2BLog.firstSelectionCache.debug("🧹 Removing persona '\(persona.name)' from active refresh tasks")
                activeRefreshTasks[personaId] = nil
            }
        }

        activeRefreshTasks[personaId] = refreshTask
        B2BLog.firstSelectionCache.info("⏳ Awaiting completion of cache generation for persona '\(persona.name)'")
        await refreshTask.value
        B2BLog.firstSelectionCache.info("🏁 Cache generation task completed for persona '\(persona.name)'")
    }

    /// Generates a first selection for the given persona
    /// Uses the shared song selection pipeline with full quality gates
    func generateFirstSelection(for persona: Persona) async throws -> CachedFirstSelection {
        B2BLog.firstSelectionCache.info("🤖 Starting generation of first selection for persona '\(persona.name)'")
        B2BLog.firstSelectionCache.info("   Using full song selection pipeline with validation and retry logic")

        // Use the shared pipeline with empty session history
        // The pipeline will:
        // - Use user's configured AI model (respects AIModelConfig)
        // - Perform full validation via SongPersonaValidator
        // - Retry on validation failure with AIRetryStrategy
        // - Record in PersonaSongCacheService
        // - Save complete debug info to SongDebugService
        let result = try await aiSongCoordinator.executeSongSelectionPipeline(
            personaId: persona.id,
            personaStyleGuide: persona.styleGuide,
            sessionHistory: [], // Empty for first selection
            directionChange: nil,
            shouldRecordInCache: true,  // Record to prevent immediate repeats
            shouldSaveDebugInfo: true   // Save to Song Errors debug view
        )

        guard let (song, rationale, _) = result else {
            B2BLog.firstSelectionCache.error("❌ Pipeline returned no result for first selection")
            throw FirstSongCacheError.generationFailed
        }

        B2BLog.firstSelectionCache.info("🎯 AI selected: '\(song.title)' by \(song.artistName)")
        B2BLog.firstSelectionCache.debug("   Rationale: \(rationale)")

        // Convert MusicKit Song to SimplifiedSong for caching
        let artworkURL = song.artwork?.url(width: 300, height: 300)?.absoluteString

        let appleMusicSong = SimplifiedSong(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            artworkURL: artworkURL
        )

        // Create SongRecommendation for the cache (this matches the OpenAI response format)
        let recommendation = SongRecommendation(
            artist: song.artistName,
            song: song.title,
            rationale: rationale
        )

        // Create CachedFirstSelection
        let cached = CachedFirstSelection(
            recommendation: recommendation,
            cachedAt: Date(),
            appleMusicSong: appleMusicSong
        )

        B2BLog.firstSelectionCache.info("✅ First selection generated with full pipeline for persona '\(persona.name)'")
        B2BLog.firstSelectionCache.info("   ✓ Validated against persona style")
        B2BLog.firstSelectionCache.info("   ✓ Recorded in PersonaSongCache")
        B2BLog.firstSelectionCache.info("   ✓ Debug info saved to Song Errors view")

        return cached
    }

    /// Regenerates first selection after it's been consumed
    /// Spawns low-priority background task immediately (non-blocking)
    func regenerateAfterUse(for personaId: UUID) {
        B2BLog.firstSelectionCache.info("🔄 Triggering immediate regeneration after cache consumption for persona \(personaId)")

        Task.detached(priority: .low) { [weak self] in
            guard let self = self else { return }

            // Prevent duplicate regeneration tasks
            let hasDuplicateTask = await MainActor.run {
                self.activeRefreshTasks[personaId] != nil
            }

            if hasDuplicateTask {
                await MainActor.run {
                    B2BLog.firstSelectionCache.debug("⚠️ Regeneration task already in progress for persona \(personaId)")
                }
                return
            }

            let refreshTask = Task {
                // Get persona
                guard let persona = await MainActor.run(body: {
                    self.personaService.personas.first(where: { $0.id == personaId })
                }) else {
                    await MainActor.run {
                        B2BLog.firstSelectionCache.error("❌ Persona \(personaId) not found for regeneration")
                    }
                    return
                }

                do {
                    let cached = try await self.generateFirstSelection(for: persona)

                    // Update persona with new cached selection
                    await MainActor.run {
                        self.personaService.updateFirstSelection(for: personaId, selection: cached)
                        B2BLog.firstSelectionCache.info("✅ First selection regenerated for persona '\(persona.name)': '\(cached.recommendation.song)' by \(cached.recommendation.artist)")
                    }
                } catch {
                    await MainActor.run {
                        B2BLog.firstSelectionCache.error("❌ Failed to regenerate first selection for persona '\(persona.name)': \(error)")
                    }
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
            B2BLog.firstSelectionCache.info("🗑️ Played song matches cached first selection - invalidating cache and triggering regeneration")

            // Clear the cached selection
            personaService.clearFirstSelection(for: personaId)

            // Trigger immediate regeneration
            regenerateAfterUse(for: personaId)
        }
    }

}
