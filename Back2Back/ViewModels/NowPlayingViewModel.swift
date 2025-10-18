import Foundation
import MusicKit
import SwiftUI
import Observation
import OSLog

/// Lightweight view model for Now Playing UI
/// Uses animation-based progress tracking instead of polling for better performance
/// Follows Apple's recommendation for MusicKit playback time observation
@MainActor
@Observable
class NowPlayingViewModel {
    // MARK: - Private Properties
    // Use concrete @Observable type for SwiftUI observation to work
    private let musicService: MusicService

    // MARK: - Animation-Based Playback Tracking
    // Instead of polling every 500ms, we track a base time and calculate elapsed time
    // This approach is recommended by Apple engineers for MusicKit
    // See: https://forums.developer.apple.com/forums/thread/687487

    /// Base playback time when animation started (or state changed)
    var basePlaybackTime: TimeInterval = 0

    /// When the current animation period started
    var animationStartTime: Date?

    // MARK: - Initialization
    init(musicService: MusicService) {
        self.musicService = musicService
        B2BLog.ui.debug("Initializing NowPlayingViewModel with animation-based tracking")
    }

    // MARK: - Computed Properties from MusicService
    var currentlyPlaying: NowPlayingItem? {
        musicService.currentlyPlaying
    }

    var playbackState: ApplicationMusicPlayer.PlaybackStatus {
        musicService.playbackState
    }

    // MARK: - Playback Time Management

    /// Calculate current playback time based on elapsed time since animation start
    /// This is called by TimelineView on each frame (60fps for progress bar, 2fps for labels)
    /// Returns the actual current playback position without polling
    func getCurrentPlaybackTime() -> TimeInterval {
        guard isPlaying, let startTime = animationStartTime else {
            // When paused or stopped, return the base time
            return basePlaybackTime
        }

        // Calculate elapsed time since animation started
        let elapsed = Date().timeIntervalSince(startTime)
        return basePlaybackTime + elapsed
    }

    /// Update the base playback time when playback state changes
    /// This resets the animation reference point to ensure accuracy
    func updateBasePlaybackTime() {
        basePlaybackTime = musicService.getCurrentPlaybackTime()
        animationStartTime = Date()
        B2BLog.playback.debug("Updated base playback time: \(self.basePlaybackTime)s")
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        Task {
            do {
                try await musicService.togglePlayPause()
                // Reset animation base when state changes
                updateBasePlaybackTime()
            } catch {
                B2BLog.playback.error("❌ NowPlayingViewModel.togglePlayPause: \(error.localizedDescription)")
            }
        }
    }

    func skipToNext() {
        Task {
            do {
                try await musicService.skipToNext()
                // Reset animation base for new song
                updateBasePlaybackTime()
            } catch {
                B2BLog.playback.warning("Failed to skip to next song")
            }
        }
    }

    func skipToPrevious() {
        Task {
            do {
                try await musicService.skipToPrevious()
                // Reset animation base for new song
                updateBasePlaybackTime()
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
                // Update base time to the new seek position
                basePlaybackTime = time
                animationStartTime = Date()
                B2BLog.playback.debug("Seeked to \(time)s, reset animation base")
            } catch {
                B2BLog.playback.error("❌ Seek failed: \(error.localizedDescription)")
            }
        }
    }

    func skipForward() {
        Task {
            do {
                try await musicService.skipForward(15)
                // Reset animation base after skip
                updateBasePlaybackTime()
            } catch {
                B2BLog.playback.error("❌ Skip forward failed: \(error.localizedDescription)")
            }
        }
    }

    func skipBackward() {
        Task {
            do {
                try await musicService.skipBackward(15)
                // Reset animation base after skip
                updateBasePlaybackTime()
            } catch {
                B2BLog.playback.error("❌ Skip backward failed: \(error.localizedDescription)")
            }
        }
    }
}
