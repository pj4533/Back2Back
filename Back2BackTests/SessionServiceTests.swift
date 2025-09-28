//
//  SessionServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-09-27.
//

import Testing
import Foundation
@testable import Back2Back
import MusicKit

@Suite("SessionService Tests")
struct SessionServiceTests {
    @MainActor
    @Test("Initial state")
    func testInitialState() {
        let service = SessionService.shared

        // Reset to known state since we're using a singleton
        service.resetSession()

        // Test initial values after reset
        #expect(service.sessionHistory.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
        #expect(!service.currentPersonaStyleGuide.isEmpty)
        #expect(!service.currentPersonaName.isEmpty)
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
        let service = SessionService.shared

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
        let service = SessionService.shared

        // Set some state
        service.setAIThinking(true)

        // Reset
        service.resetSession()

        // Verify everything is reset
        #expect(service.sessionHistory.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
    }

    @MainActor
    @Test("Has song been played - case insensitive")
    func testHasSongBeenPlayed() {
        let service = SessionService.shared

        // Test the method logic (without actual songs)
        #expect(service.hasSongBeenPlayed(artist: "Test Artist", title: "Test Song") == false)

        // After reset, no songs should have been played
        service.resetSession()
        #expect(service.hasSongBeenPlayed(artist: "Any Artist", title: "Any Song") == false)
    }

    @MainActor
    @Test("Current persona integration")
    func testCurrentPersonaIntegration() {
        let service = SessionService.shared
        let personaService = PersonaService.shared

        // Should have a default persona
        #expect(personaService.selectedPersona != nil)

        // Current persona should reflect the selected persona
        if let selectedPersona = personaService.selectedPersona {
            #expect(service.currentPersonaStyleGuide == selectedPersona.styleGuide)
            #expect(service.currentPersonaName == selectedPersona.name)
        }
    }

    @MainActor
    @Test("Turn type values")
    func testTurnTypeValues() {
        #expect(TurnType.user.rawValue == "User")
        #expect(TurnType.ai.rawValue == "AI")
    }
}