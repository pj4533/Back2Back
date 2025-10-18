//
//  PersonaSongCacheServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-09-30.
//

import Testing
import Foundation
@testable import Back2Back

@MainActor
struct PersonaSongCacheServiceTests {
    let service = PersonaSongCacheService()

    init() async {
        // Clear all caches before each test
        service.clearAllCaches()

        // Set cache size to 50 for tests
        UserDefaults.standard.set(50, forKey: "com.back2back.personaSongCacheSize")
    }

    @Test("Recording a song creates a cache entry")
    func recordSongCreatesEntry() async {
        let personaId = UUID()
        let artist = "The Beatles"
        let songTitle = "Hey Jude"

        service.recordSong(personaId: personaId, artist: artist, songTitle: songTitle)

        let recentSongs = service.getRecentSongs(for: personaId)
        #expect(recentSongs.count == 1)
        #expect(recentSongs.first?.artist == artist)
        #expect(recentSongs.first?.songTitle == songTitle)
    }

    @Test("Recording multiple songs for same persona")
    func recordMultipleSongsForSamePersona() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        service.recordSong(personaId: personaId, artist: "Artist 3", songTitle: "Song 3")

        let recentSongs = service.getRecentSongs(for: personaId)
        #expect(recentSongs.count == 3)
    }

    @Test("Different personas have separate caches")
    func separateCachesPerPersona() async {
        let persona1 = UUID()
        let persona2 = UUID()

        service.recordSong(personaId: persona1, artist: "Artist A", songTitle: "Song A")
        service.recordSong(personaId: persona2, artist: "Artist B", songTitle: "Song B")

        let persona1Songs = service.getRecentSongs(for: persona1)
        let persona2Songs = service.getRecentSongs(for: persona2)

        #expect(persona1Songs.count == 1)
        #expect(persona2Songs.count == 1)
        #expect(persona1Songs.first?.artist == "Artist A")
        #expect(persona2Songs.first?.artist == "Artist B")
    }

    @Test("Get recent songs returns empty array for unknown persona")
    func unknownPersonaReturnsEmpty() async {
        let unknownPersonaId = UUID()
        let recentSongs = service.getRecentSongs(for: unknownPersonaId)
        #expect(recentSongs.isEmpty)
    }

    @Test("Clear cache removes all songs for persona")
    func clearCacheRemovesSongs() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")

        #expect(service.getRecentSongs(for: personaId).count == 2)

        service.clearCache(for: personaId)

        #expect(service.getRecentSongs(for: personaId).isEmpty)
    }

    @Test("Clear all caches removes everything")
    func clearAllCachesRemovesEverything() async {
        let persona1 = UUID()
        let persona2 = UUID()

        service.recordSong(personaId: persona1, artist: "Artist A", songTitle: "Song A")
        service.recordSong(personaId: persona2, artist: "Artist B", songTitle: "Song B")

        #expect(service.getRecentSongs(for: persona1).count == 1)
        #expect(service.getRecentSongs(for: persona2).count == 1)

        service.clearAllCaches()

        #expect(service.getRecentSongs(for: persona1).isEmpty)
        #expect(service.getRecentSongs(for: persona2).isEmpty)
    }

    // MARK: - LRU Cache Tests

    @Test("LRU eviction when cache reaches size limit")
    func lruEvictionAtLimit() async {
        let personaId = UUID()

        // Set cache size to 3 for this test
        UserDefaults.standard.set(3, forKey: "com.back2back.personaSongCacheSize")

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        service.recordSong(personaId: personaId, artist: "Artist 3", songTitle: "Song 3")

        let beforeEviction = service.getRecentSongs(for: personaId)
        #expect(beforeEviction.count == 3)

        // Add a 4th song - should evict the oldest (Song 1)
        service.recordSong(personaId: personaId, artist: "Artist 4", songTitle: "Song 4")

        let afterEviction = service.getRecentSongs(for: personaId)
        #expect(afterEviction.count == 3)
        #expect(afterEviction.contains { $0.songTitle == "Song 1" } == false)
        #expect(afterEviction.contains { $0.songTitle == "Song 2" } == true)
        #expect(afterEviction.contains { $0.songTitle == "Song 3" } == true)
        #expect(afterEviction.contains { $0.songTitle == "Song 4" } == true)

        // Reset cache size
        UserDefaults.standard.set(50, forKey: "com.back2back.personaSongCacheSize")
    }

    @Test("LRU eviction maintains correct order")
    func lruEvictionOrder() async {
        let personaId = UUID()

        // Set cache size to 5
        UserDefaults.standard.set(5, forKey: "com.back2back.personaSongCacheSize")

        // Add 7 songs
        for i in 1...7 {
            service.recordSong(personaId: personaId, artist: "Artist \(i)", songTitle: "Song \(i)")
        }

        let songs = service.getRecentSongs(for: personaId)
        #expect(songs.count == 5)

        // Should have songs 3, 4, 5, 6, 7 (first 2 evicted)
        #expect(songs[0].songTitle == "Song 3")
        #expect(songs[1].songTitle == "Song 4")
        #expect(songs[2].songTitle == "Song 5")
        #expect(songs[3].songTitle == "Song 6")
        #expect(songs[4].songTitle == "Song 7")

        // Reset cache size
        UserDefaults.standard.set(50, forKey: "com.back2back.personaSongCacheSize")
    }

    @Test("Cache size of 1 works correctly")
    func cacheSizeOne() async {
        let personaId = UUID()

        // Set cache size to 1
        UserDefaults.standard.set(1, forKey: "com.back2back.personaSongCacheSize")

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        #expect(service.getRecentSongs(for: personaId).count == 1)

        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        let songs = service.getRecentSongs(for: personaId)
        #expect(songs.count == 1)
        #expect(songs.first?.songTitle == "Song 2")

        // Reset cache size
        UserDefaults.standard.set(50, forKey: "com.back2back.personaSongCacheSize")
    }

    @Test("PersonaSongCache addSong method")
    func addSongMethod() async {
        let personaId = UUID()
        var cache = PersonaSongCache(personaId: personaId, songs: [])

        // Add 3 songs with limit 3
        cache.addSong(CachedSong(artist: "Artist 1", songTitle: "Song 1", selectedAt: Date()), maxSize: 3)
        cache.addSong(CachedSong(artist: "Artist 2", songTitle: "Song 2", selectedAt: Date()), maxSize: 3)
        cache.addSong(CachedSong(artist: "Artist 3", songTitle: "Song 3", selectedAt: Date()), maxSize: 3)
        #expect(cache.songs.count == 3)

        // Add 4th song - should evict first
        cache.addSong(CachedSong(artist: "Artist 4", songTitle: "Song 4", selectedAt: Date()), maxSize: 3)
        #expect(cache.songs.count == 3)
        #expect(cache.songs[0].songTitle == "Song 2")
        #expect(cache.songs[1].songTitle == "Song 3")
        #expect(cache.songs[2].songTitle == "Song 4")
    }

    @Test("Cache size configuration changes apply to new songs")
    func cacheSizeConfigChanges() async {
        let personaId = UUID()

        // Start with cache size 3
        UserDefaults.standard.set(3, forKey: "com.back2back.personaSongCacheSize")

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        service.recordSong(personaId: personaId, artist: "Artist 3", songTitle: "Song 3")

        #expect(service.getRecentSongs(for: personaId).count == 3)

        // Change cache size to 5
        UserDefaults.standard.set(5, forKey: "com.back2back.personaSongCacheSize")

        // Add 2 more songs
        service.recordSong(personaId: personaId, artist: "Artist 4", songTitle: "Song 4")
        service.recordSong(personaId: personaId, artist: "Artist 5", songTitle: "Song 5")

        // Should have 5 songs now
        #expect(service.getRecentSongs(for: personaId).count == 5)

        // Reset cache size
        UserDefaults.standard.set(50, forKey: "com.back2back.personaSongCacheSize")
    }

    @Test("Empty cache returns empty array")
    func emptyCache() async {
        let personaId = UUID()
        let songs = service.getRecentSongs(for: personaId)
        #expect(songs.isEmpty)
    }

    @Test("Backwards compatibility with existing cache data")
    func backwardsCompatibility() async {
        let personaId = UUID()

        // Create a cache with old format (would have had isExpired field, but that's computed so it doesn't affect persistence)
        let oldSong = CachedSong(
            artist: "Old Artist",
            songTitle: "Old Song",
            selectedAt: Date().addingTimeInterval(-48 * 60 * 60) // 2 days ago
        )

        var cache = PersonaSongCache(personaId: personaId, songs: [oldSong])

        // Add a new song using the new LRU method
        cache.addSong(CachedSong(artist: "New Artist", songTitle: "New Song", selectedAt: Date()), maxSize: 50)

        #expect(cache.songs.count == 2)
        #expect(cache.songs[0].artist == "Old Artist")
        #expect(cache.songs[1].artist == "New Artist")
    }

    // MARK: - Remove Song Tests

    @Test("Removing a song that exists in cache")
    func removeSongFromCache() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "The Beatles", songTitle: "Hey Jude")
        service.recordSong(personaId: personaId, artist: "Queen", songTitle: "Bohemian Rhapsody")
        service.recordSong(personaId: personaId, artist: "Pink Floyd", songTitle: "Comfortably Numb")

        #expect(service.getRecentSongs(for: personaId).count == 3)

        service.removeSong(personaId: personaId, artist: "Queen", songTitle: "Bohemian Rhapsody")

        let remainingSongs = service.getRecentSongs(for: personaId)
        #expect(remainingSongs.count == 2)
        #expect(remainingSongs.contains { $0.artist == "Queen" && $0.songTitle == "Bohemian Rhapsody" } == false)
        #expect(remainingSongs.contains { $0.artist == "The Beatles" && $0.songTitle == "Hey Jude" } == true)
        #expect(remainingSongs.contains { $0.artist == "Pink Floyd" && $0.songTitle == "Comfortably Numb" } == true)
    }

    @Test("Removing a song that doesn't exist in cache")
    func removeSongNotInCache() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "The Beatles", songTitle: "Hey Jude")
        #expect(service.getRecentSongs(for: personaId).count == 1)

        // Try to remove a song that doesn't exist
        service.removeSong(personaId: personaId, artist: "Queen", songTitle: "Bohemian Rhapsody")

        // Cache should remain unchanged
        let songs = service.getRecentSongs(for: personaId)
        #expect(songs.count == 1)
        #expect(songs.first?.artist == "The Beatles")
    }

    @Test("Removing song from unknown persona")
    func removeSongFromUnknownPersona() async {
        let unknownPersonaId = UUID()

        // Try to remove from a persona that has no cache
        service.removeSong(personaId: unknownPersonaId, artist: "The Beatles", songTitle: "Hey Jude")

        // Should not crash and cache should remain empty
        #expect(service.getRecentSongs(for: unknownPersonaId).isEmpty)
    }

    @Test("Removing all songs one by one")
    func removeAllSongsOneByOne() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        service.recordSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        service.recordSong(personaId: personaId, artist: "Artist 3", songTitle: "Song 3")

        #expect(service.getRecentSongs(for: personaId).count == 3)

        service.removeSong(personaId: personaId, artist: "Artist 1", songTitle: "Song 1")
        #expect(service.getRecentSongs(for: personaId).count == 2)

        service.removeSong(personaId: personaId, artist: "Artist 2", songTitle: "Song 2")
        #expect(service.getRecentSongs(for: personaId).count == 1)

        service.removeSong(personaId: personaId, artist: "Artist 3", songTitle: "Song 3")
        #expect(service.getRecentSongs(for: personaId).isEmpty)
    }

    @Test("Remove song is case-sensitive")
    func removeSongCaseSensitive() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "The Beatles", songTitle: "Hey Jude")

        // Try to remove with different case - should not match
        service.removeSong(personaId: personaId, artist: "the beatles", songTitle: "hey jude")

        // Song should still be in cache
        let songs = service.getRecentSongs(for: personaId)
        #expect(songs.count == 1)
        #expect(songs.first?.artist == "The Beatles")
        #expect(songs.first?.songTitle == "Hey Jude")
    }

    @Test("Remove song with exact match on both artist and title")
    func removeSongExactMatch() async {
        let personaId = UUID()

        service.recordSong(personaId: personaId, artist: "David Bowie", songTitle: "Heroes")
        service.recordSong(personaId: personaId, artist: "David Bowie", songTitle: "Space Oddity")

        // Remove one song by same artist
        service.removeSong(personaId: personaId, artist: "David Bowie", songTitle: "Heroes")

        let remainingSongs = service.getRecentSongs(for: personaId)
        #expect(remainingSongs.count == 1)
        #expect(remainingSongs.first?.songTitle == "Space Oddity")
    }
}
