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
import Combine
import OSLog

/// Coordinates playback monitoring and song transition detection
@MainActor
@Observable
final class PlaybackCoordinator {
    private let musicService = MusicService.shared
    private let sessionService = SessionService.shared

    private var playbackObserverTask: Task<Void, Never>?
    private var stateSubscription: AnyCancellable?
    private var lastPlaybackTime: TimeInterval = 0
    private var lastSongId: String? = nil
    private var hasTriggeredEndOfSong: Bool = false

    // Callback for when a song ends and we need to advance
    var onSongEnded: (() async -> Void)?

    init() {
        B2BLog.session.debug("PlaybackCoordinator initialized")
        startPlaybackMonitoring()
        setupStateObserver()
    }

    nonisolated deinit {
        // Tasks and subscriptions will be cancelled automatically
    }

    // MARK: - Public Methods

    /// Manually stop playback monitoring (for testing or cleanup)
    func stopMonitoring() {
        playbackObserverTask?.cancel()
        playbackObserverTask = nil
        stateSubscription?.cancel()
        stateSubscription = nil
    }

    // MARK: - Playback Monitoring

    /// Subscribe to ApplicationMusicPlayer state changes for reactive updates
    private func setupStateObserver() {
        // Observe player state changes to detect song transitions more efficiently
        stateSubscription = ApplicationMusicPlayer.shared.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleStateChange()
                }
            }
        B2BLog.playback.debug("Subscribed to ApplicationMusicPlayer state changes")
    }

    /// Handle player state changes from Combine publisher
    private func handleStateChange() async {
        // Quick check for song transitions when state changes
        if let nowPlaying = musicService.currentlyPlaying {
            let currentSongId = nowPlaying.song.id.rawValue
            if currentSongId != lastSongId {
                B2BLog.playback.info("🎵 Song transition detected via state observer: \(nowPlaying.song.title)")
                lastSongId = currentSongId
                hasTriggeredEndOfSong = false
                sessionService.updateCurrentlyPlayingSong(songId: currentSongId)
            }
        }
    }

    private func startPlaybackMonitoring() {
        playbackObserverTask = Task { [weak self] in
            guard let self = self else { return }

            B2BLog.playback.debug("Starting playback monitoring")

            // Reduced timer frequency: check every 0.5s instead of 1s for better responsiveness
            while !Task.isCancelled {
                await self.checkPlaybackState()
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
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
