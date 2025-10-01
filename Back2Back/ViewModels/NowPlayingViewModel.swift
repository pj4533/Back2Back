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

    // MARK: - Live Playback Tracking
    private(set) var livePlaybackTime: TimeInterval = 0
    nonisolated(unsafe) private var playbackTimer: Task<Void, Never>?

    // MARK: - Initialization
    init(musicService: MusicService = MusicService.shared) {
        self.musicService = musicService
        // Log initialization only once
        B2BLog.ui.debug("Initializing NowPlayingViewModel")
        startPlaybackTracking()
    }

    nonisolated deinit {
        playbackTimer?.cancel()
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

    // MARK: - Seek Controls

    func seek(to time: TimeInterval) {
        Task {
            do {
                try await musicService.seek(to: time)
                livePlaybackTime = time
            } catch {
                B2BLog.playback.error("❌ Seek failed: \(error.localizedDescription)")
            }
        }
    }

    func skipForward() {
        Task {
            do {
                try await musicService.skipForward(15)
            } catch {
                B2BLog.playback.error("❌ Skip forward failed: \(error.localizedDescription)")
            }
        }
    }

    func skipBackward() {
        Task {
            do {
                try await musicService.skipBackward(15)
            } catch {
                B2BLog.playback.error("❌ Skip backward failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func startPlaybackTracking() {
        playbackTimer = Task { @MainActor in
            while !Task.isCancelled {
                if playbackState == .playing {
                    livePlaybackTime = musicService.getCurrentPlaybackTime()
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}