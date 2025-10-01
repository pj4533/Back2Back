//
//  QueueManager.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionService as part of Phase 3 refactoring (#23)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Manages the song queue for the session
@MainActor
@Observable
final class QueueManager {
    private(set) var songQueue: [SessionSong] = []

    // MARK: - Queue Operations

    /// Add a song to the queue
    func queueSong(_ song: Song, selectedBy: TurnType, rationale: String? = nil, queueStatus: QueueStatus) -> SessionSong {
        let sessionSong = SessionSong(
            id: UUID(),
            song: song,
            selectedBy: selectedBy,
            timestamp: Date(),
            rationale: rationale,
            queueStatus: queueStatus
        )
        songQueue.append(sessionSong)
        B2BLog.session.info("Queued song: \(song.title) - Status: \(queueStatus)")
        return sessionSong
    }

    /// Get the next queued song based on priority
    func getNextQueuedSong() -> SessionSong? {
        // First priority: songs marked as "upNext" (user → AI transition)
        if let upNext = songQueue.first(where: { $0.queueStatus == .upNext }) {
            return upNext
        }
        // Second priority: AI continuation songs (AI → AI transition)
        if let aiContinuation = songQueue.first(where: { $0.queueStatus == .queuedIfUserSkips }) {
            return aiContinuation
        }
        return nil
    }

    /// Clear all AI queued songs
    func clearAIQueuedSongs() {
        songQueue.removeAll { $0.selectedBy == .ai }
        B2BLog.session.info("Cleared AI queued songs")
    }

    /// Remove all songs before a specific song in the queue
    func removeQueuedSongsBeforeSong(_ songId: UUID) {
        // Find the index of the target song
        if let targetIndex = songQueue.firstIndex(where: { $0.id == songId }) {
            // Remove all songs before this index
            let removedSongs = songQueue.prefix(targetIndex)
            songQueue.removeFirst(targetIndex)
            B2BLog.session.info("Removed \(removedSongs.count) songs from queue (skipped ahead)")
            for song in removedSongs {
                B2BLog.session.debug("  Skipped: \(song.song.title) by \(song.song.artistName)")
            }
        }
    }

    /// Remove a song from the queue
    func removeSong(withId songId: UUID) -> SessionSong? {
        if let index = songQueue.firstIndex(where: { $0.id == songId }) {
            let song = songQueue.remove(at: index)
            B2BLog.session.info("Removed song from queue: \(song.song.title)")
            return song
        }
        return nil
    }

    /// Update song status in the queue
    func updateSongStatus(id: UUID, newStatus: QueueStatus) {
        if let index = songQueue.firstIndex(where: { $0.id == id }) {
            songQueue[index].queueStatus = newStatus
            B2BLog.session.debug("Updated song status in queue: \(self.songQueue[index].song.title) to \(newStatus)")
        }
    }

    /// Clear all songs from the queue
    func clearQueue() {
        songQueue.removeAll()
        B2BLog.session.info("Cleared song queue")
    }

    /// Check if a song exists in the queue
    func containsSong(withId songId: UUID) -> Bool {
        songQueue.contains { $0.id == songId }
    }

    /// Get song from queue by ID
    func getSong(withId songId: UUID) -> SessionSong? {
        songQueue.first { $0.id == songId }
    }
}
