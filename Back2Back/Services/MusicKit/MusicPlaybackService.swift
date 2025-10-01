//
//  MusicPlaybackService.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from MusicService as part of Phase 3 refactoring (#23)
//

import Foundation
import MusicKit
import Combine
import Observation
import OSLog

/// Handles Apple Music playback control
@MainActor
@Observable
final class MusicPlaybackService {
    var currentlyPlaying: NowPlayingItem?
    var playbackState: ApplicationMusicPlayer.PlaybackStatus = .stopped
    var currentSongId: String? = nil

    private let player = ApplicationMusicPlayer.shared
    private let queueSync = QueueSynchronizationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastLoggedSongId: String?

    init() {
        B2BLog.musicKit.debug("Initializing MusicPlaybackService")
        setupPlaybackObservers()
    }

    // MARK: - Playback Observers

    private func setupPlaybackObservers() {
        player.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
    }

    private func updatePlaybackState() {
        let oldState = playbackState
        playbackState = player.state.playbackStatus

        if oldState != playbackState {
            B2BLog.playback.info("🔄 State: \(String(describing: oldState)) → \(String(describing: self.playbackState))")

            // Log additional context when state changes
            B2BLog.playback.debug("🔍 State change context:")
            B2BLog.playback.debug("  - Queue entries: \(self.player.queue.entries.count)")
            B2BLog.playback.debug("  - Current entry exists: \(self.player.queue.currentEntry != nil)")
            B2BLog.playback.debug("  - Playback time: \(self.player.playbackTime)s")

            // Check if this is an unexpected pause or stop
            if playbackState == .paused && oldState == .playing {
                B2BLog.playback.warning("⚠️ Unexpected pause detected - was playing, now paused")
            } else if playbackState == .stopped && oldState == .playing {
                B2BLog.playback.warning("⚠️ Unexpected stop detected - was playing, now stopped")
            }
        }

        if let currentEntry = player.queue.currentEntry {
            Task {
                switch currentEntry.item {
                case .song(let song):
                    currentlyPlaying = NowPlayingItem(
                        song: song,
                        isPlaying: player.state.playbackStatus == .playing,
                        playbackTime: player.playbackTime,
                        duration: song.duration ?? 0
                    )
                    // Track the current song ID for external observers
                    let newSongId = song.id.rawValue
                    if newSongId != currentSongId {
                        currentSongId = newSongId
                    }
                    // Only log when the song actually changes, not on every state update
                    if song.id.rawValue != lastLoggedSongId {
                        B2BLog.playback.info("🎵 Now playing: \(song.title) by \(song.artistName)")
                        lastLoggedSongId = song.id.rawValue
                    }
                default:
                    currentlyPlaying = nil
                    if lastLoggedSongId != nil {
                        B2BLog.playback.debug("Current queue entry is not a song")
                        lastLoggedSongId = nil
                    }
                }
            }
        } else {
            currentlyPlaying = nil
            currentSongId = nil
            lastLoggedSongId = nil
        }
    }

    // MARK: - Playback Control

    /// Start playback with a song (used for first song or when queue is empty)
    /// Delegates to QueueSynchronizationService for queue management
    func startPlayback(with song: Song) async throws {
        B2BLog.playback.info("👤 Start playback: \(song.title)")
        B2BLog.playback.debug("   Song ID: \(song.id.rawValue)")

        do {
            // Delegate to QueueSynchronizationService
            try await queueSync.addToQueue(song)
            B2BLog.playback.info("✅ Started playback: \(song.title) by \(song.artistName)")
        } catch {
            let playbackError = MusicPlaybackError.playbackFailed(error)
            B2BLog.playback.error("❌ startPlayback: \(playbackError.localizedDescription)")
            B2BLog.playback.error("   Error details: \(error)")
            throw playbackError
        }
    }

    /// Add a song to the playback queue (used for subsequent songs)
    /// Delegates to QueueSynchronizationService for queue management
    func queueNextSong(_ song: Song) async throws {
        B2BLog.playback.info("➕ Queue next song: \(song.title)")

        do {
            // Delegate to QueueSynchronizationService
            try await queueSync.addToQueue(song)
            B2BLog.playback.info("✅ Queued next song: \(song.title)")
        } catch {
            let queueError = MusicPlaybackError.queueFailed
            B2BLog.playback.error("❌ queueNextSong: \(queueError.localizedDescription)")
            throw queueError
        }
    }

    /// Play a specific song (backward compatibility wrapper)
    /// Uses startPlayback internally
    @available(*, deprecated, message: "Use startPlayback(with:) or queueNextSong(_:) instead")
    func playSong(_ song: Song) async throws {
        try await startPlayback(with: song)
    }

    /// Toggle play/pause
    func togglePlayPause() async throws {
        if player.state.playbackStatus == .playing {
            B2BLog.playback.info("👤 Pause playback")
            player.pause()
        } else {
            B2BLog.playback.info("👤 Resume playback")
            try await player.play()
        }
    }

    /// Skip to next song in queue
    func skipToNext() async throws {
        B2BLog.playback.info("👤 Skip to next")
        try await player.skipToNextEntry()
    }

    /// Skip to previous song in queue
    func skipToPrevious() async throws {
        B2BLog.playback.info("👤 Skip to previous")
        try await player.skipToPreviousEntry()
    }

    /// Clear the playback queue
    func clearQueue() {
        B2BLog.playback.info("🗑️ Clearing playback queue")
        player.queue = ApplicationMusicPlayer.Queue()
    }

    /// Get current playback time
    func getCurrentPlaybackTime() -> TimeInterval {
        // Return the current real-time playback position
        return player.playbackTime
    }

    // MARK: - Seek Controls

    /// Seek to a specific time position in the current track
    func seek(to time: TimeInterval) async throws {
        B2BLog.playback.info("⏩ Seeking to \(time)s")

        guard let _ = player.queue.currentEntry else {
            B2BLog.playback.warning("Cannot seek - no current entry")
            throw MusicPlaybackError.queueFailed
        }

        // Clamp time to valid range
        let clampedTime = max(0, min(time, currentDuration))
        player.playbackTime = clampedTime

        B2BLog.playback.debug("✅ Seeked to \(clampedTime)s")
    }

    /// Skip forward by a specified number of seconds (default: 15s)
    func skipForward(_ seconds: TimeInterval = 15) async throws {
        B2BLog.playback.info("⏭️ Skip forward \(seconds)s")

        guard let _ = player.queue.currentEntry else {
            B2BLog.playback.warning("Cannot skip forward - no current entry")
            throw MusicPlaybackError.queueFailed
        }

        let newTime = min(player.playbackTime + seconds, currentDuration)
        player.playbackTime = newTime

        B2BLog.playback.debug("✅ Skipped forward to \(newTime)s")
    }

    /// Skip backward by a specified number of seconds (default: 15s)
    func skipBackward(_ seconds: TimeInterval = 15) async throws {
        B2BLog.playback.info("⏮️ Skip backward \(seconds)s")

        guard let _ = player.queue.currentEntry else {
            B2BLog.playback.warning("Cannot skip backward - no current entry")
            throw MusicPlaybackError.queueFailed
        }

        let newTime = max(player.playbackTime - seconds, 0)
        player.playbackTime = newTime

        B2BLog.playback.debug("✅ Skipped backward to \(newTime)s")
    }

    // MARK: - Private Helpers

    /// Get the duration of the current track
    private var currentDuration: TimeInterval {
        guard let currentEntry = player.queue.currentEntry,
              case .song(let song) = currentEntry.item,
              let duration = song.duration else {
            return 0
        }
        return duration
    }
}
