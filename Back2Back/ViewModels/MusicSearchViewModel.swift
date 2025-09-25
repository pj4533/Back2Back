import Foundation
import MusicKit
import SwiftUI
import Combine

@MainActor
class MusicSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [MusicSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    @Published var currentlyPlaying: NowPlayingItem?
    @Published var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    private let musicService = MusicService.shared
    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        setupSearchDebouncing()
    }

    private func setupBindings() {
        musicService.$searchResults
            .assign(to: &$searchResults)

        musicService.$isSearching
            .assign(to: &$isSearching)

        musicService.$currentlyPlaying
            .assign(to: &$currentlyPlaying)

        musicService.$playbackState
            .assign(to: &$playbackState)
    }

    private func setupSearchDebouncing() {
        searchCancellable = $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] searchTerm in
                self?.performSearch(searchTerm)
            }
    }

    private func performSearch(_ searchTerm: String) {
        errorMessage = nil

        guard !searchTerm.isEmpty else {
            searchResults = []
            return
        }

        Task {
            do {
                try await musicService.searchCatalog(for: searchTerm)
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchResults = []
            }
        }
    }

    func selectSong(_ song: Song) {
        Task {
            do {
                try await musicService.playSong(song)
                errorMessage = nil
            } catch {
                errorMessage = "Failed to play song: \(error.localizedDescription)"
            }
        }
    }

    func togglePlayPause() {
        Task {
            do {
                try await musicService.togglePlayPause()
            } catch {
                errorMessage = "Playback control failed: \(error.localizedDescription)"
            }
        }
    }

    func skipToNext() {
        Task {
            do {
                try await musicService.skipToNext()
            } catch {
                errorMessage = "Failed to skip to next song"
            }
        }
    }

    func skipToPrevious() {
        Task {
            do {
                try await musicService.skipToPrevious()
            } catch {
                errorMessage = "Failed to skip to previous song"
            }
        }
    }

    var isPlaying: Bool {
        playbackState == .playing
    }

    var canSkipToNext: Bool {
        currentlyPlaying != nil
    }

    var canSkipToPrevious: Bool {
        currentlyPlaying != nil
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
}