import Foundation
import MusicKit
import SwiftUI
import Combine
import OSLog

/// Lightweight view model for Now Playing UI
/// Observes MusicService state without heavy search functionality
@MainActor
class NowPlayingViewModel: ObservableObject {
    // MARK: - Observable State
    @Published var currentlyPlaying: NowPlayingItem?
    @Published var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped

    // MARK: - Private Properties
    private let musicService = MusicService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        // Log initialization only once
        B2BLog.ui.debug("Initializing NowPlayingViewModel")
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Observe only the properties we need
        musicService.$currentlyPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentlyPlaying = value
            }
            .store(in: &cancellables)

        musicService.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.playbackState = value
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        Task {
            do {
                try await musicService.togglePlayPause()
            } catch {
                B2BLog.playback.error("❌ NowPlayingViewModel.togglePlayPause: \(error.localizedDescription)")
            }
        }
    }

    func skipToNext() {
        Task {
            do {
                try await musicService.skipToNext()
            } catch {
                B2BLog.playback.warning("Failed to skip to next song")
            }
        }
    }

    func skipToPrevious() {
        Task {
            do {
                try await musicService.skipToPrevious()
            } catch {
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
}