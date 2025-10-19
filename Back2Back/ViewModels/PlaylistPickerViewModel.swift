//
//  PlaylistPickerViewModel.swift
//  Back2Back
//
//  Created as part of playlist export feature (Issue #85)
//

import Foundation
import MusicKit
import Observation
import OSLog

@MainActor
@Observable
final class PlaylistPickerViewModel: ViewModelError, Identifiable {
    let id = UUID()
    private let musicService: MusicServiceProtocol
    private let favoritedSong: FavoritedSong

    // MARK: - Published State

    private(set) var playlists: [Playlist] = []
    private(set) var isLoading = false
    var errorMessage: String?

    // Computed state
    var hasError: Bool { errorMessage != nil }
    var isEmpty: Bool { playlists.isEmpty && !isLoading }

    init(musicService: MusicServiceProtocol, favoritedSong: FavoritedSong) {
        self.musicService = musicService
        self.favoritedSong = favoritedSong
    }

    // MARK: - Public API

    /// Loads user's playlists from Apple Music library
    /// Requests authorization first if not already granted
    func loadPlaylists() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        B2BLog.musicKit.info("Loading user playlists for playlist picker")

        do {
            // Request authorization if needed (this will show permission prompt)
            try await musicService.requestAuthorization()

            // Now fetch playlists with proper authorization
            playlists = try await musicService.fetchUserPlaylists()
            B2BLog.musicKit.info("Loaded \(self.playlists.count) playlists")
        } catch {
            let message = "Failed to load playlists: \(error.localizedDescription)"
            B2BLog.musicKit.error("Failed to load playlists: \(error.localizedDescription)")
            errorMessage = message
            handleError(error)
        }

        isLoading = false
    }

    /// Adds the favorited song to the selected playlist
    /// - Parameter playlist: The target playlist
    /// - Returns: True if successful, false otherwise
    func addToPlaylist(_ playlist: Playlist) async -> Bool {
        B2BLog.musicKit.info("Adding '\(self.favoritedSong.title)' to playlist '\(playlist.name)'")
        errorMessage = nil

        do {
            // First convert FavoritedSong to MusicKit Song
            let song = try await musicService.convertToSong(favoritedSong: favoritedSong)

            // Then add to playlist
            try await musicService.addSongToPlaylist(song: song, playlist: playlist)

            B2BLog.musicKit.info("Successfully added song to playlist '\(playlist.name)'")
            return true
        } catch {
            let message = "Failed to add song to playlist: \(error.localizedDescription)"
            B2BLog.musicKit.error("Failed to add song to playlist: \(error.localizedDescription)")
            errorMessage = message
            handleError(error)
            return false
        }
    }

    /// Clears error state
    func clearError() {
        errorMessage = nil
    }

    // MARK: - ViewModelError Protocol

    func handleError(_ error: Error) {
        B2BLog.musicKit.error("PlaylistPickerViewModel error: \(error.localizedDescription)")
    }
}
