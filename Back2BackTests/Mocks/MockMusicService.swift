import Foundation
import MusicKit
@testable import Back2Back

/// Mock MusicService for testing - subclasses real MusicService to override behavior
@MainActor
class MockMusicService: MusicService {
    // Override stored properties with test values
    override var authorizationStatus: MusicAuthorization.Status {
        get { _authorizationStatus }
        set { _authorizationStatus = newValue }
    }
    private var _authorizationStatus: MusicAuthorization.Status = .authorized

    override var isAuthorized: Bool {
        _authorizationStatus == .authorized
    }

    override var currentlyPlaying: NowPlayingItem? {
        get { _currentlyPlaying }
        set { _currentlyPlaying = newValue }
    }
    private var _currentlyPlaying: NowPlayingItem?

    override var isSearching: Bool {
        get { _isSearching }
        set { _isSearching = newValue }
    }
    private var _isSearching: Bool = false

    override var playbackState: ApplicationMusicPlayer.PlaybackStatus {
        get { _playbackState }
        set { _playbackState = newValue }
    }
    private var _playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    // Test tracking
    var requestAuthorizationCalled = false
    var searchCatalogCalled = false
    var playSongCalled = false
    var addToQueueCalled = false
    var lastSearchTerm: String?
    var lastPlayedSong: Song?
    var lastQueuedSong: Song?

    // Test data
    private var _searchResults: [MusicSearchResult] = []

    override var searchResults: [MusicSearchResult] {
        get { _searchResults }
        set { _searchResults = newValue }
    }

    override func requestAuthorization() async throws {
        requestAuthorizationCalled = true
        _authorizationStatus = .authorized
    }

    override func searchCatalog(for searchTerm: String, limit: Int = 25) async throws -> [MusicSearchResult] {
        searchCatalogCalled = true
        lastSearchTerm = searchTerm
        _isSearching = true
        // Simulate delay
        try? await Task.sleep(nanoseconds: 100_000_000)
        _isSearching = false
        return _searchResults
    }

    override func searchCatalogWithPagination(for searchTerm: String, pageSize: Int = 25, maxResults: Int = 200) async throws -> [MusicSearchResult] {
        return try await searchCatalog(for: searchTerm, limit: pageSize)
    }

    override func playSong(_ song: Song) async throws {
        playSongCalled = true
        lastPlayedSong = song
        _playbackState = .playing
    }

    override func addToQueue(_ song: Song) async throws {
        addToQueueCalled = true
        lastQueuedSong = song
    }

    override func togglePlayPause() async throws {
        _playbackState = _playbackState == .playing ? .paused : .playing
    }

    override func getCurrentPlaybackTime() -> TimeInterval {
        return 0
    }
}
