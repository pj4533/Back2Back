//
//  PersonaSongCacheService.swift
//  Back2Back
//
//  Created on 2025-09-30.
//

import Foundation
import OSLog

@MainActor
final class PersonaSongCacheService {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "com.back2back.personaSongCache"
    private var caches: [UUID: PersonaSongCache] = [:]

    init() {
        B2BLog.ai.info("PersonaSongCacheService initialized")
        loadCaches()
        cleanupExpiredSongs()
    }

    // MARK: - Public API

    /// Records a song selection for a specific persona
    func recordSong(personaId: UUID, artist: String, songTitle: String) {
        let cachedSong = CachedSong(
            artist: artist,
            songTitle: songTitle,
            selectedAt: Date()
        )

        if var cache = caches[personaId] {
            // Add to existing cache
            cache.songs.append(cachedSong)
            caches[personaId] = cache
            B2BLog.ai.info("Cached song for persona: '\(songTitle)' by '\(artist)'")
            B2BLog.ai.debug("Cache now has \(cache.songs.count) songs for persona \(personaId)")
        } else {
            // Create new cache for this persona
            let newCache = PersonaSongCache(personaId: personaId, songs: [cachedSong])
            caches[personaId] = newCache
            B2BLog.ai.info("Created new cache for persona \(personaId) with song: '\(songTitle)' by '\(artist)'")
        }

        saveCaches()
    }

    /// Returns all recent (non-expired) songs for a specific persona
    func getRecentSongs(for personaId: UUID) -> [CachedSong] {
        guard let cache = caches[personaId] else {
            B2BLog.ai.debug("No cache found for persona \(personaId)")
            return []
        }

        let recentSongs = cache.activeSongs
        B2BLog.ai.debug("Found \(recentSongs.count) recent songs for persona \(personaId)")
        return recentSongs
    }

    /// Removes all expired songs from all caches
    func clearExpiredSongs() {
        B2BLog.ai.info("Clearing expired songs from all persona caches")
        var removedCount = 0

        for (personaId, var cache) in caches {
            let beforeCount = cache.songs.count
            cache.removeExpiredSongs()
            let afterCount = cache.songs.count

            caches[personaId] = cache
            removedCount += (beforeCount - afterCount)
        }

        if removedCount > 0 {
            B2BLog.ai.info("Removed \(removedCount) expired songs from caches")
            saveCaches()
        } else {
            B2BLog.ai.debug("No expired songs to remove")
        }
    }

    /// Clears all cached songs for a specific persona
    func clearCache(for personaId: UUID) {
        if caches[personaId] != nil {
            caches.removeValue(forKey: personaId)
            saveCaches()
            B2BLog.ai.info("Cleared cache for persona \(personaId)")
        }
    }

    /// Clears all caches for all personas (for testing/debugging)
    func clearAllCaches() {
        caches.removeAll()
        saveCaches()
        B2BLog.ai.warning("Cleared all persona song caches")
    }

    // MARK: - Private Methods

    private func loadCaches() {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            B2BLog.ai.debug("No saved persona song caches found")
            return
        }

        do {
            let decodedCaches = try JSONDecoder().decode([PersonaSongCache].self, from: data)
            caches = Dictionary(uniqueKeysWithValues: decodedCaches.map { ($0.personaId, $0) })
            B2BLog.ai.info("Loaded \(self.caches.count) persona song caches")

            let totalSongs = self.caches.values.reduce(0) { $0 + $1.songs.count }
            B2BLog.ai.debug("Total cached songs: \(totalSongs)")
        } catch {
            B2BLog.ai.error("Failed to load persona song caches: \(error)")
        }
    }

    private func saveCaches() {
        let cachesArray = Array(caches.values)

        do {
            let encoded = try JSONEncoder().encode(cachesArray)
            userDefaults.set(encoded, forKey: cacheKey)
            B2BLog.ai.debug("Saved \(cachesArray.count) persona song caches")
        } catch {
            B2BLog.ai.error("Failed to save persona song caches: \(error)")
        }
    }

    private func cleanupExpiredSongs() {
        clearExpiredSongs()
    }
}
