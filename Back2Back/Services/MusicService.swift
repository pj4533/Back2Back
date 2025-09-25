import Foundation
import MusicKit
import Combine

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

    private init() {
        updateAuthorizationStatus()
        setupPlaybackObservers()
    }

    private func updateAuthorizationStatus() {
        let status = MusicAuthorization.currentStatus
        authorizationStatus = status
        isAuthorized = status == .authorized
    }

    private func setupPlaybackObservers() {
        player.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
    }

    private func updatePlaybackState() {
        playbackState = player.state.playbackStatus

        if let currentEntry = player.queue.currentEntry {
            Task {
                do {
                    switch currentEntry.item {
                    case .song(let song):
                        currentlyPlaying = NowPlayingItem(
                            song: song,
                            isPlaying: player.state.playbackStatus == .playing,
                            playbackTime: player.playbackTime,
                            duration: song.duration ?? 0
                        )
                    default:
                        currentlyPlaying = nil
                    }
                } catch {
                    currentlyPlaying = nil
                }
            }
        } else {
            currentlyPlaying = nil
        }
    }

    func requestAuthorization() async throws {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            authorizationStatus = status
            isAuthorized = status == .authorized
        }

        guard status == .authorized else {
            switch status {
            case .denied:
                throw MusicAuthorizationError.denied
            case .restricted:
                throw MusicAuthorizationError.restricted
            default:
                throw MusicAuthorizationError.unknown
            }
        }
    }

    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws {
        guard !searchTerm.isEmpty else {
            await MainActor.run {
                searchResults = []
            }
            return
        }

        await MainActor.run {
            isSearching = true
        }

        do {
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
            request.limit = limit

            let response = try await request.response()
            let results = response.songs.map { MusicSearchResult(song: $0) }

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                isSearching = false
                searchResults = []
            }
            throw error
        }
    }

    func playSong(_ song: Song) async throws {
        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song])
            try await player.play()
        } catch {
            throw MusicPlaybackError.playbackFailed(error)
        }
    }

    func addToQueue(_ song: Song) async throws {
        do {
            try await player.queue.insert(song, position: .tail)
        } catch {
            throw MusicPlaybackError.queueFailed
        }
    }

    func togglePlayPause() async throws {
        if player.state.playbackStatus == .playing {
            player.pause()
        } else {
            try await player.play()
        }
    }

    func skipToNext() async throws {
        try await player.skipToNextEntry()
    }

    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
    }

    func clearQueue() {
        player.queue = ApplicationMusicPlayer.Queue()
    }
}