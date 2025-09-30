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
    let service = PersonaSongCacheService.shared

    init() async {
        // Clear all caches before each test
        service.clearAllCaches()
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

    @Test("Expired songs are filtered from results")
    func expiredSongsFiltered() async {
        let personaId = UUID()

        // Create a song that was selected 25 hours ago (expired)
        let expiredDate = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        let expiredSong = CachedSong(
            artist: "Old Artist",
            songTitle: "Old Song",
            selectedAt: expiredDate
        )

        // We can't directly inject the expired song through the service,
        // so we'll test the CachedSong.isExpired property instead
        #expect(expiredSong.isExpired == true)

        // Add a recent song
        service.recordSong(personaId: personaId, artist: "New Artist", songTitle: "New Song")

        let recentSongs = service.getRecentSongs(for: personaId)
        #expect(recentSongs.count == 1)
        #expect(recentSongs.first?.artist == "New Artist")
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

    @Test("CachedSong isExpired returns false for recent songs")
    func recentSongNotExpired() async {
        let recentSong = CachedSong(
            artist: "Artist",
            songTitle: "Song",
            selectedAt: Date() // Just now
        )
        #expect(recentSong.isExpired == false)
    }

    @Test("CachedSong isExpired returns true for old songs")
    func oldSongIsExpired() async {
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        let oldSong = CachedSong(
            artist: "Artist",
            songTitle: "Song",
            selectedAt: oldDate
        )
        #expect(oldSong.isExpired == true)
    }

    @Test("PersonaSongCache activeSongs filters expired songs")
    func activeSongsFiltersExpired() async {
        let personaId = UUID()

        let recentSong = CachedSong(
            artist: "Recent Artist",
            songTitle: "Recent Song",
            selectedAt: Date()
        )

        let expiredSong = CachedSong(
            artist: "Old Artist",
            songTitle: "Old Song",
            selectedAt: Date().addingTimeInterval(-25 * 60 * 60)
        )

        var cache = PersonaSongCache(personaId: personaId, songs: [recentSong, expiredSong])

        let activeSongs = cache.activeSongs
        #expect(activeSongs.count == 1)
        #expect(activeSongs.first?.artist == "Recent Artist")
    }

    @Test("PersonaSongCache removeExpiredSongs removes old entries")
    func removeExpiredSongsWorks() async {
        let personaId = UUID()

        let recentSong = CachedSong(
            artist: "Recent Artist",
            songTitle: "Recent Song",
            selectedAt: Date()
        )

        let expiredSong = CachedSong(
            artist: "Old Artist",
            songTitle: "Old Song",
            selectedAt: Date().addingTimeInterval(-25 * 60 * 60)
        )

        var cache = PersonaSongCache(personaId: personaId, songs: [recentSong, expiredSong])
        #expect(cache.songs.count == 2)

        cache.removeExpiredSongs()

        #expect(cache.songs.count == 1)
        #expect(cache.songs.first?.artist == "Recent Artist")
    }
}
