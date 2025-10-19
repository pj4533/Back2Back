import Foundation
import MusicKit

@MainActor
protocol MusicLibraryServiceProtocol {
    /// Fetches user's playlists from Apple Music library
    func fetchUserPlaylists() async throws -> [Playlist]

    /// Converts a FavoritedSong to a MusicKit Song by fetching from catalog
    func convertToSong(favoritedSong: FavoritedSong) async throws -> Song

    /// Adds a song to the specified playlist
    func addSongToPlaylist(song: Song, playlist: Playlist) async throws
}
