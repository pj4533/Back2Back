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
    private let cacheSizeKey = "com.back2back.personaSongCacheSize"
    private var caches: [UUID: PersonaSongCache] = [:]

    /// Current cache size limit per persona
    private var cacheSize: Int {
        let size = userDefaults.integer(forKey: cacheSizeKey)
        return size > 0 ? size : 50  // Default to 50 if not set
    }

    init() {
        B2BLog.ai.info("PersonaSongCacheService initialized with LRU cache (size: \(self.cacheSize))")
        loadCaches()
    }

    // MARK: - Public API

    /// Records a song selection for a specific persona using LRU eviction
    func recordSong(personaId: UUID, artist: String, songTitle: String) {
        let cachedSong = CachedSong(
            artist: artist,
            songTitle: songTitle,
            selectedAt: Date()
        )

        if var cache = caches[personaId] {
            // Add to existing cache with LRU eviction
            let beforeCount = cache.songs.count
            cache.addSong(cachedSong, maxSize: cacheSize)
            caches[personaId] = cache

            if cache.songs.count < beforeCount + 1 {
                B2BLog.ai.debug("Evicted oldest song from cache (LRU)")
            }

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

    /// Returns all recent songs for a specific persona (up to cache size limit)
    func getRecentSongs(for personaId: UUID) -> [CachedSong] {
        guard let cache = caches[personaId] else {
            B2BLog.ai.debug("No cache found for persona \(personaId)")
            return []
        }

        B2BLog.ai.debug("Found \(cache.songs.count) recent songs for persona \(personaId)")
        return cache.songs
    }

    /// Removes a specific song from a persona's cache
    func removeSong(personaId: UUID, artist: String, songTitle: String) {
        guard var cache = caches[personaId] else {
            B2BLog.ai.debug("No cache found for persona \(personaId), cannot remove song")
            return
        }

        let beforeCount = cache.songs.count
        cache.songs.removeAll { song in
            song.artist == artist && song.songTitle == songTitle
        }

        if cache.songs.count < beforeCount {
            caches[personaId] = cache
            saveCaches()
            B2BLog.ai.info("Removed song from cache: '\(songTitle)' by '\(artist)' (persona: \(personaId))")
            B2BLog.ai.debug("Cache now has \(cache.songs.count) songs for persona \(personaId)")
        } else {
            B2BLog.ai.debug("Song not found in cache: '\(songTitle)' by '\(artist)' (persona: \(personaId))")
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

            // Migration: Trim caches to new size limit on first load
            let currentCacheSize = cacheSize
            var trimmed = false
            for (personaId, var cache) in caches {
                if cache.songs.count > currentCacheSize {
                    cache.songs = Array(cache.songs.suffix(currentCacheSize))
                    caches[personaId] = cache
                    trimmed = true
                    B2BLog.ai.info("Trimmed cache for persona \(personaId) to \(currentCacheSize) songs")
                }
            }

            if trimmed {
                saveCaches()
            }

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
}
