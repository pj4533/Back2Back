import Foundation
import MusicKit
import SwiftUI
import Combine
import OSLog

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
        B2BLog.search.info("🔍 Initializing MusicSearchViewModel")
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
            B2BLog.search.debug("Search term is empty, clearing results")
            searchResults = []
            return
        }

        Task {
            B2BLog.search.info("Performing search for: \(searchTerm)")
            do {
                try await musicService.searchCatalog(for: searchTerm)
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchResults = []
                B2BLog.search.error(error, context: "MusicSearchViewModel.performSearch")
            }
        }
    }

    func selectSong(_ song: Song) {
        Task {
            B2BLog.playback.userAction("Selected song: \(song.title)")
            do {
                try await musicService.playSong(song)
                errorMessage = nil
            } catch {
                errorMessage = "Failed to play song: \(error.localizedDescription)"
                B2BLog.playback.error(error, context: "MusicSearchViewModel.selectSong")
            }
        }
    }

    func togglePlayPause() {
        Task {
            do {
                try await musicService.togglePlayPause()
            } catch {
                errorMessage = "Playback control failed: \(error.localizedDescription)"
                B2BLog.playback.error(error, context: "MusicSearchViewModel.togglePlayPause")
            }
        }
    }

    func skipToNext() {
        Task {
            do {
                try await musicService.skipToNext()
            } catch {
                errorMessage = "Failed to skip to next song"
                B2BLog.playback.warning("Failed to skip to next song")
            }
        }
    }

    func skipToPrevious() {
        Task {
            do {
                try await musicService.skipToPrevious()
            } catch {
                errorMessage = "Failed to skip to previous song"
                B2BLog.playback.warning("Failed to skip to previous song")
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
        B2BLog.ui.userAction("Clear search")
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
}