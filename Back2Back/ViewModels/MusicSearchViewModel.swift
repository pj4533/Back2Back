import Foundation
import MusicKit
import SwiftUI
import Combine
import Observation
import OSLog

/// High-performance search implementation with non-blocking UI updates
/// Uses Combine for debouncing to avoid excessive Task creation
@MainActor
@Observable
class MusicSearchViewModel {
    // MARK: - Observable State
    // Remove didSet to prevent synchronous updates
    var searchText: String = ""
    var searchResults: [MusicSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?

    // MARK: - Private Properties
    private let musicService = MusicService.shared
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Use Combine for efficient debouncing instead of Task creation/cancellation
    private let searchSubject = PassthroughSubject<String, Never>()

    /// Debounce duration in seconds (0.75s for better UX)
    private let debounceDuration: TimeInterval = 0.75

    // MARK: - Initialization
    init() {
        // Use debug level for initialization logs to reduce noise
        B2BLog.search.debug("Initializing MusicSearchViewModel")
        setupBindings()
        setupSearchPipeline()
    }

    // MARK: - Computed Properties from MusicService
    var currentlyPlaying: NowPlayingItem? {
        musicService.currentlyPlaying
    }

    var playbackState: ApplicationMusicPlayer.PlaybackStatus {
        musicService.playbackState
    }

    // MARK: - Setup
    private func setupBindings() {
        // No longer needed for MusicService observation since we use computed properties
    }

    /// Setup efficient search pipeline using Combine
    private func setupSearchPipeline() {
        searchSubject
            .debounce(for: .seconds(debounceDuration), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] searchTerm in
                guard let self else { return }
                Task { @MainActor in
                    await self.performSearch(for: searchTerm)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Logic with Non-Blocking Updates

    /// Truly non-blocking async method to update search text
    func updateSearchTextAsync(_ newText: String) async {
        // Store the text without triggering immediate UI updates
        searchText = newText

        // Send to search pipeline on background queue
        Task.detached { [weak self, newText] in
            await self?.searchSubject.send(newText)
        }
    }

    /// Performs the actual search with proper task management
    private func performSearch(for searchTerm: String) async {
        // Cancel any existing search task
        searchTask?.cancel()

        // Clear results if search term is empty
        guard !searchTerm.isEmpty else {
            Task.detached(priority: .utility) {
                await B2BLog.search.debug("Search term is empty, clearing results")
            }
            // Update UI properties asynchronously to avoid blocking
            Task { @MainActor in
                self.searchResults = []
                self.errorMessage = nil
            }
            return
        }

        // Create new search task with structured concurrency
        searchTask = Task { [weak self] in
            guard let self else { return }

            // Update UI state
            self.isSearching = true
            self.errorMessage = nil

            // Defer logging to avoid blocking
            Task.detached(priority: .utility) {
                await B2BLog.search.info("🔍 Performing search for: \(searchTerm)")
            }
            let startTime = Date()

            do {
                // Check for cancellation before making the API call
                try Task.checkCancellation()

                // Perform the search
                let results = try await self.searchMusicCatalog(for: searchTerm)

                // Check for cancellation before updating UI
                try Task.checkCancellation()

                let duration = Date().timeIntervalSince(startTime)
                // Defer logging to avoid blocking UI updates
                Task.detached(priority: .utility) {
                    await B2BLog.search.debug("⏱️ searchDuration: \(duration)")
                    await B2BLog.search.info("Found \(results.count) results for '\(searchTerm)' in \(String(format: "%.2f", duration))s")
                }

                // Update UI
                self.searchResults = results
                self.isSearching = false

            } catch is CancellationError {
                // Search was cancelled, don't update UI
                Task.detached(priority: .utility) {
                    await B2BLog.search.debug("Search task cancelled for: \(searchTerm)")
                }
                self.isSearching = false
            } catch {
                Task.detached(priority: .utility) {
                    await B2BLog.search.error("❌ MusicSearchViewModel.performSearch: \(error.localizedDescription)")
                }
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

        Task.detached(priority: .utility) {
            await B2BLog.network.debug("🌐 API: MusicCatalogSearchRequest")
        }
        let response = try await request.response()

        // Convert to our model type
        return response.songs.map { MusicSearchResult(song: $0) }
    }

    // MARK: - User Actions

    func selectSong(_ song: Song) {
        Task {
            Task.detached(priority: .utility) {
                await B2BLog.playback.info("👤 Selected song: \(song.title)")
            }
            do {
                try await musicService.playSong(song)
                errorMessage = nil
            } catch {
                errorMessage = "Failed to play song: \(error.localizedDescription)"
                Task.detached(priority: .utility) {
                    await B2BLog.playback.error("❌ MusicSearchViewModel.selectSong: \(error.localizedDescription)")
                }
            }
        }
    }

    func togglePlayPause() {
        Task {
            do {
                try await musicService.togglePlayPause()
            } catch {
                errorMessage = "Playback control failed: \(error.localizedDescription)"
                Task.detached(priority: .utility) {
                    await B2BLog.playback.error("❌ MusicSearchViewModel.togglePlayPause: \(error.localizedDescription)")
                }
            }
        }
    }

    func skipToNext() {
        Task {
            do {
                try await musicService.skipToNext()
            } catch {
                errorMessage = "Failed to skip to next song"
                Task.detached(priority: .utility) {
                    await B2BLog.playback.warning("Failed to skip to next song")
                }
            }
        }
    }

    func skipToPrevious() {
        Task {
            do {
                try await musicService.skipToPrevious()
            } catch {
                errorMessage = "Failed to skip to previous song"
                Task.detached(priority: .utility) {
                    await B2BLog.playback.warning("Failed to skip to previous song")
                }
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

    func clearSearchAsync() async {
        Task.detached(priority: .utility) {
            await B2BLog.ui.info("👤 Clear search")
        }

        // Cancel any pending search operations
        searchTask?.cancel()

        // Clear state asynchronously
        await MainActor.run {
            searchText = ""
            searchResults = []
            errorMessage = nil
        }

        // Clear the search pipeline
        searchSubject.send("")
    }

    // MARK: - Performance Optimization

    /// Force cancels all pending operations (useful for view dismissal)
    func cancelAllOperations() {
        searchTask?.cancel()
        Task.detached(priority: .utility) {
            await B2BLog.search.info("Cancelled all pending search operations")
        }
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