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

    /// Play a specific song
    func playSong(_ song: Song) async throws {
        B2BLog.playback.info("👤 Play song: \(song.title)")
        B2BLog.playback.debug("   Song ID: \(song.id.rawValue)")
        B2BLog.playback.debug("   Song contentRating: \(String(describing: song.contentRating))")

        do {
            // Log current state before any changes
            let beforeState = player.state.playbackStatus
            let beforeQueueCount = player.queue.entries.count
            B2BLog.playback.debug("📝 BEFORE setQueue:")
            B2BLog.playback.debug("   - Player state: \(String(describing: beforeState))")
            B2BLog.playback.debug("   - Queue entries: \(beforeQueueCount)")

            // Create queue and set it
            let setQueueStartTime = Date()
            player.queue = ApplicationMusicPlayer.Queue(for: [song])
            let setQueueDuration = Date().timeIntervalSince(setQueueStartTime)
            B2BLog.playback.debug("⏱️ setQueue completed in \(setQueueDuration)s")

            // Check queue state immediately after setQueue
            let afterSetQueueCount = player.queue.entries.count
            let afterSetQueueHasEntry = player.queue.currentEntry != nil
            B2BLog.playback.debug("📝 IMMEDIATELY after setQueue:")
            B2BLog.playback.debug("   - Queue entries: \(afterSetQueueCount)")
            B2BLog.playback.debug("   - Has current entry: \(afterSetQueueHasEntry)")

            // CRITICAL: Use prepareToPlay() to ensure the queue is ready before calling play()
            // This is an async operation that loads and prepares the media
            B2BLog.playback.debug("⏱️ Calling prepareToPlay()...")
            let prepareStartTime = Date()
            try await player.prepareToPlay()
            let prepareDuration = Date().timeIntervalSince(prepareStartTime)
            B2BLog.playback.debug("⏱️ prepareToPlay() completed in \(prepareDuration)s")

            // Check queue state after prepareToPlay
            let afterPrepareCount = player.queue.entries.count
            let afterPrepareHasEntry = player.queue.currentEntry != nil
            let afterPrepareState = player.state.playbackStatus
            B2BLog.playback.debug("📝 AFTER prepareToPlay():")
            B2BLog.playback.debug("   - Player state: \(String(describing: afterPrepareState))")
            B2BLog.playback.debug("   - Queue entries: \(afterPrepareCount)")
            B2BLog.playback.debug("   - Has current entry: \(afterPrepareHasEntry)")

            // Verify queue is actually ready
            guard player.queue.entries.count > 0 else {
                B2BLog.playback.error("❌ Queue still empty after prepareToPlay() - song may not be available")
                B2BLog.playback.error("   Song details: \(song.title) by \(song.artistName)")
                B2BLog.playback.error("   Song ID: \(song.id.rawValue)")
                throw MusicPlaybackError.queueFailed
            }

            // Now call play()
            B2BLog.playback.debug("⏱️ Calling play()...")
            let playStartTime = Date()
            try await player.play()
            let playDuration = Date().timeIntervalSince(playStartTime)
            B2BLog.playback.debug("⏱️ play() completed in \(playDuration)s")

            // Log final state
            let finalState = player.state.playbackStatus
            B2BLog.playback.debug("📝 AFTER play():")
            B2BLog.playback.debug("   - Player state: \(String(describing: finalState))")

            B2BLog.playback.info("✅ Started playback: \(song.title) by \(song.artistName)")
        } catch {
            let playbackError = MusicPlaybackError.playbackFailed(error)
            B2BLog.playback.error("❌ playSong: \(playbackError.localizedDescription)")
            B2BLog.playback.error("   Error details: \(error)")
            throw playbackError
        }
    }

    /// Add a song to the playback queue
    func addToQueue(_ song: Song) async throws {
        B2BLog.playback.info("➕ Adding to queue: \(song.title)")

        do {
            try await player.queue.insert(song, position: .tail)
            B2BLog.playback.info("✅ Added to queue: \(song.title)")
        } catch {
            let queueError = MusicPlaybackError.queueFailed
            B2BLog.playback.error("❌ addToQueue: \(queueError.localizedDescription)")
            throw queueError
        }
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
}
