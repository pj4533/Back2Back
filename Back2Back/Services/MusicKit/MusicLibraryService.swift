//
//  MusicLibraryService.swift
//  Back2Back
//
//  Created as part of playlist export feature (Issue #85)
//

import Foundation
import MusicKit
import OSLog

/// Service handling Apple Music library operations (playlists)
/// Requires library access permission in addition to playback permission
@MainActor
final class MusicLibraryService: MusicLibraryServiceProtocol {

    // MARK: - Public API

    /// Fetches user's playlists from Apple Music library
    /// - Returns: Array of user-created playlists (excluding Apple-created playlists)
    /// - Throws: MusicLibraryError if fetching fails or permission is denied
    func fetchUserPlaylists() async throws -> [Playlist] {
        B2BLog.musicKit.info("Fetching user playlists from library")

        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 100 // Fetch up to 100 playlists

            let response = try await request.response()
            let playlists = Array(response.items)

            B2BLog.musicKit.info("Successfully fetched \(playlists.count) playlists")
            return playlists
        } catch {
            B2BLog.musicKit.error("Failed to fetch playlists: \(error.localizedDescription)")
            throw MusicLibraryError.fetchFailed(underlying: error)
        }
    }

    /// Converts a FavoritedSong to a MusicKit Song by fetching from catalog
    /// - Parameter favoritedSong: The favorited song with MusicKit ID
    /// - Returns: MusicKit Song instance
    /// - Throws: MusicLibraryError if song not found or fetch fails
    func convertToSong(favoritedSong: FavoritedSong) async throws -> Song {
        B2BLog.musicKit.info("Converting favorited song to MusicKit Song: \(favoritedSong.title)")

        do {
            let songId = MusicItemID(favoritedSong.songId)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songId)
            let response = try await request.response()

            guard let song = response.items.first else {
                B2BLog.musicKit.error("Song not found in catalog: \(favoritedSong.songId)")
                throw MusicLibraryError.songNotFound(songId: favoritedSong.songId)
            }

            B2BLog.musicKit.info("Successfully converted song: \(song.title)")
            return song
        } catch let error as MusicLibraryError {
            throw error
        } catch {
            B2BLog.musicKit.error("Failed to fetch song from catalog: \(error.localizedDescription)")
            throw MusicLibraryError.fetchFailed(underlying: error)
        }
    }

    /// Adds a song to the specified playlist
    /// - Parameters:
    ///   - song: The MusicKit Song to add
    ///   - playlist: The target playlist
    /// - Throws: MusicLibraryError if addition fails (e.g., non-editable playlist)
    func addSongToPlaylist(song: Song, playlist: Playlist) async throws {
        B2BLog.musicKit.info("Adding song '\(song.title)' to playlist '\(playlist.name)'")

        do {
            try await MusicLibrary.shared.add(song, to: playlist)
            B2BLog.musicKit.info("Successfully added song to playlist")
        } catch {
            B2BLog.musicKit.error("Failed to add song to playlist: \(error.localizedDescription)")
            throw MusicLibraryError.addToPlaylistFailed(underlying: error)
        }
    }
}

// MARK: - Error Types

enum MusicLibraryError: LocalizedError {
    case fetchFailed(underlying: Error)
    case songNotFound(songId: String)
    case addToPlaylistFailed(underlying: Error)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch playlists: \(error.localizedDescription)"
        case .songNotFound(let songId):
            return "Song not found in Apple Music catalog (ID: \(songId))"
        case .addToPlaylistFailed(let error):
            return "Failed to add song to playlist: \(error.localizedDescription)"
        case .permissionDenied:
            return "Library access permission denied. Please enable in Settings."
        }
    }
}
