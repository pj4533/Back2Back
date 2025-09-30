//
//  TurnManager.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Manages turn state transitions and validation
//

import Foundation
import MusicKit
import OSLog

@MainActor
@Observable
final class TurnManager {
    enum Turn {
        case user
        case ai
        case userWithAIBackup  // User's turn, but AI has backup queued
    }

    private let sessionService: SessionService

    init(sessionService: SessionService = .shared) {
        self.sessionService = sessionService
        B2BLog.session.debug("TurnManager initialized")
    }

    // MARK: - Turn Logic

    /// Determines whose turn it is based on the last song in history/queue
    func getCurrentTurn() -> Turn {
        // Look at session history to see who went last
        if let lastSong = sessionService.sessionHistory.last {
            if lastSong.selectedBy == .user {
                // User went last, it's AI's turn
                return .ai
            } else {
                // AI went last, it's user's turn (but AI can queue backup)
                return .userWithAIBackup
            }
        }

        // No history yet - user can start or AI can start
        return .user
    }

    /// Determines the appropriate queue status for the next AI song based on current turn
    func getQueueStatusForNextAISong() -> QueueStatus {
        let currentTurn = getCurrentTurn()

        switch currentTurn {
        case .ai:
            // It's AI's turn - queue as upNext
            return .upNext
        case .user, .userWithAIBackup:
            // It's user's turn - queue AI song as backup in case user doesn't select
            return .queuedIfUserSkips
        }
    }

    /// Validates if AI should be allowed to queue a song
    func shouldAllowAIQueueing() -> Bool {
        // AI can always queue, but the queue status will differ based on whose turn it is
        return true
    }

    /// Validates if user selection should clear AI queued songs
    func shouldClearAIQueueOnUserSelection() -> Bool {
        // User taking control always clears AI queue
        return true
    }

    /// Determines if we should queue another AI song after the current song plays
    /// based on who selected the current song
    func shouldQueueAnotherAISong(after selectedBy: TurnType) -> Bool {
        switch selectedBy {
        case .ai:
            // AI just played, so it's the user's turn, but we queue a backup
            return true
        case .user:
            // User just played, so it's AI's turn
            return true
        }
    }

    /// Gets the queue status for the next AI song based on who just played
    func getQueueStatusAfterSong(selectedBy: TurnType) -> QueueStatus {
        switch selectedBy {
        case .ai:
            // AI just played, user's turn - queue as backup
            return .queuedIfUserSkips
        case .user:
            // User just played, AI's turn - queue as upNext
            return .upNext
        }
    }

    /// Determines if AI thinking state should be cleared when a song starts playing
    func shouldClearAIThinkingOnPlay(selectedBy: TurnType) -> Bool {
        // When an AI song starts playing, clear thinking state (AI's turn is over)
        return selectedBy == .ai
    }

    /// Validates turn transition rules
    func validateTurnTransition(from: TurnType, to: TurnType) -> Bool {
        // In back-to-back DJ mode, we prefer alternating turns
        // but don't enforce it strictly (user can skip, AI can fail to match, etc.)
        return true
    }
}
