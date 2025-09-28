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
final class SessionService {
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

        B2BLog.session.info("Added song to history: \(song.title) by \(selectedBy == .user ? "User" : "AI") - Status: \(queueStatus)")
        let newTurn = self.currentTurn == .user ? TurnType.ai : TurnType.user
        B2BLog.session.debug("Turn change: \(self.currentTurn.rawValue) -> \(newTurn.rawValue)")

        currentTurn = currentTurn == .user ? .ai : .user
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

    func getNextQueuedSong() -> SessionSong? {
        return songQueue.first { $0.queueStatus == .upNext }
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