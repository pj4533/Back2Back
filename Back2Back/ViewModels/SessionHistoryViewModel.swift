//
//  SessionHistoryViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionHistoryViewModel {
    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }

    // MARK: - Computed Properties

    var sessionHistory: [SessionSong] {
        sessionService.sessionHistory
    }

    var songQueue: [SessionSong] {
        sessionService.songQueue
    }

    var isAIThinking: Bool {
        sessionService.isAIThinking
    }

    var isEmpty: Bool {
        sessionHistory.isEmpty && songQueue.isEmpty && !isAIThinking
    }

    /// Total count for animation/scroll tracking purposes
    var totalCount: Int {
        sessionHistory.count + songQueue.count + (isAIThinking ? 1 : 0)
    }
}
