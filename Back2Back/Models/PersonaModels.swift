import Foundation

struct SongRecommendation: Codable, Equatable {
    let artist: String
    let song: String
    let rationale: String
}

struct Persona: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var styleGuide: String
    var isSelected: Bool
    let createdAt: Date
    var updatedAt: Date
    var firstSelection: CachedFirstSelection?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        styleGuide: String = "",
        isSelected: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        firstSelection: CachedFirstSelection? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.styleGuide = styleGuide
        self.isSelected = isSelected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.firstSelection = firstSelection
    }
}

struct CachedFirstSelection: Codable, Equatable {
    let recommendation: SongRecommendation
    let cachedAt: Date
    let appleMusicSong: SimplifiedSong?

    init(recommendation: SongRecommendation, cachedAt: Date = Date(), appleMusicSong: SimplifiedSong?) {
        self.recommendation = recommendation
        self.cachedAt = cachedAt
        self.appleMusicSong = appleMusicSong
    }
}

struct SimplifiedSong: Codable, Equatable {
    let id: String // MusicKit song ID
    let title: String
    let artistName: String
    let artworkURL: String?

    init(id: String, title: String, artistName: String, artworkURL: String?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
    }
}

struct PersonaGenerationResult {
    let name: String
    let styleGuide: String
    let sources: [String]
}