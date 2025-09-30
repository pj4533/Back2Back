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
    let selectedAt: Date

    /// Returns true if this song was selected more than 24 hours ago
    var isExpired: Bool {
        Date().timeIntervalSince(selectedAt) > 24 * 60 * 60 // 24 hours in seconds
    }
}

/// Stores the cache of recently selected songs for a specific persona
struct PersonaSongCache: Codable {
    let personaId: UUID
    var songs: [CachedSong]

    /// Returns only songs that have not expired (selected within last 24 hours)
    var activeSongs: [CachedSong] {
        songs.filter { !$0.isExpired }
    }

    /// Removes all expired songs from the cache
    mutating func removeExpiredSongs() {
        songs.removeAll { $0.isExpired }
    }
}
