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

    @Test("Determine next queue status after AI song")
    @MainActor
    func testDetermineNextQueueStatusAfterAI() async {
        let turnManager = TurnManager()

        let queueStatus = turnManager.determineNextQueueStatus(after: .ai)

        #expect(queueStatus == .upNext)
    }

    @Test("Determine next queue status after user song")
    @MainActor
    func testDetermineNextQueueStatusAfterUser() async {
        let turnManager = TurnManager()

        let queueStatus = turnManager.determineNextQueueStatus(after: .user)

        #expect(queueStatus == .upNext)
    }

    @Test("Advance to next song returns nil when no queued song")
    @MainActor
    func testAdvanceToNextSongNoQueue() async {
        let turnManager = TurnManager()

        // SessionService should be empty by default
        let result = await turnManager.advanceToNextSong()

        #expect(result == nil)
    }
}
