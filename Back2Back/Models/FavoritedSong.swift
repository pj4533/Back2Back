//
//  FavoritedSong.swift
//  Back2Back
//
//  Created on 2025-10-12.
//

import Foundation

struct FavoritedSong: Codable, Identifiable, Equatable {
    let id: UUID
    let songId: String              // MusicKit song ID
    let title: String
    let artistName: String
    let artworkURL: URL?
    let personaName: String         // Which persona selected it
    let personaId: UUID
    let favoritedAt: Date

    init(
        id: UUID = UUID(),
        songId: String,
        title: String,
        artistName: String,
        artworkURL: URL?,
        personaName: String,
        personaId: UUID,
        favoritedAt: Date = Date()
    ) {
        self.id = id
        self.songId = songId
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.personaName = personaName
        self.personaId = personaId
        self.favoritedAt = favoritedAt
    }
}
