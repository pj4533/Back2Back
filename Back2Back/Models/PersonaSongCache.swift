//
//  PersonaSongCache.swift
//  Back2Back
//
//  Created on 2025-09-30.
//

import Foundation

/// Represents a single song that was recently selected by a persona
struct CachedSong: Codable, Equatable {
    let artist: String
    let songTitle: String
    let selectedAt: Date  // Used for ordering in LRU cache
}

/// Stores the cache of recently selected songs for a specific persona using LRU (Least Recently Used) eviction
struct PersonaSongCache: Codable {
    let personaId: UUID
    var songs: [CachedSong]

    /// Adds a song to the cache with LRU eviction
    /// When the cache reaches maxSize, the oldest song is automatically removed
    /// - Parameters:
    ///   - song: The song to add to the cache
    ///   - maxSize: The maximum number of songs to keep in the cache
    mutating func addSong(_ song: CachedSong, maxSize: Int) {
        songs.append(song)
        if songs.count > maxSize {
            songs.removeFirst()  // Remove oldest (FIFO for LRU)
        }
    }
}
