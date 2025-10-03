//
//  SessionService.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 3 refactoring (#23) - delegating to specialized services
//

import Foundation
import MusicKit
import Observation
import OSLog

@MainActor
@Observable
final class SessionService: SessionStateManagerProtocol {
    static let shared = SessionService()

    // Delegated services
    private let historyService = SessionHistoryService()
    private let queueManager = QueueManager()

    // Core session state
    private(set) var currentTurn: TurnType = .user
    private(set) var isAIThinking: Bool = false
    private(set) var nextAISong: Song? = nil

    // Expose delegated properties
    var sessionHistory: [SessionSong] {
        historyService.sessionHistory
    }

    var songQueue: [SessionSong] {
        queueManager.songQueue
    }

    var currentlyPlayingSongId: UUID? {
        historyService.currentlyPlayingSongId
    }

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

    // MARK: - History Delegation

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) {
        _ = historyService.addToHistory(song, selectedBy: selectedBy, rationale: rationale, queueStatus: queueStatus)

        // Update turn based on who selected this song
        let newTurn = selectedBy == .user ? TurnType.ai : TurnType.user
        B2BLog.session.debug("Turn change: \(self.currentTurn.rawValue) -> \(newTurn.rawValue)")
        currentTurn = newTurn
    }

    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        historyService.hasSongBeenPlayed(artist: artist, title: title)
    }

    func getCurrentlyPlayingSessionSong() -> SessionSong? {
        historyService.getCurrentlyPlayingSessionSong()
    }

    func updateCurrentlyPlayingSong(songId: String) {
        // Check history first
        if let _ = historyService.getSong(withId: UUID()) {
            historyService.updateCurrentlyPlayingSong(songId: songId)
            return
        }

        // Then check queue - if found, move to history
        for sessionSong in queueManager.songQueue {
            if sessionSong.song.id.rawValue == songId {
                // This song started playing from the queue
                if let removedSong = queueManager.removeSong(withId: sessionSong.id) {
                    // Mark any previously playing song as played
                    if let previousId = currentlyPlayingSongId {
                        historyService.updateSongStatus(id: previousId, newStatus: .played)
                    }

                    historyService.moveToHistory(removedSong)

                    // Update turn based on queue status:
                    // - .upNext → switch turn to other person (someone took their turn)
                    // - .queuedIfUserSkips → keep turn on user (AI backup, user hasn't picked)
                    if removedSong.queueStatus == .upNext {
                        let newTurn = removedSong.selectedBy == .user ? TurnType.ai : TurnType.user
                        B2BLog.session.info("🔄 Turn switch: \(self.currentTurn.rawValue) → \(newTurn.rawValue) (.upNext played)")
                        currentTurn = newTurn
                    } else if removedSong.queueStatus == .queuedIfUserSkips {
                        B2BLog.session.info("🔄 Turn stays on USER (.queuedIfUserSkips played - AI backup)")
                        currentTurn = .user
                    }

                    B2BLog.session.info("Moved to playing from queue: \(removedSong.song.title)")
                }
                return
            }
        }

        // Not found in history or queue - update history anyway
        historyService.updateCurrentlyPlayingSong(songId: songId)
    }

    func markCurrentSongAsPlayed() {
        historyService.markCurrentSongAsPlayed()
    }

    // MARK: - Queue Delegation

    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        queueManager.queueSong(song, selectedBy: selectedBy, rationale: rationale, queueStatus: queueStatus)
    }

    func getNextQueuedSong() -> SessionSong? {
        queueManager.getNextQueuedSong()
    }

    func clearAIQueuedSongs() {
        queueManager.clearAIQueuedSongs()
    }

    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        queueManager.removeQueuedSongsBeforeSong(songId)
    }

    func moveQueuedSongToHistory(_ songId: UUID) {
        if let song = queueManager.removeSong(withId: songId) {
            historyService.moveToHistory(song)

            // Update turn based on queue status:
            // - .upNext → switch turn to other person (someone took their turn)
            // - .queuedIfUserSkips → keep turn on user (AI backup, user hasn't picked)
            if song.queueStatus == .upNext {
                let newTurn = song.selectedBy == .user ? TurnType.ai : TurnType.user
                B2BLog.session.info("🔄 Turn switch: \(self.currentTurn.rawValue) → \(newTurn.rawValue) (.upNext played)")
                currentTurn = newTurn
            } else if song.queueStatus == .queuedIfUserSkips {
                B2BLog.session.info("🔄 Turn stays on USER (.queuedIfUserSkips played - AI backup)")
                currentTurn = .user
            }
        }
    }

    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        // Update in history
        historyService.updateSongStatus(id: id, newStatus: newStatus)
        // Update in queue
        queueManager.updateSongStatus(id: id, newStatus: newStatus)
    }

    // MARK: - AI State Management

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

    // MARK: - Session Management

    func resetSession() {
        historyService.clearHistory()
        queueManager.clearQueue()
        currentTurn = .user
        isAIThinking = false
        nextAISong = nil
        B2BLog.session.info("Session reset")
    }
}

// MARK: - Models (kept in this file for backward compatibility)

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
