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
    func searchCatalogWithPagination(for searchTerm: String, pageSize: Int, maxResults: Int) async throws -> [MusicSearchResult]
    func playSong(_ song: Song) async throws
    func addToQueue(_ song: Song) async throws
    func togglePlayPause() async throws
    func skipToNext() async throws
    func skipToPrevious() async throws
    func clearQueue()
    func getCurrentPlaybackTime() -> TimeInterval
    func seek(to time: TimeInterval) async throws
    func skipForward(_ seconds: TimeInterval) async throws
    func skipBackward(_ seconds: TimeInterval) async throws
}
