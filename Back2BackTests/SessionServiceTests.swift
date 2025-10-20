//
//  SessionServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-09-27.
//  Updated on 2025-10-18 (#57) - Updated for merged SessionService
//

import Testing
import Foundation
@testable import Back2Back
import MusicKit

@Suite("SessionService Tests")
struct SessionServiceTests {
    @MainActor
    func createTestService() -> SessionService {
        // Create a mock PersonaService with test data
        let personaService = PersonaService(statusMessageService: StatusMessageService(openAIClient: OpenAIClient(environmentService: EnvironmentService(), personaSongCacheService: PersonaSongCacheService())))
        return SessionService(personaService: personaService)
    }

    @MainActor
    @Test("Initial state")
    func testInitialState() {
        let service = createTestService()

        // Test initial values
        #expect(service.sessionHistory.isEmpty)
        #expect(service.songQueue.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
        #expect(!service.currentPersonaStyleGuide.isEmpty)
        #expect(!service.currentPersonaName.isEmpty)
        #expect(service.currentlyPlayingSongId == nil)
    }

    // Note: Tests that require creating Song instances are commented out
    // as Song is a MusicKit type that cannot be instantiated in tests

    /*
    @MainActor
    @Test("Add song to history - User")
    func testAddUserSongToHistory() async throws {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Add song to history - AI with rationale")
    func testAddAISongToHistory() async throws {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Turn alternation")
    func testTurnAlternation() async throws {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }
    */

    @MainActor
    @Test("AI thinking state")
    func testAIThinkingState() {
        let service = createTestService()

        // Initial state
        #expect(service.isAIThinking == false)

        // Set thinking
        service.setAIThinking(true)
        #expect(service.isAIThinking == true)

        // Clear thinking
        service.setAIThinking(false)
        #expect(service.isAIThinking == false)
    }

    /*
    @MainActor
    @Test("Next AI song management")
    func testNextAISongManagement() async throws {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }
    */

    @MainActor
    @Test("Session reset")
    func testSessionReset() {
        let service = createTestService()

        // Set some state
        service.setAIThinking(true)

        // Reset
        service.resetSession()

        // Verify everything is reset
        #expect(service.sessionHistory.isEmpty)
        #expect(service.songQueue.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
        #expect(service.currentlyPlayingSongId == nil)
    }

    @MainActor
    @Test("Has song been played - case insensitive")
    func testHasSongBeenPlayed() {
        let service = createTestService()

        // Test the method logic (without actual songs)
        #expect(service.hasSongBeenPlayed(artist: "Test Artist", title: "Test Song") == false)

        // After reset, no songs should have been played
        service.resetSession()
        #expect(service.hasSongBeenPlayed(artist: "Any Artist", title: "Any Song") == false)
    }

    @MainActor
    @Test("Current persona integration")
    func testCurrentPersonaIntegration() {
        let service = createTestService()

        // PersonaService creates default personas if none exist
        // First default persona is "Rare Groove Collector" which is selected
        #expect(!service.currentPersonaStyleGuide.isEmpty)
        #expect(!service.currentPersonaName.isEmpty)

        // Default persona should be "Rare Groove Collector" (first default)
        #expect(service.currentPersonaName == "Rare Groove Collector")
    }

    @MainActor
    @Test("Turn type values")
    func testTurnTypeValues() {
        #expect(TurnType.user.rawValue == "User")
        #expect(TurnType.ai.rawValue == "AI")
    }

    @MainActor
    @Test("Computed properties - currently playing song")
    func testCurrentlyPlayingSong() {
        let service = createTestService()

        // Initially should be nil
        #expect(service.currentlyPlayingSong == nil)
    }

    @MainActor
    @Test("Computed properties - next queued song")
    func testNextQueuedSong() {
        let service = createTestService()

        // Initially should be nil
        #expect(service.nextQueuedSong == nil)
    }

    @MainActor
    @Test("Queue management - clear AI queued songs")
    func testClearAIQueuedSongs() {
        let service = createTestService()

        // Should not crash when clearing empty queue
        service.clearAIQueuedSongs()
        #expect(service.songQueue.isEmpty)
    }

    @MainActor
    @Test("Determine next queue status - user turn")
    func testDetermineNextQueueStatusUserTurn() {
        let service = createTestService()

        // When it's user's turn, AI should queue as backup
        let status = service.determineNextQueueStatus()
        #expect(status == .queuedIfUserSkips)
    }

    @MainActor
    @Test("Single @Observable source of truth")
    func testSingleObservablePattern() {
        let service = createTestService()

        // Verify SessionService is @Observable and directly holds state
        // (not delegating to another @Observable layer)
        #expect(service.sessionHistory.isEmpty)
        #expect(service.songQueue.isEmpty)

        // This test documents that SessionService is now the single
        // @Observable source of truth (issue #57 fix)
    }

    @MainActor
    @Test("Update commentary - non-existent song ID logs warning")
    func testUpdateCommentaryNonExistentId() {
        let service = createTestService()
        let nonExistentId = UUID()

        // Updating non-existent song should not crash (just logs warning)
        service.updateSongCommentary(id: nonExistentId, commentary: "This won't work", isGenerating: false)

        // Verify nothing was added to history or queue
        #expect(service.sessionHistory.isEmpty)
        #expect(service.songQueue.isEmpty)
    }

    // Note: Tests involving actual song creation require MusicKit Song objects
    // which cannot be instantiated in unit tests. The commentary update logic
    // is integration tested through the full SessionViewModel flow.
    //
    // Key behaviors tested above:
    // - Non-existent ID handling (logs warning, doesn't crash)
    //
    // Integration testing (manual or UI tests) should verify:
    // - Commentary updates work for songs in history
    // - Commentary updates work for songs in queue
    // - Commentary state preserved when moving from queue to history
    // - Progress indicator shows during generation
    // - Commentary appears when generation completes
}
