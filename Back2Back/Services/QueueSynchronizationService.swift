//
//  QueueSynchronizationService.swift
//  Back2Back
//
//  Created on 2025-10-01.
//  Implements native MusicKit queue progression (#33)
//

import Foundation
import MusicKit
import Combine
import Observation
import OSLog

/// Synchronizes SessionService queue with MusicKit's ApplicationMusicPlayer queue.
/// Observes native queue progression instead of polling playback time.
@MainActor
@Observable
final class QueueSynchronizationService {
    static let shared = QueueSynchronizationService()

    private let player = ApplicationMusicPlayer.shared
    private let sessionService = SessionService.shared

    private var queueObserver: AnyCancellable?
    private var currentEntryObserver: AnyCancellable?
    private var lastObservedSongId: String?

    // Callback for when MusicKit automatically advances to next song
    var onSongAdvanced: (() async -> Void)?

    // Track entries we've added to MusicKit queue (for removal operations)
    private var queuedSongIds: [String] = []

    private init() {
        B2BLog.playback.info("QueueSynchronizationService initialized")
        setupQueueObserver()
    }

    // MARK: - Queue Observer

    /// Setup observer for MusicKit queue changes
    private func setupQueueObserver() {
        // Observe queue changes to detect when MusicKit advances
        queueObserver = player.queue.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleQueueChanged()
                }
            }

        B2BLog.playback.debug("✅ Queue observer setup complete")
    }

    /// Handle when MusicKit queue changes (song advanced)
    private func handleQueueChanged() async {
        guard let currentEntry = player.queue.currentEntry else {
            B2BLog.playback.debug("Queue changed but no current entry")
            return
        }

        // Don't process transient items
        guard !currentEntry.isTransient else {
            B2BLog.playback.debug("Current entry is transient, waiting for resolution")
            return
        }

        // Extract song from current entry
        guard case .song(let song) = currentEntry.item else {
            B2BLog.playback.debug("Current entry is not a song")
            return
        }

        let currentSongId = song.id.rawValue

        // Check if this is a new song (queue advanced)
        if currentSongId != lastObservedSongId {
            B2BLog.playback.info("🎵 MusicKit queue advanced to: \(song.title) by \(song.artistName)")
            B2BLog.playback.debug("   Previous song ID: \(self.lastObservedSongId ?? "none")")
            B2BLog.playback.debug("   Current song ID: \(currentSongId)")

            lastObservedSongId = currentSongId

            // Update SessionService to reflect the song now playing
            sessionService.updateCurrentlyPlayingSong(songId: currentSongId)

            // Notify callback that song advanced
            await onSongAdvanced?()
        }
    }

    // MARK: - Queue Management

    /// Add song to MusicKit queue (first song initializes queue, subsequent songs append)
    func addToQueue(_ song: Song) async throws {
        B2BLog.playback.info("➕ Adding to MusicKit queue: \(song.title)")
        B2BLog.playback.debug("   Current queue entries: \(self.player.queue.entries.count)")

        if player.queue.entries.isEmpty {
            // First song - initialize queue
            B2BLog.playback.debug("   Initializing queue with first song")
            player.queue = ApplicationMusicPlayer.Queue(for: [song])

            // Prepare and play
            try await player.prepareToPlay()
            try await player.play()

            B2BLog.playback.info("✅ Started playback with: \(song.title)")

            // Track this song ID
            queuedSongIds.append(song.id.rawValue)
            lastObservedSongId = song.id.rawValue
        } else {
            // Add to tail of existing queue
            B2BLog.playback.debug("   Adding to tail of existing queue")
            try await player.queue.insert(song, position: .tail)

            // Wait for transient state to resolve (with timeout)
            try await waitForTransientResolution()

            B2BLog.playback.info("✅ Added to queue: \(song.title)")
            B2BLog.playback.debug("   Queue entries now: \(self.player.queue.entries.count)")

            // Track this song ID
            queuedSongIds.append(song.id.rawValue)
        }
    }

    /// Remove a specific song from MusicKit queue by song ID
    func removeSong(withId songId: String) async throws {
        B2BLog.playback.info("🗑️ Removing song from MusicKit queue: \(songId)")

        // Find the index of the entry with this song ID
        guard let index = findSongIndex(songId) else {
            B2BLog.playback.warning("⚠️ Song not found in MusicKit queue: \(songId)")
            return
        }

        B2BLog.playback.debug("   Found song at index: \(index)")

        // Remove from MusicKit queue
        // Note: MusicKit doesn't have a direct remove API, so we need to rebuild the queue
        // This is safe because we're only removing songs that haven't played yet
        let entriesToKeep = player.queue.entries.enumerated().compactMap { i, entry -> Song? in
            guard i != index,
                  case .song(let song) = entry.item,
                  !entry.isTransient else {
                return nil
            }
            return song
        }

        // Only rebuild if we're removing from queue (not currently playing)
        if index > 0 {
            B2BLog.playback.debug("   Rebuilding queue without removed song")

            // Get currently playing song
            if case .song(let currentSong) = player.queue.currentEntry?.item {
                // Rebuild queue: current song + remaining songs
                var newQueue = [currentSong]
                newQueue.append(contentsOf: entriesToKeep.filter { $0.id != currentSong.id })

                player.queue = ApplicationMusicPlayer.Queue(for: newQueue)
                try await player.prepareToPlay()
            }
        }

        // Remove from tracking
        queuedSongIds.removeAll { $0 == songId }

        B2BLog.playback.info("✅ Removed song from queue")
        B2BLog.playback.debug("   Queue entries now: \(self.player.queue.entries.count)")
    }

    /// Remove all AI-queued songs from MusicKit queue
    func removeAISongs() async throws {
        B2BLog.playback.info("🗑️ Removing all AI songs from MusicKit queue")

        // Get AI song IDs from SessionService queue
        let aiSongIds = sessionService.songQueue
            .filter { $0.selectedBy == .ai }
            .map { $0.song.id.rawValue }

        B2BLog.playback.debug("   Found \(aiSongIds.count) AI songs to remove")

        // Remove each AI song
        for songId in aiSongIds {
            try await removeSong(withId: songId)
        }

        B2BLog.playback.info("✅ Removed all AI songs from queue")
    }

    /// Find the index of a song in MusicKit queue by song ID
    func findSongIndex(_ songId: String) -> Int? {
        for (index, entry) in player.queue.entries.enumerated() {
            if case .song(let song) = entry.item,
               song.id.rawValue == songId {
                return index
            }
        }
        return nil
    }

    /// Skip to a specific entry in the queue
    func skipToEntry(at index: Int) async throws {
        B2BLog.playback.info("⏩ Skipping to entry at index: \(index)")

        guard index < player.queue.entries.count else {
            B2BLog.playback.error("❌ Invalid queue index: \(index)")
            throw MusicPlaybackError.queueFailed
        }

        // MusicKit doesn't have skipToEntry(at:), so we need to skip multiple times
        let currentIndex = player.queue.entries.firstIndex(where: { entry in
            guard let currentEntry = player.queue.currentEntry else { return false }
            return entry.id == currentEntry.id
        }) ?? 0

        let skipsNeeded = index - currentIndex

        if skipsNeeded > 0 {
            B2BLog.playback.debug("   Skipping forward \(skipsNeeded) times")
            for _ in 0..<skipsNeeded {
                try await player.skipToNextEntry()
            }
        } else if skipsNeeded < 0 {
            B2BLog.playback.debug("   Skipping backward \(abs(skipsNeeded)) times")
            for _ in 0..<abs(skipsNeeded) {
                try await player.skipToPreviousEntry()
            }
        }

        B2BLog.playback.info("✅ Skipped to entry at index: \(index)")
    }

    // MARK: - Private Helpers

    /// Wait for transient item to resolve (with timeout)
    private func waitForTransientResolution() async throws {
        var attempts = 0
        let maxAttempts = 50 // 5 seconds total (50 * 0.1s)

        while attempts < maxAttempts {
            // Check if last entry is still transient
            guard let lastEntry = player.queue.entries.last,
                  lastEntry.isTransient else {
                // Resolved!
                B2BLog.playback.debug("✅ Transient item resolved after \(attempts) attempts")
                return
            }

            // Wait 0.1s and try again
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        // Timeout - still transient after 5 seconds
        B2BLog.playback.error("❌ Transient item failed to resolve after 5 seconds")
        throw MusicPlaybackError.queueFailed
    }

    /// Reset all state (for testing or session reset)
    func reset() {
        B2BLog.playback.info("🔄 Resetting QueueSynchronizationService state")
        lastObservedSongId = nil
        queuedSongIds.removeAll()
    }
}
