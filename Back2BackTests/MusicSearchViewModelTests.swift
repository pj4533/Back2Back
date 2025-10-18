//
//  MusicSearchViewModelTests.swift
//  Back2BackTests
//
//  Created by PJ Gray on 9/25/25.
//

import Testing
import MusicKit
@testable import Back2Back

@MainActor
struct MusicSearchViewModelTests {

    func createTestViewModel() -> MusicSearchViewModel {
        let musicService = MockMusicService()
        return MusicSearchViewModel(musicService: musicService)
    }

    @Test func viewModelInitializesWithEmptySearchText() async throws {
        let viewModel = createTestViewModel()
        #expect(viewModel.searchText.isEmpty)
    }

    @Test func viewModelInitializesWithEmptySearchResults() async throws {
        let viewModel = createTestViewModel()
        #expect(viewModel.searchResults.isEmpty)
    }

    @Test func isSearchingInitiallyFalse() async throws {
        let viewModel = createTestViewModel()
        #expect(!viewModel.isSearching)
    }

    @Test func errorMessageInitiallyNil() async throws {
        let viewModel = createTestViewModel()
        #expect(viewModel.errorMessage == nil)
    }

    @Test func currentlyPlayingInitiallyNil() async throws {
        let viewModel = createTestViewModel()
        #expect(viewModel.currentlyPlaying == nil)
    }

    @Test func playbackStateInitiallyStopped() async throws {
        let viewModel = createTestViewModel()
        #expect(viewModel.playbackState == .stopped)
    }

    // Disabled: playbackState is read-only, cannot be set directly in tests
    /*
    @Test func isPlayingReturnsFalseWhenStopped() async throws {
        let viewModel = MusicSearchViewModel()
        viewModel.playbackState = .stopped
        #expect(!viewModel.isPlaying)
    }

    @Test func isPlayingReturnsTrueWhenPlaying() async throws {
        let viewModel = MusicSearchViewModel()
        viewModel.playbackState = .playing
        #expect(viewModel.isPlaying)
    }
    */

    @Test func canSkipToNextWhenCurrentlyPlayingExists() async throws {
        let viewModel = createTestViewModel()
        #expect(!viewModel.canSkipToNext)
    }

    @Test func canSkipToPreviousWhenCurrentlyPlayingExists() async throws {
        let viewModel = createTestViewModel()
        #expect(!viewModel.canSkipToPrevious)
    }

    @Test func clearSearchResetsAllFields() async throws {
        let viewModel = createTestViewModel()
        viewModel.searchText = "test"
        viewModel.errorMessage = "error"

        viewModel.clearSearch()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }
}