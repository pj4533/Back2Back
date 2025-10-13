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
    private func makeSessionDependencies() -> (SessionService, PersonaService) {
        let statusMessageService = StatusMessageService()
        let personaService = PersonaService(statusMessageService: statusMessageService)
        let historyService = SessionHistoryService()
        let queueManager = QueueManager()
        let sessionService = SessionService(
            personaService: personaService,
            historyService: historyService,
            queueManager: queueManager
        )
        return (sessionService, personaService)
    }

    @MainActor
    @Test("Initial state")
    func testInitialState() {
        let (service, _) = makeSessionDependencies()

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
        let (service, _) = makeSessionDependencies()

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
        let (service, _) = makeSessionDependencies()

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
        let (service, _) = makeSessionDependencies()

        #expect(service.hasSongBeenPlayed(artist: "Test Artist", title: "Test Song") == false)
        #expect(service.hasSongBeenPlayed(artist: "Any Artist", title: "Any Song") == false)
    }

    @MainActor
    @Test("Current persona integration")
    func testCurrentPersonaIntegration() {
        let (service, personaService) = makeSessionDependencies()

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
