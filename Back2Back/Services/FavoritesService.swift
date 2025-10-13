//
//  FavoritesService.swift
//  Back2Back
//
//  Created on 2025-10-12.
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Observable service managing favorited songs with UserDefaults persistence.
/// This service is @Observable, allowing views to directly observe state changes
/// without needing intermediate ViewModels for simple state synchronization.
@MainActor
@Observable
final class FavoritesService {
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "com.back2back.favorites"

    /// Published array of favorited songs - views observe this directly
    private(set) var favorites: [FavoritedSong] = []

    init() {
        B2BLog.general.info("FavoritesService initialized")
        loadFavorites()
    }

    // MARK: - Public API

    /// Adds a song to favorites from a SessionSong
    func addFavorite(sessionSong: SessionSong, personaName: String, personaId: UUID) {
        let songId = sessionSong.song.id.rawValue

        // Prevent duplicates
        guard !isFavorited(songId: songId) else {
            B2BLog.general.debug("Song already favorited: \(sessionSong.song.title)")
            return
        }

        let favoritedSong = FavoritedSong(
            songId: songId,
            title: sessionSong.song.title,
            artistName: sessionSong.song.artistName,
            artworkURL: sessionSong.song.artwork?.url(width: 300, height: 300),
            personaName: personaName,
            personaId: personaId
        )

        favorites.append(favoritedSong)
        saveFavorites()

        B2BLog.general.info("Added favorite: '\(favoritedSong.title)' by '\(favoritedSong.artistName)'")
    }

    /// Removes a song from favorites by MusicKit song ID
    func removeFavorite(songId: String) {
        guard let index = favorites.firstIndex(where: { $0.songId == songId }) else {
            B2BLog.general.debug("Song not found in favorites: \(songId)")
            return
        }

        let removedSong = favorites.remove(at: index)
        saveFavorites()

        B2BLog.general.info("Removed favorite: '\(removedSong.title)' by '\(removedSong.artistName)'")
    }

    /// Toggles favorite status for a song
    func toggleFavorite(sessionSong: SessionSong, personaName: String, personaId: UUID) {
        let songId = sessionSong.song.id.rawValue

        if isFavorited(songId: songId) {
            removeFavorite(songId: songId)
        } else {
            addFavorite(sessionSong: sessionSong, personaName: personaName, personaId: personaId)
        }
    }

    /// Checks if a song is favorited by MusicKit song ID
    func isFavorited(songId: String) -> Bool {
        favorites.contains { $0.songId == songId }
    }

    /// Returns all favorites sorted by recency (newest first)
    func getFavorites() -> [FavoritedSong] {
        favorites.sorted { $0.favoritedAt > $1.favoritedAt }
    }

    /// Clears all favorites (for testing/debugging)
    func clearAllFavorites() {
        favorites.removeAll()
        saveFavorites()
        B2BLog.general.warning("Cleared all favorites")
    }

    // MARK: - Private Methods

    private func loadFavorites() {
        guard let data = userDefaults.data(forKey: favoritesKey) else {
            B2BLog.general.debug("No saved favorites found")
            return
        }

        do {
            favorites = try JSONDecoder().decode([FavoritedSong].self, from: data)
            B2BLog.general.info("Loaded \(self.favorites.count) favorited songs")
        } catch {
            B2BLog.general.error("Failed to load favorites: \(error)")
        }
    }

    private func saveFavorites() {
        do {
            let encoded = try JSONEncoder().encode(favorites)
            userDefaults.set(encoded, forKey: favoritesKey)
            B2BLog.general.debug("Saved \(self.favorites.count) favorited songs")
        } catch {
            B2BLog.general.error("Failed to save favorites: \(error)")
        }
    }
}
