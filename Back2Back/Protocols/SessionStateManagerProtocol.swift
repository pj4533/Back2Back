import Foundation
import MusicKit

@MainActor
protocol SessionStateManagerProtocol {
    var sessionHistory: [SessionSong] { get }
    var songQueue: [SessionSong] { get }
    var isAIThinking: Bool { get }
    var nextAISong: Song? { get }
    var currentPersonaStyleGuide: String { get }
    var currentPersonaName: String { get }

    func addSongToHistory(_ song: Song, selectedBy: TurnType, rationale: String?, queueStatus: QueueStatus)
    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String?, queueStatus: QueueStatus) -> SessionSong
    func updateSongStatus(id: UUID, newStatus: QueueStatus)
    func moveQueuedSongToHistory(_ songId: UUID)
    func updateCurrentlyPlayingSong(songId: String)
    func getNextQueuedSong() -> SessionSong?
    func clearAIQueuedSongs()
    func markCurrentSongAsPlayed()
    func getCurrentlyPlayingSessionSong() -> SessionSong?
    func setAIThinking(_ thinking: Bool)
    func setNextAISong(_ song: Song?)
    func clearNextAISong()
    func resetSession()
    func hasSongBeenPlayed(artist: String, title: String) -> Bool
    func removeQueuedSongsBeforeSong(_ songId: UUID)
}
