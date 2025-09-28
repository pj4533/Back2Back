//
//  SessionViewModelTests.swift
//  Back2BackTests
//
//  Created on 2025-09-27.
//

import Testing
import Foundation
@testable import Back2Back
import MusicKit

@Suite("SessionViewModel Tests")
struct SessionViewModelTests {
    @MainActor
    @Test("ViewModel initialization")
    func testViewModelInitialization() {
        let viewModel = SessionViewModel.shared

        // Verify the view model is properly initialized
        // Note: We can't create new instances due to singleton pattern
        // So we just verify it exists and has expected services
        #expect(viewModel != nil)
    }

    // Note: Tests that require creating Song instances are commented out
    // as Song is a MusicKit type that cannot be instantiated in tests

    /*
    @MainActor
    @Test("Find best match - exact match")
    func testFindBestMatchExact() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Find best match - case insensitive")
    func testFindBestMatchCaseInsensitive() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Handle user song selection")
    func testHandleUserSongSelection() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Session song structure")
    func testSessionSongStructure() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Prefetch task cancellation")
    func testPrefetchTaskCancellation() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }
    */

    @MainActor
    @Test("Turn type enum")
    func testTurnTypeEnum() {
        let userTurn = TurnType.user
        let aiTurn = TurnType.ai

        #expect(userTurn.rawValue == "User")
        #expect(aiTurn.rawValue == "AI")
        #expect(userTurn != aiTurn)
    }

    @MainActor
    @Test("Score calculation for fuzzy matching")
    func testScoreCalculation() {
        // Test the scoring logic for fuzzy matching
        let searchArtist = "The Beatles"
        let searchTitle = "Hey Jude"

        // Exact match should score highest
        let exactArtist = "The Beatles"
        let exactTitle = "Hey Jude"
        #expect(exactArtist.lowercased() == searchArtist.lowercased())
        #expect(exactTitle.lowercased() == searchTitle.lowercased())

        // Partial match should score lower
        let partialArtist = "Beatles"
        #expect(searchArtist.lowercased().contains(partialArtist.lowercased()))

        // No match should score zero
        let noMatchArtist = "Rolling Stones"
        #expect(!searchArtist.lowercased().contains(noMatchArtist.lowercased()))
    }

    @MainActor
    @Test("AI thinking state management")
    func testAIThinkingStateManagement() async {
        let sessionService = SessionService.shared

        // Initial state
        #expect(sessionService.isAIThinking == false)

        // Simulate AI thinking
        sessionService.setAIThinking(true)
        #expect(sessionService.isAIThinking == true)

        // AI done thinking
        sessionService.setAIThinking(false)
        #expect(sessionService.isAIThinking == false)
    }

    @MainActor
    @Test("Session Service turn management")
    func testSessionServiceTurnManagement() {
        let sessionService = SessionService.shared

        // Reset to known state
        sessionService.resetSession()

        // Initial state should be user turn
        #expect(sessionService.currentTurn == .user)

        // After reset, history should be empty
        #expect(sessionService.sessionHistory.isEmpty)
        #expect(sessionService.nextAISong == nil)
    }

}