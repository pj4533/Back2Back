//
//  SessionService.swift
//  Back2Back
//
//  Created on 2025-09-27.
//

import Foundation
import MusicKit
import Observation
import OSLog

@MainActor
@Observable
final class SessionService: SessionStateManagerProtocol {
    static let shared = SessionService()

    private(set) var sessionHistory: [SessionSong] = []
    private(set) var currentTurn: TurnType = .user
    private(set) var isAIThinking: Bool = false
    private(set) var nextAISong: Song? = nil
    private(set) var songQueue: [SessionSong] = []  // Songs waiting to play
    private(set) var currentlyPlayingSongId: UUID? = nil

    // Dynamic persona from PersonaService
    var currentPersonaStyleGuide: String {
        if let selectedPersona = PersonaService.shared.selectedPersona {
            return selectedPersona.styleGuide
        }
        // Fallback to a basic persona if none selected
        return "You are a DJ assistant helping to select songs in a back-to-back session."
    }

    var currentPersonaName: String {
        PersonaService.shared.selectedPersona?.name ?? "Default DJ"
    }

    private init() {
        B2BLog.session.info("SessionService initialized")
    }

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) {
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

        // Update turn based on who selected this song (same logic as moveQueuedSongToHistory)
        let newTurn = selectedBy == .user ? TurnType.ai : TurnType.user
        B2BLog.session.debug("Turn change: \(self.currentTurn.rawValue) -> \(newTurn.rawValue)")

        currentTurn = selectedBy == .user ? .ai : .user
    }

    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        songQueue.append(sessionSong)
        B2BLog.session.info("Queued song: \(song.title) - Status: \(queueStatus)")
        return sessionSong
    }

    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        // Update in history
        if let index = sessionHistory.firstIndex(where: { $0.id == id }) {
            sessionHistory[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in history: \(self.sessionHistory[index].song.title) to \(newStatus)")
        }
        // Update in queue
        if let index = songQueue.firstIndex(where: { $0.id == id }) {
            songQueue[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in queue: \(self.songQueue[index].song.title) to \(newStatus)")
        }
    }

    func moveQueuedSongToHistory(_ songId: UUID) {
        if let index = songQueue.firstIndex(where: { $0.id == songId }) {
            var song = songQueue.remove(at: index)
            song.queueStatus = .playing
            sessionHistory.append(song)
            currentlyPlayingSongId = song.id
            B2BLog.session.info("Moved song from queue to history: \(song.song.title)")

            // Update turn based on who selected this song
            currentTurn = song.selectedBy == .user ? .ai : .user
            B2BLog.session.debug("Turn change after queue move: \(song.selectedBy.rawValue) -> \(self.currentTurn.rawValue)")
        }
    }

    func updateCurrentlyPlayingSong(songId: String) {
        // Find the song in history or queue that matches this MusicKit song ID
        // First check history
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

        // Then check queue
        for (index, sessionSong) in songQueue.enumerated() {
            if sessionSong.song.id.rawValue == songId {
                // This song started playing from the queue
                // Move it to history with playing status
                var song = songQueue.remove(at: index)

                // Mark any previously playing song as played
                if let previousId = currentlyPlayingSongId {
                    updateSongStatus(id: previousId, newStatus: .played)
                }

                song.queueStatus = .playing
                sessionHistory.append(song)
                currentlyPlayingSongId = song.id

                // Update turn based on who selected this song
                currentTurn = song.selectedBy == .user ? .ai : .user

                B2BLog.session.info("Moved to playing from queue: \(song.song.title)")
                return
            }
        }

        B2BLog.session.debug("Song with ID \(songId) not found in history or queue - may be initial playback")
    }

    func getNextQueuedSong() -> SessionSong? {
        // First priority: songs marked as "upNext" (user → AI transition)
        if let upNext = songQueue.first(where: { $0.queueStatus == .upNext }) {
            return upNext
        }
        // Second priority: AI continuation songs (AI → AI transition)
        if let aiContinuation = songQueue.first(where: { $0.queueStatus == .queuedIfUserSkips }) {
            return aiContinuation
        }
        return nil
    }

    func clearAIQueuedSongs() {
        songQueue.removeAll { $0.selectedBy == .ai }
        B2BLog.session.info("Cleared AI queued songs")
    }

    func markCurrentSongAsPlayed() {
        if let id = currentlyPlayingSongId {
            updateSongStatus(id: id, newStatus: .played)
            currentlyPlayingSongId = nil
            B2BLog.session.debug("Marked current song as played")
        }
    }

    func getCurrentlyPlayingSessionSong() -> SessionSong? {
        if let id = currentlyPlayingSongId {
            // Check history first
            if let song = sessionHistory.first(where: { $0.id == id }) {
                return song
            }
            // Then check queue
            if let song = songQueue.first(where: { $0.id == id }) {
                return song
            }
        }
        return nil
    }

    func setAIThinking(_ thinking: Bool) {
        isAIThinking = thinking
        B2BLog.ai.debug("AI thinking state: \(thinking)")
    }

    func setNextAISong(_ song: Song?) {
        nextAISong = song
        if let song = song {
            B2BLog.ai.info("Pre-fetched AI song: \(song.title)")
        }
    }

    func clearNextAISong() {
        nextAISong = nil
        B2BLog.ai.debug("Cleared pre-fetched AI song")
    }

    func resetSession() {
        sessionHistory = []
        songQueue = []
        currentTurn = .user
        isAIThinking = false
        nextAISong = nil
        currentlyPlayingSongId = nil
        B2BLog.session.info("Session reset")
    }

    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        sessionHistory.contains { sessionSong in
            sessionSong.song.artistName.lowercased() == artist.lowercased() &&
            sessionSong.song.title.lowercased() == title.lowercased()
        }
    }

    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        // Find the index of the target song
        if let targetIndex = songQueue.firstIndex(where: { $0.id == songId }) {
            // Remove all songs before this index
            let removedSongs = songQueue.prefix(targetIndex)
            songQueue.removeFirst(targetIndex)
            B2BLog.session.info("Removed \(removedSongs.count) songs from queue (skipped ahead)")
            for song in removedSongs {
                B2BLog.session.debug("  Skipped: \(song.song.title) by \(song.song.artistName)")
            }
        }
    }
}

struct SessionSong: Identifiable {
    let id: UUID
    let song: Song
    let selectedBy: TurnType
    let timestamp: Date
    let rationale: String?
    var queueStatus: QueueStatus
}

enum TurnType: String {
    case user = "User"
    case ai = "AI"
}