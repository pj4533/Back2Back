//
//  SessionHistoryService.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionService as part of Phase 3 refactoring (#23)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Manages the session history tracking
@MainActor
@Observable
final class SessionHistoryService {
    private(set) var sessionHistory: [SessionSong] = []
    private(set) var currentlyPlayingSongId: UUID? = nil

    // MARK: - History Operations

    /// Add a song to the session history
    func addToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) -> SessionSong {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        sessionHistory.append(sessionSong)

        // If this song is playing, track it
        if queueStatus == .playing {
            currentlyPlayingSongId = sessionSong.id
            B2BLog.session.debug("Set currently playing song ID: \(sessionSong.id)")
        }

        B2BLog.session.info("Added song to history: \(song.title) by \(selectedBy == .user ? "User" : "AI") - Status: \(queueStatus)")
        return sessionSong
    }

    /// Move a queued song to history
    func moveToHistory(_ sessionSong: SessionSong) {
        var updatedSong = sessionSong
        updatedSong.queueStatus = .playing
        sessionHistory.append(updatedSong)
        currentlyPlayingSongId = updatedSong.id
        B2BLog.session.info("Moved song to history: \(updatedSong.song.title)")
    }

    /// Update song status in history
    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        if let index = sessionHistory.firstIndex(where: { $0.id == id }) {
            sessionHistory[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in history: \(self.sessionHistory[index].song.title) to \(newStatus)")
        }
    }

    /// Mark the currently playing song as played
    func markCurrentSongAsPlayed() {
        if let id = currentlyPlayingSongId {
            updateSongStatus(id: id, newStatus: .played)
            currentlyPlayingSongId = nil
            B2BLog.session.debug("Marked current song as played")
        }
    }

    /// Get the currently playing session song
    func getCurrentlyPlayingSessionSong() -> SessionSong? {
        if let id = currentlyPlayingSongId {
            return sessionHistory.first(where: { $0.id == id })
        }
        return nil
    }

    /// Update the currently playing song by MusicKit song ID
    func updateCurrentlyPlayingSong(songId: String) {
        // Find the song in history that matches this MusicKit song ID
        for (index, sessionSong) in sessionHistory.enumerated() {
            if sessionSong.song.id.rawValue == songId {
                // If this song is already marked as playing and is the current one, nothing to do
                if sessionSong.queueStatus == .playing && currentlyPlayingSongId == sessionSong.id {
                    B2BLog.session.trace("Song already marked as currently playing: \(sessionSong.song.title)")
                    return
                }

                // Mark any previously playing song as played
                if let previousId = currentlyPlayingSongId, previousId != sessionSong.id {
                    updateSongStatus(id: previousId, newStatus: .played)
                }

                // Update this song to playing
                sessionHistory[index].queueStatus = .playing
                currentlyPlayingSongId = sessionSong.id
                B2BLog.session.info("Updated currently playing: \(sessionSong.song.title)")
                return
            }
        }

        B2BLog.session.debug("Song with ID \(songId) not found in history - may be initial playback")
    }

    /// Check if a song has been played in this session
    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        sessionHistory.contains { sessionSong in
            sessionSong.song.artistName.lowercased() == artist.lowercased() &&
            sessionSong.song.title.lowercased() == title.lowercased()
        }
    }

    /// Clear all history
    func clearHistory() {
        sessionHistory.removeAll()
        currentlyPlayingSongId = nil
        B2BLog.session.info("Cleared session history")
    }

    /// Get song from history by ID
    func getSong(withId songId: UUID) -> SessionSong? {
        sessionHistory.first { $0.id == songId }
    }

    /// Set the currently playing song ID
    func setCurrentlyPlayingSong(id: UUID) {
        currentlyPlayingSongId = id
        B2BLog.session.debug("Set currently playing song ID: \(id)")
    }
}
