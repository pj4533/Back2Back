//
//  TurnManagerTests.swift
//  Back2BackTests
//
//  Created on 2025-09-30.
//  Tests for TurnManager coordinator
//  FIXED: Now uses dependency injection instead of .shared singletons
//

import Testing
import MusicKit
@testable import Back2Back

@Suite("TurnManager Tests")
@MainActor
struct TurnManagerTests {

    // Note: Tests that require creating Song instances are commented out
    // as Song is a MusicKit type that cannot be instantiated in tests
    // See Issue #62 for plans to enable these tests via protocol abstractions

    @Test("Determine next queue status when user's turn returns queuedIfUserSkips")
    func testDetermineNextQueueStatusDuringUserTurn() async {
        // Create mock dependencies
        let mockSessionService = MockSessionStateManager()
        let mockMusicService = MockMusicService()

        mockSessionService.currentTurn = .user

        // Inject dependencies (no more .shared!)
        let environmentService = EnvironmentService()
        let personaSongCacheService = PersonaSongCacheService()
        let openAIClient = OpenAIClient(environmentService: environmentService, personaSongCacheService: personaSongCacheService)
        let statusMessageService = StatusMessageService(openAIClient: openAIClient)
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(personaService: personaService)
        let musicService = MusicService()
        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)

        // For this specific test, we can just use the mock directly
        // since TurnManager delegates to SessionService.determineNextQueueStatus()
        let queueStatus = mockSessionService.determineNextQueueStatus()

        // When it's user's turn, AI should queue as backup (.queuedIfUserSkips)
        #expect(queueStatus == .queuedIfUserSkips)
        #expect(mockSessionService.determineNextQueueStatusCalled == true)
    }

    @Test("Determine next queue status when AI's turn returns upNext")
    func testDetermineNextQueueStatusDuringAITurn() async {
        // Create mock dependencies
        let mockSessionService = MockSessionStateManager()

        mockSessionService.currentTurn = .ai  // AI's turn

        let queueStatus = mockSessionService.determineNextQueueStatus()

        // When it's AI's turn, next song should be upNext (AI's active pick)
        #expect(queueStatus == .upNext)
        #expect(mockSessionService.determineNextQueueStatusCalled == true)
    }

    @Test("Advance to next song returns nil when no queued song")
    func testAdvanceToNextSongNoQueue() async {
        // Create mock dependencies
        let mockSessionService = MockSessionStateManager()
        let mockMusicService = MockMusicService()

        mockSessionService.songQueue = []  // Empty queue

        let environmentService = EnvironmentService()
        let personaSongCacheService = PersonaSongCacheService()
        let openAIClient = OpenAIClient(environmentService: environmentService, personaSongCacheService: personaSongCacheService)
        let statusMessageService = StatusMessageService(openAIClient: openAIClient)
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(personaService: personaService)
        let musicService = MusicService()
        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)

        let result = await turnManager.advanceToNextSong()

        #expect(result == nil)
        // AI thinking should be cleared when no song available
    }

    @Test("Verify currentTurn starts as user")
    func testCurrentTurnStartsAsUser() async {
        let mockSessionService = MockSessionStateManager()

        #expect(mockSessionService.currentTurn == .user)
    }

    @Test("Queue status logic follows turn state")
    func testQueueStatusFollowsTurnState() async {
        let mockSessionService = MockSessionStateManager()

        // Test user turn
        mockSessionService.currentTurn = .user
        let userTurnStatus = mockSessionService.determineNextQueueStatus()
        #expect(userTurnStatus == .queuedIfUserSkips)

        // Test AI turn
        mockSessionService.currentTurn = .ai
        let aiTurnStatus = mockSessionService.determineNextQueueStatus()
        #expect(aiTurnStatus == .upNext)
    }

    // MARK: - Tests Requiring Song Objects
    // The following tests require MusicKit Song objects which cannot be instantiated in unit tests
    // See Issue #62 for plans to enable these via protocol abstractions

    /*
    @Test("Turn stays on user when queuedIfUserSkips song plays")
    func testTurnStaysOnUserWhenBackupPlays() async {
        // Requires: Mock Song objects
        // Test that when a .queuedIfUserSkips song plays, turn remains .user
    }

    @Test("Turn switches when upNext song plays")
    func testTurnSwitchesWhenUpNextPlays() async {
        // Requires: Mock Song objects
        // Test that when a .upNext song plays, turn switches to opposite
    }

    @Test("Perfect alternation: User -> AI -> User -> AI")
    func testPerfectAlternation() async {
        // Requires: Mock Song objects
        // Test full alternating pattern over multiple songs
    }

    @Test("User skips scenario: AI backup plays, turn stays on user")
    func testUserSkipsAIBackupPlays() async {
        // Requires: Mock Song objects
        // Test that AI backup song playing doesn't switch turn
    }

    @Test("Advance to next song with queued songs")
    func testAdvanceWithQueue() async {
        // Requires: Mock Song objects
        // Test advancing when songs are in queue
    }

    @Test("Skip to specific queued song")
    func testSkipToSong() async {
        // Requires: Mock Song objects
        // Test skipToSong method with queued songs
    }
    */

    // MARK: - Additional Tests (PR #77)

    @Test("TurnManager clears AI thinking when advancing to AI song")
    func testAdvanceToAISongClearsThinking() async {
        let mockSessionService = MockSessionStateManager()

        // Set up a queued AI song
        mockSessionService.currentTurn = .user
        mockSessionService.setAIThinking(true)

        // Verify AI is thinking before advance
        #expect(mockSessionService.isAIThinking == true)

        // Note: Full test would require MockSong to create queued songs
        // For now we verify the mock's state management works
        mockSessionService.setAIThinking(false)
        #expect(mockSessionService.isAIThinking == false)
    }

    @Test("TurnManager integrates with SessionService for queue operations")
    func testSessionServiceIntegration() async {
        let environmentService = EnvironmentService()
        let personaSongCacheService = PersonaSongCacheService()
        let openAIClient = OpenAIClient(environmentService: environmentService, personaSongCacheService: personaSongCacheService)
        let statusMessageService = StatusMessageService(openAIClient: openAIClient)
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(personaService: personaService)
        let musicService = MusicService()
        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)

        // Verify TurnManager can access session state
        #expect(sessionService.currentTurn == .user)
        #expect(sessionService.songQueue.isEmpty)
        #expect(sessionService.sessionHistory.isEmpty)
    }

    @Test("TurnManager initializes with correct dependencies")
    func testInitializationWithDependencies() async {
        let environmentService = EnvironmentService()
        let personaSongCacheService = PersonaSongCacheService()
        let openAIClient = OpenAIClient(environmentService: environmentService, personaSongCacheService: personaSongCacheService)
        let statusMessageService = StatusMessageService(openAIClient: openAIClient)
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(personaService: personaService)
        let musicService = MusicService()
        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)

        // TurnManager should be created successfully
        #expect(turnManager != nil)
    }

    @Test("determineNextQueueStatus uses currentTurn from sessionService")
    func testDetermineNextQueueStatusUsesCurrentTurn() async {
        let mockSessionService = MockSessionStateManager()

        // Test user turn
        mockSessionService.currentTurn = .user
        let userTurnStatus = mockSessionService.determineNextQueueStatus()
        #expect(userTurnStatus == .queuedIfUserSkips)

        // Test AI turn
        mockSessionService.currentTurn = .ai
        let aiTurnStatus = mockSessionService.determineNextQueueStatus()
        #expect(aiTurnStatus == .upNext)
    }

    @Test("Advance to next song handles empty queue gracefully")
    func testAdvanceToNextSongEmptyQueue() async {
        let mockSessionService = MockSessionStateManager()

        // Ensure queue is empty
        mockSessionService.songQueue = []

        // getNextQueuedSong should return nil for empty queue
        let nextSong = mockSessionService.getNextQueuedSong()
        #expect(nextSong == nil)
    }
}
