import Foundation
import MusicKit
import Combine
import OSLog

@MainActor
class MusicService: ObservableObject {
    static let shared = MusicService()

    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var searchResults: [MusicSearchResult] = []
    @Published var currentlyPlaying: NowPlayingItem?
    @Published var isSearching: Bool = false
    @Published var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    private let player = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()

    private static var isInitialized = false

    private init() {
        // Prevent duplicate initialization logs
        if !Self.isInitialized {
            B2BLog.musicKit.info("🎵 Initializing MusicService (singleton)")
            Self.isInitialized = true
        }
        updateAuthorizationStatus()
        setupPlaybackObservers()
    }

    private func updateAuthorizationStatus() {
        let status = MusicAuthorization.currentStatus
        authorizationStatus = status
        isAuthorized = status == .authorized
        B2BLog.auth.info("Authorization status: \(String(describing: status))")
    }

    private func setupPlaybackObservers() {
        player.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
    }

    private var lastLoggedSongId: String?

    private func updatePlaybackState() {
        let oldState = playbackState
        playbackState = player.state.playbackStatus

        if oldState != playbackState {
            B2BLog.playback.info("🔄 State: \(String(describing: oldState)) → \(String(describing: self.playbackState))")
        }

        if let currentEntry = player.queue.currentEntry {
            Task {
                do {
                    switch currentEntry.item {
                    case .song(let song):
                        let wasPlaying = currentlyPlaying?.song.id
                        currentlyPlaying = NowPlayingItem(
                            song: song,
                            isPlaying: player.state.playbackStatus == .playing,
                            playbackTime: player.playbackTime,
                            duration: song.duration ?? 0
                        )
                        // Only log when the song actually changes, not on every state update
                        if song.id.rawValue != lastLoggedSongId {
                            B2BLog.playback.info("🎵 Now playing: \(song.title) by \(song.artistName)")
                            lastLoggedSongId = song.id.rawValue
                        }
                    default:
                        currentlyPlaying = nil
                        if lastLoggedSongId != nil {
                            B2BLog.playback.debug("Current queue entry is not a song")
                            lastLoggedSongId = nil
                        }
                    }
                } catch {
                    currentlyPlaying = nil
                    B2BLog.playback.error("❌ updatePlaybackState: \(error.localizedDescription)")
                }
            }
        } else {
            currentlyPlaying = nil
            lastLoggedSongId = nil
        }
    }

    func requestAuthorization() async throws {
        B2BLog.auth.trace("→ Entering requestAuthorization")

        let status = await MusicAuthorization.request()
        B2BLog.auth.info("Authorization request returned: \(String(describing: status))")

        await MainActor.run {
            authorizationStatus = status
            isAuthorized = status == .authorized
        }

        guard status == .authorized else {
            let error: MusicAuthorizationError
            switch status {
            case .denied:
                error = MusicAuthorizationError.denied
            case .restricted:
                error = MusicAuthorizationError.restricted
            default:
                error = MusicAuthorizationError.unknown
            }
            B2BLog.auth.error("❌ requestAuthorization: \(error.localizedDescription)")
            throw error
        }

        B2BLog.auth.info("✅ Music authorization granted")
        B2BLog.auth.trace("← Exiting requestAuthorization")
    }

    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws {
        guard !searchTerm.isEmpty else {
            B2BLog.search.debug("Empty search term, clearing results")
            await MainActor.run {
                searchResults = []
            }
            return
        }

        B2BLog.search.info("🔍 Searching for: \(searchTerm)")
        let startTime = Date()

        await MainActor.run {
            isSearching = true
        }

        do {
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
            request.limit = limit

            B2BLog.network.debug("🌐 API: MusicCatalogSearchRequest")
            let response = try await request.response()
            let results = response.songs.map { MusicSearchResult(song: $0) }

            let duration = Date().timeIntervalSince(startTime)
            B2BLog.search.debug("⏱️ searchDuration: \(duration)")
            B2BLog.search.info("Found \(results.count) results for '\(searchTerm)'")

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            B2BLog.search.error("❌ searchCatalog: \(error.localizedDescription)")
            await MainActor.run {
                isSearching = false
                searchResults = []
            }
            throw error
        }
    }

    func playSong(_ song: Song) async throws {
        B2BLog.playback.info("👤 Play song: \(song.title)")

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song])
            try await player.play()
            B2BLog.playback.info("✅ Started playback: \(song.title) by \(song.artistName)")
        } catch {
            let playbackError = MusicPlaybackError.playbackFailed(error)
            B2BLog.playback.error("❌ playSong: \(playbackError.localizedDescription)")
            throw playbackError
        }
    }

    func addToQueue(_ song: Song) async throws {
        B2BLog.playback.info("➕ Adding to queue: \(song.title)")

        do {
            try await player.queue.insert(song, position: .tail)
            B2BLog.playback.info("✅ Added to queue: \(song.title)")
        } catch {
            let queueError = MusicPlaybackError.queueFailed
            B2BLog.playback.error("❌ addToQueue: \(queueError.localizedDescription)")
            throw queueError
        }
    }

    func togglePlayPause() async throws {
        if player.state.playbackStatus == .playing {
            B2BLog.playback.info("👤 Pause playback")
            player.pause()
        } else {
            B2BLog.playback.info("👤 Resume playback")
            try await player.play()
        }
    }

    func skipToNext() async throws {
        B2BLog.playback.info("👤 Skip to next")
        try await player.skipToNextEntry()
    }

    func skipToPrevious() async throws {
        B2BLog.playback.info("👤 Skip to previous")
        try await player.skipToPreviousEntry()
    }

    func clearQueue() {
        B2BLog.playback.info("🗑️ Clearing playback queue")
        player.queue = ApplicationMusicPlayer.Queue()
    }

    func getCurrentPlaybackTime() -> TimeInterval {
        // Return the current real-time playback position
        return player.playbackTime
    }
}