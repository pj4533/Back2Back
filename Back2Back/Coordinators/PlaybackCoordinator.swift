//
//  PlaybackCoordinator.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionViewModel as part of Phase 1 refactoring (#20)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Coordinates playback monitoring and song transition detection
@MainActor
@Observable
final class PlaybackCoordinator {
    private let musicService = MusicService.shared
    private let sessionService = SessionService.shared

    private var playbackObserverTask: Task<Void, Never>?
    private var lastPlaybackTime: TimeInterval = 0
    private var lastSongId: String? = nil
    private var hasTriggeredEndOfSong: Bool = false

    // Callback for when a song ends and we need to advance
    var onSongEnded: (() async -> Void)?

    init() {
        B2BLog.session.debug("PlaybackCoordinator initialized")
        startPlaybackMonitoring()
    }

    nonisolated deinit {
        // Tasks will be cancelled automatically
    }

    // MARK: - Public Methods

    /// Manually stop playback monitoring (for testing or cleanup)
    func stopMonitoring() {
        playbackObserverTask?.cancel()
        playbackObserverTask = nil
    }

    // MARK: - Playback Monitoring

    private func startPlaybackMonitoring() {
        playbackObserverTask = Task { [weak self] in
            guard let self = self else { return }

            B2BLog.playback.debug("Starting playback monitoring")

            // Create a timer that checks playback state periodically
            while !Task.isCancelled {
                await self.checkPlaybackState()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }

    private func checkPlaybackState() async {
        // Monitor the MusicService's currentlyPlaying state
        if let nowPlaying = musicService.currentlyPlaying {
            let currentSongId = nowPlaying.song.id.rawValue
            // Get real-time playback position directly from the player
            let currentPlaybackTime = musicService.getCurrentPlaybackTime()
            let progress = nowPlaying.duration > 0 ? (currentPlaybackTime / nowPlaying.duration) : 0

            // Check if this is a new song
            if currentSongId != lastSongId {
                B2BLog.playback.info("🎵 New song detected: \(nowPlaying.song.title)")
                lastSongId = currentSongId
                hasTriggeredEndOfSong = false
                lastPlaybackTime = currentPlaybackTime

                // CRITICAL: Update the queue status to show this song is now playing
                sessionService.updateCurrentlyPlayingSong(songId: currentSongId)

                return
            }

            // Log current state for debugging (less frequently)
            if Int(currentPlaybackTime) % 10 == 0 && Int(currentPlaybackTime) != Int(lastPlaybackTime) {
                B2BLog.playback.trace("Playback - \(nowPlaying.song.title): \(Int(currentPlaybackTime))s/\(Int(nowPlaying.duration))s (\(Int(progress * 100))%)")
            }

            // Detailed logging when approaching song end
            if progress >= 0.90 && progress < 0.99 {
                B2BLog.playback.debug("📊 Near song end: \(nowPlaying.song.title) - Progress: \(String(format: "%.1f%%", progress * 100)) (\(Int(currentPlaybackTime))s/\(Int(nowPlaying.duration))s)")
                B2BLog.playback.debug("  - hasTriggeredEndOfSong: \(self.hasTriggeredEndOfSong)")
                B2BLog.playback.debug("  - Playback state: \(String(describing: self.musicService.playbackState))")
                B2BLog.playback.debug("  - Is playing: \(nowPlaying.isPlaying)")
            }

            // Check if song has ended (100% complete or very close) and we haven't triggered yet
            // Lower threshold to 97% to catch songs that might not reach exactly 99%
            if progress >= 0.97 && !hasTriggeredEndOfSong && nowPlaying.duration > 0 {
                B2BLog.playback.info("🎵 Song ending detected at \(String(format: "%.1f%%", progress * 100)) - advancing to next song")
                hasTriggeredEndOfSong = true
                B2BLog.playback.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

                // Mark current song as played before transitioning
                sessionService.markCurrentSongAsPlayed()

                // Notify delegate to advance to next queued song
                await onSongEnded?()
            }

            lastPlaybackTime = currentPlaybackTime

        } else if lastSongId != nil {
            // Was playing but now nothing - song ended or playback stopped
            B2BLog.playback.debug("🔍 No current playback detected (lastSongId: \(self.lastSongId ?? "nil"), hasTriggeredEndOfSong: \(self.hasTriggeredEndOfSong))")

            if !hasTriggeredEndOfSong {
                B2BLog.playback.info("⏹️ Playback stopped or ended unexpectedly, advancing queue")
                B2BLog.playback.debug("Queue state - History: \(self.sessionService.sessionHistory.count), Queue: \(self.sessionService.songQueue.count)")

                hasTriggeredEndOfSong = true

                // Mark current song as played before transitioning
                sessionService.markCurrentSongAsPlayed()

                // Notify delegate to advance queue
                await onSongEnded?()
            }

            lastSongId = nil
            lastPlaybackTime = 0
        }
    }
}
