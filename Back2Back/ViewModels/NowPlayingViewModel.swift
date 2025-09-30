import Foundation
import MusicKit
import SwiftUI
import Observation
import OSLog

/// Lightweight view model for Now Playing UI
/// Directly accesses MusicService singleton for state
@MainActor
@Observable
class NowPlayingViewModel {
    // MARK: - Private Properties
    // Use concrete @Observable type for SwiftUI observation to work
    private let musicService: MusicService

    // MARK: - Initialization
    init(musicService: MusicService = MusicService.shared) {
        self.musicService = musicService
        // Log initialization only once
        B2BLog.ui.debug("Initializing NowPlayingViewModel")
    }

    // MARK: - Computed Properties from MusicService
    var currentlyPlaying: NowPlayingItem? {
        musicService.currentlyPlaying
    }

    var playbackState: ApplicationMusicPlayer.PlaybackStatus {
        musicService.playbackState
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