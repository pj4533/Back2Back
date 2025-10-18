//
//  SessionService.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 3 refactoring (#23) - delegating to specialized services
//  Refactored on 2025-10-18 (#54) - now delegates to SessionState (single source of truth)
//

import Foundation
import MusicKit
import Observation
import OSLog

@MainActor
@Observable
final class SessionService: SessionStateManagerProtocol {
    // Single source of truth for session state
    private let state = SessionState()
    private let personaService: PersonaService

    // Expose state properties for backward compatibility
    var currentTurn: TurnType {
        state.currentTurn
    }

    var isAIThinking: Bool {
        state.isAIThinking
    }

    var nextAISong: Song? {
        state.nextAISong
    }

    var sessionHistory: [SessionSong] {
        state.history
    }

    var songQueue: [SessionSong] {
        state.queue
    }

    var currentlyPlayingSongId: UUID? {
        state.currentlyPlayingSongId
    }

    // Dynamic persona from PersonaService
    var currentPersonaStyleGuide: String {
        if let selectedPersona = personaService.selectedPersona {
            return selectedPersona.styleGuide
        }
        // Fallback to a basic persona if none selected
        return "You are a DJ assistant helping to select songs in a back-to-back session."
    }

    var currentPersonaName: String {
        personaService.selectedPersona?.name ?? "Default DJ"
    }

    init(personaService: PersonaService) {
        self.personaService = personaService
        B2BLog.session.info("SessionService initialized (using SessionState)")
    }

    // MARK: - History Delegation

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) {
        state.addToHistory(song, selectedBy: selectedBy, rationale: rationale, queueStatus: queueStatus)
    }

    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        state.hasSongBeenPlayed(artist: artist, title: title)
    }

    func getCurrentlyPlayingSessionSong() -> SessionSong? {
        state.currentlyPlayingSong
    }

    func updateCurrentlyPlayingSong(songId: String) {
        // FIXED: Now delegates to SessionState which has the corrected UUID bug fix
        state.updateCurrentlyPlayingSong(musicKitSongId: songId)
    }

    func markCurrentSongAsPlayed() {
        state.markCurrentSongAsPlayed()
    }

    // MARK: - Queue Delegation

    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        state.queueSong(song, selectedBy: selectedBy, rationale: rationale, queueStatus: queueStatus)
    }

    func getNextQueuedSong() -> SessionSong? {
        state.nextQueuedSong
    }

    func clearAIQueuedSongs() {
        state.clearAIQueuedSongs()
    }

    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        state.removeQueuedSongsBeforeSong(songId)
    }

    func moveQueuedSongToHistory(_ songId: UUID) {
        // Turn logic now handled inside SessionState.moveQueuedSongToHistory
        state.moveQueuedSongToHistory(songId)
    }

    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        // Update in both history and queue
        state.updateHistorySongStatus(id: id, newStatus: newStatus)
        state.updateQueueSongStatus(id: id, newStatus: newStatus)
    }

    // MARK: - AI State Management

    func setAIThinking(_ thinking: Bool) {
        state.setAIThinking(thinking)
    }

    func setNextAISong(_ song: Song?) {
        state.setNextAISong(song)
    }

    func clearNextAISong() {
        state.clearNextAISong()
    }

    // MARK: - Session Management

    func resetSession() {
        state.resetSession()
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
