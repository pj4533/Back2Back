//
//  SessionActionButtonsViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionActionButtonsViewModel {
    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
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
}
