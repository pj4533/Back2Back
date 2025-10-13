//
//  TurnManagerTests.swift
//  Back2BackTests
//
//  Created on 2025-09-30.
//  Tests for TurnManager coordinator
//

import Testing
import MusicKit
@testable import Back2Back

@Suite("TurnManager Tests")
struct TurnManagerTests {

    // Note: Tests that require creating Song instances are commented out
    // as Song is a MusicKit type that cannot be instantiated in tests

    @Test("Determine next queue status when user's turn returns queuedIfUserSkips")
    @MainActor
    func testDetermineNextQueueStatusDuringUserTurn() async {
        // Setup: Ensure it's user's turn
        let statusMessageService = StatusMessageService()
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(
            personaService: personaService,
            historyService: SessionHistoryService(),
            queueManager: QueueManager()
        )
        let musicService = MusicService(
            authService: MusicAuthService(),
            searchService: MusicSearchService(),
            playbackService: MusicPlaybackService()
        )
        sessionService.resetSession()
        // currentTurn defaults to .user

        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)
        let queueStatus = turnManager.determineNextQueueStatus()

        // When it's user's turn, AI should queue as backup (.queuedIfUserSkips)
        #expect(queueStatus == .queuedIfUserSkips)
    }

    @Test("Advance to next song returns nil when no queued song")
    @MainActor
    func testAdvanceToNextSongNoQueue() async {
        let statusMessageService = StatusMessageService()
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let sessionService = SessionService(
            personaService: personaService,
            historyService: SessionHistoryService(),
            queueManager: QueueManager()
        )
        let musicService = MusicService(
            authService: MusicAuthService(),
            searchService: MusicSearchService(),
            playbackService: MusicPlaybackService()
        )
        sessionService.resetSession()

        let turnManager = TurnManager(sessionService: sessionService, musicService: musicService)
        let result = await turnManager.advanceToNextSong()

        #expect(result == nil)
    }

    /*
    @Test("Determine next queue status when AI's turn returns upNext")
    @MainActor
    func testDetermineNextQueueStatusDuringAITurn() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @Test("Turn stays on user when queuedIfUserSkips song plays")
    @MainActor
    func testTurnStaysOnUserWhenBackupPlays() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @Test("Turn switches when upNext song plays")
    @MainActor
    func testTurnSwitchesWhenUpNextPlays() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @Test("Perfect alternation: User -> AI -> User -> AI")
    @MainActor
    func testPerfectAlternation() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @Test("User skips scenario: AI backup plays, turn stays on user")
    @MainActor
    func testUserSkipsAIBackupPlays() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }
    */
}
