import Foundation
import MusicKit
@testable import Back2Back

@MainActor
class MockSessionStateManager: SessionStateManagerProtocol {
    var sessionHistory: [SessionSong] = []
    var songQueue: [SessionSong] = []
    var isAIThinking: Bool = false
    var nextAISong: Song?
    var currentPersonaStyleGuide: String = "Mock style guide"
    var currentPersonaName: String = "Mock Persona"

    var addSongToHistoryCalled = false
    var queueSongCalled = false
    var updateSongStatusCalled = false
    var moveQueuedSongToHistoryCalled = false
    var clearAIQueuedSongsCalled = false

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus = .played) {
        addSongToHistoryCalled = true
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        sessionHistory.append(sessionSong)
    }

    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        queueSongCalled = true
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        songQueue.append(sessionSong)
        return sessionSong
    }

    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        updateSongStatusCalled = true
        if let index = songQueue.firstIndex(where: { $0.id == id }) {
            songQueue[index].queueStatus = newStatus
        }
    }

    func moveQueuedSongToHistory(_ songId: UUID) {
        moveQueuedSongToHistoryCalled = true
        if let index = songQueue.firstIndex(where: { $0.id == songId }) {
            var song = songQueue.remove(at: index)
            song.queueStatus = .played
            sessionHistory.append(song)
        }
    }

    func updateCurrentlyPlayingSong(songId: String) {
        // Mock implementation
    }

    func getNextQueuedSong() -> SessionSong? {
        songQueue.first(where: { $0.queueStatus == .upNext })
    }

    func clearAIQueuedSongs() {
        clearAIQueuedSongsCalled = true
        songQueue.removeAll(where: { $0.selectedBy == .ai })
    }

    func markCurrentSongAsPlayed() {
        // Mock implementation
    }

    func getCurrentlyPlayingSessionSong() -> SessionSong? {
        sessionHistory.first(where: { $0.queueStatus == .playing })
    }

    func setAIThinking(_ thinking: Bool) {
        isAIThinking = thinking
    }

    func setNextAISong(_ song: Song?) {
        nextAISong = song
    }

    func clearNextAISong() {
        nextAISong = nil
    }

    func resetSession() {
        sessionHistory.removeAll()
        songQueue.removeAll()
        isAIThinking = false
        nextAISong = nil
    }

    func hasSongBeenPlayed(artist: String, title: String) -> Bool {
        sessionHistory.contains { song in
            song.song.artistName.lowercased() == artist.lowercased() &&
            song.song.title.lowercased() == title.lowercased()
        }
    }

    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        if let index = songQueue.firstIndex(where: { $0.id == songId }) {
            songQueue.removeSubrange(0..<index)
        }
    }
}
