//
//  TurnManager.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionViewModel as part of Phase 1 refactoring (#20)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Manages turn state transitions and queue advancement logic
@MainActor
@Observable
final class TurnManager {
    private let sessionService: SessionService
    private let musicService: MusicService

    init(sessionService: SessionService, musicService: MusicService) {
        self.sessionService = sessionService
        self.musicService = musicService
        B2BLog.session.debug("TurnManager initialized")
    }

    // MARK: - Public Methods

    /// Advance to next queued song (called when songs end automatically)
    func advanceToNextSong() async -> (song: Song, selectedBy: TurnType)? {
        B2BLog.session.info("🔄 Auto-advancing to next queued song")
        B2BLog.session.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Check if we have a queued song ready
        guard let nextSong = sessionService.getNextQueuedSong() else {
            B2BLog.session.warning("⚠️ No queued song available - waiting for user selection")
            // User needs to select manually - make sure AI thinking is cleared
            sessionService.setAIThinking(false)
            return nil
        }

        B2BLog.session.info("🎵 Found queued song: \(nextSong.song.title) by \(nextSong.song.artistName) (selected by \(nextSong.selectedBy.rawValue))")

        // Move the song from queue to history before playing
        sessionService.moveQueuedSongToHistory(nextSong.id)

        // If this was an AI song that just started playing, we're no longer "thinking"
        // The turn is now the user's turn (they can select while this AI song plays)
        if nextSong.selectedBy == .ai {
            B2BLog.session.info("🤖 AI song now playing, clearing AI thinking state")
            sessionService.setAIThinking(false)
        }

        return (nextSong.song, nextSong.selectedBy)
    }

    /// Skip to a specific queued song
    func skipToSong(_ sessionSong: SessionSong) async -> Song {
        B2BLog.session.info("⏩ Skipping to queued song: \(sessionSong.song.title)")
        B2BLog.session.debug("Queue state before skip - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        // Mark the currently playing song as played (if there is one)
        sessionService.markCurrentSongAsPlayed()

        // Remove all songs before this one from the queue (they're being skipped)
        sessionService.removeQueuedSongsBeforeSong(sessionSong.id)

        // Move the tapped song from queue to history
        sessionService.moveQueuedSongToHistory(sessionSong.id)

        // If this was an AI song, clear AI thinking state
        if sessionSong.selectedBy == .ai {
            B2BLog.session.info("🤖 Skipped to AI song, clearing AI thinking state")
            sessionService.setAIThinking(false)
        }

        B2BLog.session.debug("Queue state after skip - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

        return sessionSong.song
    }

    /// Determine what queue status to use for next AI song based on current turn
    func determineNextQueueStatus() -> QueueStatus {
        // Check whose turn it currently is to determine what status the AI should queue
        if sessionService.currentTurn == .user {
            // User's turn → AI queues a backup song (only plays if user doesn't pick)
            B2BLog.session.debug("Current turn is USER → AI queuing as .queuedIfUserSkips (backup)")
            return .queuedIfUserSkips
        } else {
            // AI's turn → AI queues its active pick (will definitely play)
            B2BLog.session.debug("Current turn is AI → AI queuing as .upNext (AI's pick)")
            return .upNext
        }
    }
}
