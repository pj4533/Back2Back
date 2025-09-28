//
//  SessionServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-09-27.
//

import Testing
import Foundation
@testable import Back2Back
import MusicKit

@Suite("SessionService Tests")
struct SessionServiceTests {
    @MainActor
    @Test("Initial state")
    func testInitialState() {
        let service = SessionService.shared

        // Test initial values
        #expect(service.sessionHistory.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
        #expect(!service.currentPersona.isEmpty)
    }

    @MainActor
    @Test("Add song to history - User")
    func testAddUserSongToHistory() async throws {
        let service = SessionService.shared
        service.resetSession()

        // Create a mock song
        let mockSong = Song(
            id: MusicItemID("test-song-1"),
            title: "Test Song",
            artistName: "Test Artist"
        )

        // Add song selected by user
        service.addSongToHistory(mockSong, selectedBy: .user, rationale: nil)

        // Verify history
        #expect(service.sessionHistory.count == 1)
        #expect(service.sessionHistory.first?.song.title == "Test Song")
        #expect(service.sessionHistory.first?.selectedBy == .user)
        #expect(service.sessionHistory.first?.rationale == nil)

        // Verify turn changed to AI
        #expect(service.currentTurn == .ai)
    }

    @MainActor
    @Test("Add song to history - AI with rationale")
    func testAddAISongToHistory() async throws {
        let service = SessionService.shared
        service.resetSession()

        // Create a mock song
        let mockSong = Song(
            id: MusicItemID("test-song-2"),
            title: "AI Selected Song",
            artistName: "AI Artist"
        )

        // First add a user song to set turn to AI
        let userSong = Song(
            id: MusicItemID("user-song"),
            title: "User Song",
            artistName: "User Artist"
        )
        service.addSongToHistory(userSong, selectedBy: .user)

        // Add AI song with rationale
        let rationale = "This groove complements the previous track perfectly"
        service.addSongToHistory(mockSong, selectedBy: .ai, rationale: rationale)

        // Verify history
        #expect(service.sessionHistory.count == 2)
        #expect(service.sessionHistory[1].song.title == "AI Selected Song")
        #expect(service.sessionHistory[1].selectedBy == .ai)
        #expect(service.sessionHistory[1].rationale == rationale)

        // Verify turn changed back to user
        #expect(service.currentTurn == .user)
    }

    @MainActor
    @Test("Turn alternation")
    func testTurnAlternation() async throws {
        let service = SessionService.shared
        service.resetSession()

        #expect(service.currentTurn == .user)

        // User turn
        let song1 = Song(id: MusicItemID("1"), title: "Song 1", artistName: "Artist 1")
        service.addSongToHistory(song1, selectedBy: .user)
        #expect(service.currentTurn == .ai)

        // AI turn
        let song2 = Song(id: MusicItemID("2"), title: "Song 2", artistName: "Artist 2")
        service.addSongToHistory(song2, selectedBy: .ai)
        #expect(service.currentTurn == .user)

        // User turn again
        let song3 = Song(id: MusicItemID("3"), title: "Song 3", artistName: "Artist 3")
        service.addSongToHistory(song3, selectedBy: .user)
        #expect(service.currentTurn == .ai)
    }

    @MainActor
    @Test("AI thinking state")
    func testAIThinkingState() async throws {
        let service = SessionService.shared

        #expect(service.isAIThinking == false)

        service.setAIThinking(true)
        #expect(service.isAIThinking == true)

        service.setAIThinking(false)
        #expect(service.isAIThinking == false)
    }

    @MainActor
    @Test("Next AI song management")
    func testNextAISongManagement() async throws {
        let service = SessionService.shared

        #expect(service.nextAISong == nil)

        let mockSong = Song(
            id: MusicItemID("ai-prefetch"),
            title: "Prefetched Song",
            artistName: "Prefetch Artist"
        )

        service.setNextAISong(mockSong)
        #expect(service.nextAISong?.title == "Prefetched Song")

        service.clearNextAISong()
        #expect(service.nextAISong == nil)
    }

    @MainActor
    @Test("Check if song has been played")
    func testHasSongBeenPlayed() async throws {
        let service = SessionService.shared
        service.resetSession()

        let song1 = Song(
            id: MusicItemID("played-1"),
            title: "Already Played",
            artistName: "Test Artist"
        )
        service.addSongToHistory(song1, selectedBy: .user)

        // Exact match
        #expect(service.hasSongBeenPlayed(artist: "Test Artist", title: "Already Played"))

        // Case insensitive
        #expect(service.hasSongBeenPlayed(artist: "test artist", title: "already played"))

        // Not played
        #expect(!service.hasSongBeenPlayed(artist: "Different Artist", title: "Different Song"))
        #expect(!service.hasSongBeenPlayed(artist: "Test Artist", title: "Different Song"))
    }

    @MainActor
    @Test("Reset session")
    func testResetSession() async throws {
        let service = SessionService.shared

        // Add some data
        let song = Song(id: MusicItemID("reset-test"), title: "Song", artistName: "Artist")
        service.addSongToHistory(song, selectedBy: .user)
        service.setAIThinking(true)
        service.setNextAISong(song)

        // Reset
        service.resetSession()

        // Verify all cleared
        #expect(service.sessionHistory.isEmpty)
        #expect(service.currentTurn == .user)
        #expect(service.isAIThinking == false)
        #expect(service.nextAISong == nil)
    }

    @MainActor
    @Test("Session history order")
    func testSessionHistoryOrder() async throws {
        let service = SessionService.shared
        service.resetSession()

        let songs = [
            Song(id: MusicItemID("1"), title: "First", artistName: "Artist 1"),
            Song(id: MusicItemID("2"), title: "Second", artistName: "Artist 2"),
            Song(id: MusicItemID("3"), title: "Third", artistName: "Artist 3")
        ]

        for (index, song) in songs.enumerated() {
            let turn: TurnType = index % 2 == 0 ? .user : .ai
            service.addSongToHistory(song, selectedBy: turn)
        }

        #expect(service.sessionHistory.count == 3)
        #expect(service.sessionHistory[0].song.title == "First")
        #expect(service.sessionHistory[1].song.title == "Second")
        #expect(service.sessionHistory[2].song.title == "Third")
    }
}