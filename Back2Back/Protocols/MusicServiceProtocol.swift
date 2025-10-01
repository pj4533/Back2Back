import Foundation
import MusicKit

@MainActor
protocol MusicServiceProtocol {
    var authorizationStatus: MusicAuthorization.Status { get }
    var isAuthorized: Bool { get }
    var searchResults: [MusicSearchResult] { get }
    var currentlyPlaying: NowPlayingItem? { get }
    var isSearching: Bool { get }
    var playbackState: ApplicationMusicPlayer.PlaybackStatus { get }

    func requestAuthorization() async throws
    func searchCatalog(for searchTerm: String, limit: Int) async throws -> [MusicSearchResult]
    func playSong(_ song: Song) async throws
    func addToQueue(_ song: Song) async throws
    func togglePlayPause() async throws
    func skipToNext() async throws
    func skipToPrevious() async throws
    func clearQueue()
    func getCurrentPlaybackTime() -> TimeInterval
}
