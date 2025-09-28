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

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil) {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale
        )
        sessionHistory.append(sessionSong)

        B2BLog.session.info("Added song to history: \(song.title) by \(selectedBy == .user ? "User" : "AI")")
        let newTurn = self.currentTurn == .user ? TurnType.ai : TurnType.user
        B2BLog.session.debug("Turn change: \(self.currentTurn.rawValue) -> \(newTurn.rawValue)")

        currentTurn = currentTurn == .user ? .ai : .user
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
        currentTurn = .user
        isAIThinking = false
        nextAISong = nil
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
}

enum TurnType: String {
    case user = "User"
    case ai = "AI"
}