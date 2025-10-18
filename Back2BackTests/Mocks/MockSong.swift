//
//  MockSong.swift
//  Back2BackTests
//
//  Created for comprehensive testing upgrade
//  Provides a testable implementation of SongProtocol
//

import Foundation
import MusicKit
@testable import Back2Back

/// Mock implementation of SongProtocol for unit testing
///
/// This allows tests to create song objects without requiring MusicKit catalog searches.
/// Use the static factory methods for convenient test data creation.
@MainActor
struct MockSong: SongProtocol {
    let id: MusicItemID
    let title: String
    let artistName: String
    let albumTitle: String?
    let artwork: Artwork?
    let duration: TimeInterval?

    /// Create a mock song with custom values
    init(
        id: String = "mock-song-\(UUID().uuidString)",
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        artwork: Artwork? = nil,
        duration: TimeInterval? = 180.0
    ) {
        self.id = MusicItemID(id)
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artwork = artwork
        self.duration = duration
    }

    // MARK: - Factory Methods

    /// Create a mock song with minimal required fields
    static func minimal(
        title: String = "Test Song",
        artist: String = "Test Artist"
    ) -> MockSong {
        MockSong(title: title, artistName: artist)
    }

    /// Create a mock song with full details
    static func full(
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String = "Test Album",
        duration: TimeInterval = 180.0
    ) -> MockSong {
        MockSong(
            title: title,
            artistName: artist,
            albumTitle: album,
            duration: duration
        )
    }

    /// Create a mock song with a specific ID (useful for testing equality)
    static func withId(
        _ id: String,
        title: String = "Test Song",
        artist: String = "Test Artist"
    ) -> MockSong {
        MockSong(id: id, title: title, artistName: artist)
    }

    // MARK: - Test Fixtures

    /// The Beatles - "Come Together"
    static var comeTogether: MockSong {
        MockSong(
            id: "beatles-come-together",
            title: "Come Together",
            artistName: "The Beatles",
            albumTitle: "Abbey Road",
            duration: 259.0
        )
    }

    /// Miles Davis - "So What"
    static var soWhat: MockSong {
        MockSong(
            id: "miles-davis-so-what",
            title: "So What",
            artistName: "Miles Davis",
            albumTitle: "Kind of Blue",
            duration: 542.0
        )
    }

    /// Daft Punk - "One More Time"
    static var oneMoreTime: MockSong {
        MockSong(
            id: "daft-punk-one-more-time",
            title: "One More Time",
            artistName: "Daft Punk",
            albumTitle: "Discovery",
            duration: 320.0
        )
    }

    /// Song with Unicode characters in title
    static var unicodeTitle: MockSong {
        MockSong(
            id: "unicode-song",
            title: "Don't Stop Believin'",  // Curly apostrophes
            artistName: "Journey",
            albumTitle: "Escape",
            duration: 250.0
        )
    }

    /// Song with featuring artist
    static var featuringSong: MockSong {
        MockSong(
            id: "featuring-song",
            title: "I Love You",
            artistName: "The Darling Dears feat. Someone",
            albumTitle: "Test Album",
            duration: 200.0
        )
    }

    /// Song with remastered annotation
    static var remasteredSong: MockSong {
        MockSong(
            id: "remastered-song",
            title: "Here Comes the Sun (Remastered)",
            artistName: "The Beatles",
            albumTitle: "Abbey Road (Remastered)",
            duration: 185.0
        )
    }

    /// Very short song (edge case)
    static var veryShort: MockSong {
        MockSong(
            id: "very-short",
            title: "Intro",
            artistName: "Test Artist",
            duration: 5.0
        )
    }

    /// Very long song (edge case)
    static var veryLong: MockSong {
        MockSong(
            id: "very-long",
            title: "Thick as a Brick",
            artistName: "Jethro Tull",
            albumTitle: "Thick as a Brick",
            duration: 2592.0  // 43+ minutes
        )
    }
}

// MARK: - Equatable Conformance

extension MockSong: Equatable {
    static func == (lhs: MockSong, rhs: MockSong) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable Conformance

extension MockSong: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Helper Extensions

@MainActor
extension Array where Element == MockSong {
    /// Create an array of mock songs for testing queue/history scenarios
    static func mockQueue(count: Int = 3) -> [MockSong] {
        (0..<count).map { index in
            MockSong.minimal(
                title: "Song \(index + 1)",
                artist: "Artist \(index + 1)"
            )
        }
    }
}
