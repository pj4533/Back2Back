//
//  SessionState.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Single source of truth for all session state (#54)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Single source of truth for all session state
/// Replaces state split across SessionService, SessionHistoryService, QueueManager, and TurnManager
@MainActor
@Observable
final class SessionState {
    // MARK: - Core State Properties

    /// Session history (songs that have been played or are playing)
    private(set) var history: [SessionSong] = []

    /// Song queue (songs waiting to be played)
    private(set) var queue: [SessionSong] = []

    /// Current turn in the DJ session
    private(set) var currentTurn: TurnType = .user

    /// Whether AI is currently thinking/selecting a song
    private(set) var isAIThinking: Bool = false

    /// Pre-fetched AI song (for optimization)
    private(set) var nextAISong: Song? = nil

    /// ID of the currently playing song (if any)
    private(set) var currentlyPlayingSongId: UUID? = nil

    // MARK: - Computed Properties

    /// Get the currently playing session song
    var currentlyPlayingSong: SessionSong? {
        guard let id = currentlyPlayingSongId else { return nil }
        return history.first { $0.id == id }
    }

    /// Get the next queued song based on priority
    var nextQueuedSong: SessionSong? {
        // First priority: songs marked as "upNext" (user → AI transition)
        if let upNext = queue.first(where: { $0.queueStatus == .upNext }) {
            return upNext
        }
        // Second priority: AI continuation songs (AI → AI transition)
        if let aiContinuation = queue.first(where: { $0.queueStatus == .queuedIfUserSkips }) {
            return aiContinuation
        }
        return nil
    }

    // MARK: - Initialization

    init() {
        B2BLog.session.info("SessionState initialized - single source of truth")
    }

    // MARK: - History Management

    /// Add a song to the session history
    @discardableResult
    func addToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) -> SessionSong {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        history.append(sessionSong)

        // If this song is playing, track it
        if queueStatus == .playing {
            currentlyPlayingSongId = sessionSong.id
            B2BLog.session.debug("Set currently playing song ID: \(sessionSong.id)")
        }

        // Update turn based on who selected this song and advance turn
        advanceTurn(basedOn: sessionSong)

        B2BLog.session.info("Added song to history: \(song.title) by \(selectedBy == .user ? "User" : "AI") - Status: \(queueStatus)")
        return sessionSong
    }

    /// Move a queued song to history and update turn
    func moveQueuedSongToHistory(_ songId: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == songId }) else {
            B2BLog.session.warning("Attempted to move non-existent song from queue: \(songId)")
            return
        }

        var song = queue.remove(at: index)
        song.queueStatus = .playing
        history.append(song)
        currentlyPlayingSongId = song.id

        B2BLog.session.info("Moved song to history: \(song.song.title)")

        // Update turn based on queue status
        advanceTurn(basedOn: song)
    }

    /// Check if a song has been played in this session
    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        history.contains { sessionSong in
            sessionSong.song.artistName.lowercased() == artist.lowercased() &&
            sessionSong.song.title.lowercased() == title.lowercased()
        }
    }

    /// Get song from history by ID
    func getHistorySong(withId songId: UUID) -> SessionSong? {
        history.first { $0.id == songId }
    }

    /// Update song status in history
    func updateHistorySongStatus(id: UUID, newStatus: QueueStatus) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in history: \(self.history[index].song.title) to \(newStatus)")
        }
    }

    /// Mark the currently playing song as played
    func markCurrentSongAsPlayed() {
        if let id = currentlyPlayingSongId {
            updateHistorySongStatus(id: id, newStatus: .played)
            currentlyPlayingSongId = nil
            B2BLog.session.debug("Marked current song as played")
        }
    }

    /// Update the currently playing song by MusicKit song ID (fixes UUID bug from #54)
    func updateCurrentlyPlayingSong(musicKitSongId: String) {
        // FIXED: Previously this created a random UUID() instead of searching properly!
        // First check history
        for (index, sessionSong) in history.enumerated() {
            if sessionSong.song.id.rawValue == musicKitSongId {
                // If this song is already marked as playing and is the current one, nothing to do
                if sessionSong.queueStatus == .playing && currentlyPlayingSongId == sessionSong.id {
                    B2BLog.session.trace("Song already marked as currently playing: \(sessionSong.song.title)")
                    return
                }

                // Mark any previously playing song as played
                if let previousId = currentlyPlayingSongId, previousId != sessionSong.id {
                    updateHistorySongStatus(id: previousId, newStatus: .played)
                }

                // Update this song to playing
                history[index].queueStatus = .playing
                currentlyPlayingSongId = sessionSong.id
                B2BLog.session.info("Updated currently playing: \(sessionSong.song.title)")
                return
            }
        }

        // Then check queue - if found, move to history
        for sessionSong in queue {
            if sessionSong.song.id.rawValue == musicKitSongId {
                // This song started playing from the queue
                moveQueuedSongToHistory(sessionSong.id)

                // Mark any previously playing song as played
                if let previousId = currentlyPlayingSongId {
                    updateHistorySongStatus(id: previousId, newStatus: .played)
                }

                B2BLog.session.info("Moved to playing from queue: \(sessionSong.song.title)")
                return
            }
        }

        B2BLog.session.debug("Song with ID \(musicKitSongId) not found in history or queue - may be initial playback")
    }

    // MARK: - Queue Management

    /// Add a song to the queue
    @discardableResult
    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        queue.append(sessionSong)
        B2BLog.session.info("Queued song: \(song.title) - Status: \(queueStatus)")
        return sessionSong
    }

    /// Clear all AI queued songs
    func clearAIQueuedSongs() {
        queue.removeAll { $0.selectedBy == .ai }
        B2BLog.session.info("Cleared AI queued songs")
    }

    /// Remove all songs before a specific song in the queue
    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        guard let targetIndex = queue.firstIndex(where: { $0.id == songId }) else { return }

        let removedSongs = queue.prefix(targetIndex)
        queue.removeFirst(targetIndex)
        B2BLog.session.info("Removed \(removedSongs.count) songs from queue (skipped ahead)")
        for song in removedSongs {
            B2BLog.session.debug("  Skipped: \(song.song.title) by \(song.song.artistName)")
        }
    }

    /// Remove a song from the queue
    func removeQueuedSong(withId songId: UUID) -> SessionSong? {
        if let index = queue.firstIndex(where: { $0.id == songId }) {
            let song = queue.remove(at: index)
            B2BLog.session.info("Removed song from queue: \(song.song.title)")
            return song
        }
        return nil
    }

    /// Update song status in the queue
    func updateQueueSongStatus(id: UUID, newStatus: QueueStatus) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            queue[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in queue: \(self.queue[index].song.title) to \(newStatus)")
        }
    }

    /// Check if a song exists in the queue
    func containsQueuedSong(withId songId: UUID) -> Bool {
        queue.contains { $0.id == songId }
    }

    /// Get song from queue by ID
    func getQueuedSong(withId songId: UUID) -> SessionSong? {
        queue.first { $0.id == songId }
    }

    // MARK: - Turn Management

    /// Advance turn based on the song that was added/played
    /// This is the SINGLE place where turn logic exists (fixes duplication from #54)
    private func advanceTurn(basedOn song: SessionSong) {
        // Update turn based on queue status:
        // - .upNext → switch turn to other person (someone took their turn)
        // - .queuedIfUserSkips → keep turn on user (AI backup, user hasn't picked)
        // - .playing → switch turn (song is now playing, turn advances)
        // - .played → no change (historical)

        if song.queueStatus == .upNext || song.queueStatus == .playing {
            let newTurn = song.selectedBy == .user ? TurnType.ai : TurnType.user
            if currentTurn != newTurn {
                B2BLog.session.info("🔄 Turn switch: \(self.currentTurn.rawValue) → \(newTurn.rawValue) (\(song.queueStatus) played)")
                currentTurn = newTurn
            }
        } else if song.queueStatus == .queuedIfUserSkips {
            B2BLog.session.info("🔄 Turn stays on USER (.queuedIfUserSkips played - AI backup)")
            currentTurn = .user
        }
    }

    /// Determine what queue status to use for next AI song based on current turn
    func determineNextQueueStatus() -> QueueStatus {
        if currentTurn == .user {
            // User's turn → AI queues a backup song (only plays if user doesn't pick)
            B2BLog.session.debug("Current turn is USER → AI queuing as .queuedIfUserSkips (backup)")
            return .queuedIfUserSkips
        } else {
            // AI's turn → AI queues its active pick (will definitely play)
            B2BLog.session.debug("Current turn is AI → AI queuing as .upNext (AI's pick)")
            return .upNext
        }
    }

    // MARK: - AI State Management

    /// Set AI thinking state
    func setAIThinking(_ thinking: Bool) {
        isAIThinking = thinking
        B2BLog.ai.debug("AI thinking state: \(thinking)")
    }

    /// Set pre-fetched AI song
    func setNextAISong(_ song: Song?) {
        nextAISong = song
        if let song = song {
            B2BLog.ai.info("Pre-fetched AI song: \(song.title)")
        }
    }

    /// Clear pre-fetched AI song
    func clearNextAISong() {
        nextAISong = nil
        B2BLog.ai.debug("Cleared pre-fetched AI song")
    }

    // MARK: - Session Management

    /// Reset the entire session
    func resetSession() {
        history.removeAll()
        queue.removeAll()
        currentTurn = .user
        isAIThinking = false
        nextAISong = nil
        currentlyPlayingSongId = nil
        B2BLog.session.info("Session reset")
    }
}
