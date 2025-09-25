import Foundation
import MusicKit
import SwiftUI
import Combine
import OSLog

/// Modern search implementation using Swift Concurrency with proper task cancellation
/// and debouncing to ensure smooth UI performance
@MainActor
@Observable
class MusicSearchViewModel {
    // MARK: - Observable State
    var searchText: String = "" {
        didSet {
            // Trigger search when text changes
            scheduleSearch()
        }
    }
    var searchResults: [MusicSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?
    var currentlyPlaying: NowPlayingItem?
    var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    // MARK: - Private Properties
    private let musicService = MusicService.shared
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Debounce duration in nanoseconds (750ms for better UX)
    private let debounceDuration: UInt64 = 750_000_000

    // MARK: - Initialization
    init() {
        B2BLog.search.info("🔍 Initializing MusicSearchViewModel with Swift Concurrency")
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Use Combine for simple observation of published properties
        musicService.$currentlyPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.currentlyPlaying = value
            }
            .store(in: &cancellables)

        musicService.$playbackState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.playbackState = value
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Logic with Proper Debouncing and Cancellation

    /// Schedules a search with proper debouncing and task cancellation
    private func scheduleSearch() {
        // Cancel any existing debounce task
        debounceTask?.cancel()

        // Create new debounce task
        debounceTask = Task { [weak self, searchText] in
            guard let self else { return }

            // Wait for debounce duration
            do {
                try await Task.sleep(nanoseconds: debounceDuration)
            } catch {
                // Task was cancelled during sleep
                return
            }

            // Check if task is still valid (not cancelled)
            guard !Task.isCancelled else { return }

            // Perform the actual search
            await self.performSearch(for: searchText)
        }
    }

    /// Performs the actual search with proper task management
    private func performSearch(for searchTerm: String) async {
        // Cancel any existing search task
        searchTask?.cancel()

        // Clear results if search term is empty
        guard !searchTerm.isEmpty else {
            B2BLog.search.debug("Search term is empty, clearing results")
            searchResults = []
            errorMessage = nil
            return
        }

        // Create new search task with structured concurrency
        searchTask = Task { [weak self] in
            guard let self else { return }

            // Update UI state
            self.isSearching = true
            self.errorMessage = nil

            B2BLog.search.info("🔍 Performing search for: \(searchTerm)")
            let startTime = Date()

            do {
                // Check for cancellation before making the API call
                try Task.checkCancellation()

                // Perform the search
                let results = try await self.searchMusicCatalog(for: searchTerm)

                // Check for cancellation before updating UI
                try Task.checkCancellation()

                let duration = Date().timeIntervalSince(startTime)
                B2BLog.search.performance("searchDuration", value: duration)
                B2BLog.search.info("Found \(results.count) results for '\(searchTerm)' in \(String(format: "%.2f", duration))s")

                // Update UI
                self.searchResults = results
                self.isSearching = false

            } catch is CancellationError {
                // Search was cancelled, don't update UI
                B2BLog.search.debug("Search task cancelled for: \(searchTerm)")
                self.isSearching = false
            } catch {
                B2BLog.search.error(error, context: "MusicSearchViewModel.performSearch")
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    /// Isolated search function that can be cancelled
    private func searchMusicCatalog(for searchTerm: String, limit: Int = 25) async throws -> [MusicSearchResult] {
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = limit

        B2BLog.network.apiCall("MusicCatalogSearchRequest")
        let response = try await request.response()

        // Convert to our model type
        return response.songs.map { MusicSearchResult(song: $0) }
    }

    // MARK: - User Actions

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

    // MARK: - Computed Properties

    var isPlaying: Bool {
        playbackState == .playing
    }

    var canSkipToNext: Bool {
        currentlyPlaying != nil
    }

    var canSkipToPrevious: Bool {
        currentlyPlaying != nil
    }

    // MARK: - UI Actions

    func clearSearch() {
        B2BLog.ui.userAction("Clear search")

        // Cancel any pending search operations
        searchTask?.cancel()
        debounceTask?.cancel()

        // Clear state
        searchText = ""
        searchResults = []
        errorMessage = nil
    }

    // MARK: - Performance Optimization

    /// Force cancels all pending operations (useful for view dismissal)
    func cancelAllOperations() {
        searchTask?.cancel()
        debounceTask?.cancel()
        B2BLog.search.info("Cancelled all pending search operations")
    }

    /// Preloads search results for better perceived performance
    func preloadSearchResults() {
        // Preload artwork for visible results
        Task {
            for result in searchResults.prefix(10) {
                if let artwork = result.artwork {
                    _ = artwork.url(width: 60, height: 60)
                }
            }
        }
    }
}