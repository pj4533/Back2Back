//
//  SongProtocol.swift
//  Back2Back
//
//  Created for comprehensive testing upgrade
//  Provides abstraction over MusicKit's Song type to enable unit testing
//

import Foundation
import MusicKit

/// Protocol abstraction for MusicKit Song to enable unit testing
///
/// MusicKit's Song type cannot be instantiated in unit tests because it has no public
/// initializer and can only be created via catalog searches. This protocol provides
/// an abstraction that allows both real Song objects and test mocks to be used
/// interchangeably in the codebase.
///
/// Real MusicKit Song objects conform to this protocol via extension.
/// Tests can use MockSong (see Back2BackTests/Mocks/MockSong.swift) for fast unit tests.
@MainActor
protocol SongProtocol {
    /// Unique identifier for the song
    var id: MusicItemID { get }

    /// Song title
    var title: String { get }

    /// Artist name
    var artistName: String { get }

    /// Album title (optional)
    var albumTitle: String? { get }

    /// Song artwork (optional)
    var artwork: Artwork? { get }

    /// Song duration
    var duration: TimeInterval? { get }
}

/// Extend MusicKit's Song to conform to SongProtocol
/// This allows existing code to work with both Song and MockSong
extension Song: SongProtocol {
    // Song already has all required properties, so no implementation needed
}
