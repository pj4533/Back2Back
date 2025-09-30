import Foundation
import MusicKit
@testable import Back2Back

@MainActor
class MockMusicService: MusicServiceProtocol {
    var authorizationStatus: MusicAuthorization.Status = .authorized
    var isAuthorized: Bool = true
    var searchResults: [MusicSearchResult] = []
    var currentlyPlaying: NowPlayingItem?
    var isSearching: Bool = false
    var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    var requestAuthorizationCalled = false
    var searchCatalogCalled = false
    var playSongCalled = false
    var addToQueueCalled = false
    var lastSearchTerm: String?
    var lastPlayedSong: Song?
    var lastQueuedSong: Song?

    func requestAuthorization() async throws {
        requestAuthorizationCalled = true
        isAuthorized = true
        authorizationStatus = .authorized
    }

    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws {
        searchCatalogCalled = true
        lastSearchTerm = searchTerm
        isSearching = true
        // Simulate delay
        try? await Task.sleep(nanoseconds: 100_000_000)
        isSearching = false
    }

    func playSong(_ song: Song) async throws {
        playSongCalled = true
        lastPlayedSong = song
        playbackState = .playing
    }

    func addToQueue(_ song: Song) async throws {
        addToQueueCalled = true
        lastQueuedSong = song
    }

    func togglePlayPause() async throws {
        playbackState = playbackState == .playing ? .paused : .playing
    }

    func skipToNext() async throws {
        // Mock implementation
    }

    func skipToPrevious() async throws {
        // Mock implementation
    }

    func clearQueue() {
        // Mock implementation
    }

    func getCurrentPlaybackTime() -> TimeInterval {
        return 0
    }
}
