//
//  LLMBasedMusicMatcher.swift
//  Back2Back
//
//  Created on 2025-09-30.
//

import Foundation
import MusicKit
import OSLog

/// LLM-based music matching implementation (future enhancement)
/// Uses a small language model to intelligently match AI recommendations
/// against MusicKit search results, handling variations that string matching
/// might miss.
///
/// TODO: Implement LLM-based matching using gpt-4o-mini or similar small model
/// TODO: Compare accuracy and performance against StringBasedMusicMatcher
/// TODO: Consider confidence threshold tuning based on production data
@MainActor
final class LLMBasedMusicMatcher: MusicMatchingProtocol {
    private let musicService = MusicService.shared
    private let openAIClient = OpenAIClient.shared

    func searchAndMatch(recommendation: SongRecommendation) async throws -> Song? {
        B2BLog.musicKit.info("LLM-based matching for: \(recommendation.song) by \(recommendation.artist)")

        // Perform MusicKit search
        try await musicService.searchCatalog(
            for: "\(recommendation.artist) \(recommendation.song)"
        )

        var searchResults = musicService.searchResults

        if searchResults.isEmpty {
            try await musicService.searchCatalog(for: recommendation.song)
            searchResults = musicService.searchResults
        }

        if searchResults.isEmpty {
            return nil
        }

        // Use LLM to find best match
        let matchResult = await findMatch(recommendation: recommendation, in: searchResults)

        if matchResult.confidence >= 0.7 {  // Higher threshold for LLM matching
            return matchResult.song
        }

        return nil
    }

    func findMatch(
        recommendation: SongRecommendation,
        in searchResults: [MusicSearchResult]
    ) async -> SongMatchResult {
        // TODO: Implement LLM-based matching
        //
        // Proposed implementation:
        // 1. Format recommendation and search results as structured text
        // 2. Use gpt-4o-mini with a simple prompt:
        //    "Which of these search results best matches the recommendation?
        //     Recommendation: {artist: X, song: Y}
        //     Results: [{artist: A, song: B}, {artist: C, song: D}, ...]
        //     Return the index (0-based) of the best match, or -1 if no good match."
        // 3. Parse the response and return the corresponding song
        // 4. Calculate confidence based on model's certainty
        //
        // Benefits over string matching:
        // - Handles semantic similarity (e.g., "Fool's Gold" vs "Fools Gold")
        // - Better understanding of artist name variations
        // - Can reason about remixes, covers, and versions
        // - Less brittle than regex-based normalization

        B2BLog.musicKit.warning("LLM-based matching not yet implemented, falling back to string matching")

        // Temporary fallback to string-based matching
        let fallbackMatcher = StringBasedMusicMatcher()
        return await fallbackMatcher.findMatch(recommendation: recommendation, in: searchResults)
    }
}
