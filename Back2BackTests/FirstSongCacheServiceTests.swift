//
//  FirstSongCacheServiceTests.swift
//  Back2BackTests
//
//  Created for GitHub issue #92
//  Tests for FirstSongCacheService, specifically the clearAndRegenerateAll() method
//

import Testing
import MusicKit
import Foundation
@testable import Back2Back

@Suite("FirstSongCacheService Tests")
@MainActor
struct FirstSongCacheServiceTests {

    func createTestService() -> (
        firstSongCacheService: FirstSongCacheService,
        personaService: PersonaService,
        musicService: MockMusicService,
        coordinator: AISongCoordinator
    ) {
        let environmentService = EnvironmentService()
        let personaSongCacheService = PersonaSongCacheService()
        let openAIClient = OpenAIClient(environmentService: environmentService, personaSongCacheService: personaSongCacheService)
        let musicService = MockMusicService()
        let statusMessageService = StatusMessageService(openAIClient: openAIClient)
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(personaService: personaService)
        let toastService = ToastService()
        let songErrorLoggerService = SongErrorLoggerService()
        let songDebugService = SongDebugService()

        let coordinator = AISongCoordinator(
            openAIClient: openAIClient,
            sessionService: sessionService,
            environmentService: environmentService,
            musicService: musicService,
            musicMatcher: nil,  // Will use default StringBasedMusicMatcher
            toastService: toastService,
            personaService: personaService,
            personaSongCacheService: personaSongCacheService,
            songErrorLoggerService: songErrorLoggerService,
            songDebugService: songDebugService
        )

        let firstSongCacheService = FirstSongCacheService(
            personaService: personaService,
            musicService: musicService,
            aiSongCoordinator: coordinator,
            songDebugService: songDebugService
        )

        return (firstSongCacheService, personaService, musicService, coordinator)
    }

    @Test("FirstSongCacheService initializes successfully")
    func testInitialization() {
        let (service, _, _, _) = createTestService()

        // Service should be created successfully
        _ = service
        #expect(true)  // Test passes if we got here without crashing
    }

    @Test("clearAndRegenerateAll clears all first selections")
    func testClearAndRegenerateAllClearsSelections() async {
        let (service, personaService, _, _) = createTestService()

        // Given - Create test personas with first selections
        let persona1 = personaService.createPersona(
            name: "Test Persona 1",
            description: "Test",
            styleGuide: "Test Style 1"
        )
        let persona2 = personaService.createPersona(
            name: "Test Persona 2",
            description: "Test",
            styleGuide: "Test Style 2"
        )

        // Add mock first selections
        let mockSelection1 = CachedFirstSelection(
            recommendation: SongRecommendation(
                artist: "Test Artist 1",
                song: "Test Song 1",
                rationale: "Test rationale"
            ),
            cachedAt: Date(),
            appleMusicSong: SimplifiedSong(
                id: "test-id-1",
                title: "Test Song 1",
                artistName: "Test Artist 1",
                artworkURL: nil
            ),
            debugInfoId: nil
        )
        let mockSelection2 = CachedFirstSelection(
            recommendation: SongRecommendation(
                artist: "Test Artist 2",
                song: "Test Song 2",
                rationale: "Test rationale"
            ),
            cachedAt: Date(),
            appleMusicSong: SimplifiedSong(
                id: "test-id-2",
                title: "Test Song 2",
                artistName: "Test Artist 2",
                artworkURL: nil
            ),
            debugInfoId: nil
        )

        personaService.updateFirstSelection(for: persona1.id, selection: mockSelection1)
        personaService.updateFirstSelection(for: persona2.id, selection: mockSelection2)

        // Verify first selections exist
        #expect(personaService.personas.first { $0.id == persona1.id }?.firstSelection != nil)
        #expect(personaService.personas.first { $0.id == persona2.id }?.firstSelection != nil)

        // When - Call clearAndRegenerateAll
        // Note: We can't fully test regeneration in this test because it requires
        // actual OpenAI API calls. We focus on testing the clearing logic.
        // The method will attempt regeneration but fail due to no API key in tests,
        // which is expected and acceptable for this test.
        await service.clearAndRegenerateAll()

        // Then - Verify all first selections were cleared
        // The method clears selections first, then triggers regeneration
        // Since regeneration will fail (no API key), selections should remain nil
        #expect(personaService.personas.first { $0.id == persona1.id }?.firstSelection == nil)
        #expect(personaService.personas.first { $0.id == persona2.id }?.firstSelection == nil)

        // Cleanup - Delete test personas
        personaService.deletePersona(persona1)
        personaService.deletePersona(persona2)
    }

    @Test("refreshMissingSelections skips personas with existing cache")
    func testRefreshMissingSelectionsSkipsExistingCache() async {
        let (service, personaService, _, _) = createTestService()

        // Given - Create test persona with first selection
        let persona = personaService.createPersona(
            name: "Test Persona with Cache",
            description: "Test",
            styleGuide: "Test Style"
        )

        let mockSelection = CachedFirstSelection(
            recommendation: SongRecommendation(
                artist: "Cached Artist",
                song: "Cached Song",
                rationale: "Test rationale"
            ),
            cachedAt: Date(),
            appleMusicSong: SimplifiedSong(
                id: "cached-id",
                title: "Cached Song",
                artistName: "Cached Artist",
                artworkURL: nil
            ),
            debugInfoId: nil
        )

        personaService.updateFirstSelection(for: persona.id, selection: mockSelection)

        let selectionBeforeRefresh = personaService.personas.first { $0.id == persona.id }?.firstSelection

        // When - Call refreshMissingSelections
        await service.refreshMissingSelections()

        // Then - Verify existing cache was not changed
        let selectionAfterRefresh = personaService.personas.first { $0.id == persona.id }?.firstSelection
        #expect(selectionAfterRefresh?.recommendation.song == selectionBeforeRefresh?.recommendation.song)
        #expect(selectionAfterRefresh?.recommendation.artist == selectionBeforeRefresh?.recommendation.artist)

        // Cleanup
        personaService.deletePersona(persona)
    }
}
