//
//  SessionActionButtonsViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SessionActionButtonsViewModel {
    private let sessionService: SessionService
    private let personaService: PersonaService

    init(sessionService: SessionService, personaService: PersonaService) {
        self.sessionService = sessionService
        self.personaService = personaService
    }

    // MARK: - Computed Properties

    var isSessionEmpty: Bool {
        sessionService.sessionHistory.isEmpty && sessionService.songQueue.isEmpty
    }

    var currentTurn: TurnType {
        sessionService.currentTurn
    }

    var hasUserSelectedSong: Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }

    var shouldShowStartButtons: Bool {
        isSessionEmpty
    }

    var shouldShowUserTurnButtons: Bool {
        currentTurn == .user && !hasUserSelectedSong && !isSessionEmpty
    }

    var hasFirstSelectionCached: Bool {
        // Access personas array directly to ensure proper observation
        // (computed property selectedPersona doesn't trigger observation updates)
        let result = personaService.personas.first(where: { $0.isSelected })?.firstSelection != nil
        B2BLog.ui.debug("🔍 hasFirstSelectionCached computed: \(result)")
        if let persona = personaService.personas.first(where: { $0.isSelected }) {
            B2BLog.ui.debug("   Selected persona: \(persona.name), has cache: \(persona.firstSelection != nil)")
        } else {
            B2BLog.ui.debug("   No selected persona found")
        }
        return result
    }
}
