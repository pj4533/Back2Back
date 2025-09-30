//
//  MusicMatchingProtocol.swift
//  Back2Back
//
//  Created on 2025-09-30.
//

import Foundation
import MusicKit

/// Represents the result of a song matching attempt
struct SongMatchResult {
    let song: Song?
    let confidence: Double  // 0.0 - 1.0
    let matchDetails: String  // For debugging/logging
}

/// Protocol for matching AI-recommended songs against MusicKit search results
/// This abstraction allows for multiple matching strategies (string-based, LLM-based)
/// and isolates MusicKit-specific comparison logic from the rest of the codebase.
@MainActor
protocol MusicMatchingProtocol {
    /// Finds the best matching song from search results
    /// - Parameters:
    ///   - recommendation: The AI-recommended song details
    ///   - searchResults: MusicKit search results to match against
    /// - Returns: Matching result with confidence score
    func findMatch(
        recommendation: SongRecommendation,
        in searchResults: [MusicSearchResult]
    ) async -> SongMatchResult

    /// Performs a complete search and match operation
    /// - Parameter recommendation: The AI-recommended song
    /// - Returns: Best matching Song or nil
    func searchAndMatch(
        recommendation: SongRecommendation
    ) async throws -> Song?
}
