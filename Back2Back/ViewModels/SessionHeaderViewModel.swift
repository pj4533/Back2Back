//
//  SessionHeaderViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionHeaderViewModel {
    private let sessionService: SessionService
    private let musicService: MusicService

    init(
        sessionService: SessionService,
        musicService: MusicService
    ) {
        self.sessionService = sessionService
        self.musicService = musicService
    }

    // MARK: - Computed Properties

    var currentTurn: String {
        sessionService.currentTurn.rawValue
    }

    var turnIcon: String {
        sessionService.currentTurn == .user ? "person.fill" : "cpu"
    }

    var turnColor: TurnColor {
        sessionService.currentTurn == .user ? .user : .ai
    }

    var personaName: String {
        sessionService.currentPersonaName
    }

    var hasNowPlaying: Bool {
        musicService.currentlyPlaying != nil
    }
}

// MARK: - Supporting Types

enum TurnColor {
    case user
    case ai
}
