//
//  StringBasedMusicMatcher.swift
//  Back2Back
//
//  Created on 2025-09-30.
//

import Foundation
import MusicKit
import OSLog

/// String normalization-based music matching implementation
/// Uses fuzzy string matching with scoring to find the best match between
/// AI recommendations and MusicKit search results.
///
/// NOTE: This implementation is designed to be easily replaceable with an
/// LLM-based matcher in the future. All MusicKit-specific string normalization
/// logic is isolated to this class.
@MainActor
final class StringBasedMusicMatcher: MusicMatchingProtocol {
    private let musicService = MusicService.shared

    func searchAndMatch(recommendation: SongRecommendation) async throws -> Song? {
        B2BLog.musicKit.info("Searching for: \(recommendation.song) by \(recommendation.artist)")

        // Try exact search first
        try await musicService.searchCatalog(
            for: "\(recommendation.artist) \(recommendation.song)"
        )

        var searchResults = musicService.searchResults

        if searchResults.isEmpty {
            // Try with just song title
            B2BLog.musicKit.debug("No results from combined search, trying title-only search")
            try await musicService.searchCatalog(for: recommendation.song)
            searchResults = musicService.searchResults
        }

        if searchResults.isEmpty {
            B2BLog.musicKit.warning("No search results found for: \(recommendation.song) by \(recommendation.artist)")
            return nil
        }

        // Prioritize Apple's TopResults (first 3 results are typically the most relevant)
        // Apple's search algorithm has already ranked these as best matches
        let topResults = Array(searchResults.prefix(3))
        B2BLog.musicKit.debug("Checking top \(topResults.count) results first")

        let topMatchResult = await findMatch(recommendation: recommendation, in: topResults)
        if topMatchResult.confidence >= 0.5, let song = topMatchResult.song {
            B2BLog.musicKit.info("✅ Found match in top results: '\(song.title)' by \(song.artistName)")
            return song
        }

        // Fall back to full results if top results didn't have a good match
        B2BLog.musicKit.debug("No match in top results, checking all \(searchResults.count) results")
        let fullMatchResult = await findMatch(recommendation: recommendation, in: searchResults)
        if fullMatchResult.confidence >= 0.5, let song = fullMatchResult.song {
            B2BLog.musicKit.info("✅ Found match in full results: '\(song.title)' by \(song.artistName)")
            return song
        }

        // Return nil instead of blindly accepting first result
        // This allows the AI to retry with a different recommendation
        B2BLog.musicKit.warning("❌ No good match found for: '\(recommendation.song)' by '\(recommendation.artist)'")
        B2BLog.musicKit.debug("First result was: '\(searchResults.first?.song.title ?? "none")' by '\(searchResults.first?.song.artistName ?? "none")'")
        return nil
    }

    func findMatch(
        recommendation: SongRecommendation,
        in searchResults: [MusicSearchResult]
    ) async -> SongMatchResult {
        // Normalize search terms
        let normalizedArtist = normalizeString(recommendation.artist)
        let normalizedTitle = normalizeString(stripParentheticals(recommendation.song))

        B2BLog.musicKit.debug("Looking for match - Artist: '\(normalizedArtist)', Title: '\(normalizedTitle)'")

        // Score each result
        let scoredResults = searchResults.compactMap { result -> (result: MusicSearchResult, artistScore: Int, titleScore: Int, totalScore: Int)? in
            let song = result.song

            var artistScore = 0
            var titleScore = 0

            // Normalize result strings
            let resultArtist = normalizeString(song.artistName)
            let resultTitle = normalizeString(stripParentheticals(song.title))

            // Score artist match
            if resultArtist == normalizedArtist { artistScore = 100 }
            else if resultArtist.contains(normalizedArtist) { artistScore = 50 }
            else if normalizedArtist.contains(resultArtist) { artistScore = 25 }

            // Score title match
            if resultTitle == normalizedTitle { titleScore = 100 }
            else if resultTitle.contains(normalizedTitle) { titleScore = 50 }
            else if normalizedTitle.contains(resultTitle) { titleScore = 25 }

            let totalScore = artistScore + titleScore

            // Log details for debugging
            if totalScore >= 25 {
                B2BLog.musicKit.debug("  Candidate: '\(resultTitle)' by '\(resultArtist)' - Artist:\(artistScore) Title:\(titleScore) Total:\(totalScore)")
            }

            return (result, artistScore, titleScore, totalScore)
        }

        // CRITICAL: Require BOTH artist AND title to have some match
        // This prevents matching "I Love You" by "Trippie Redd" when looking for "I Love You" by "The Darling Dears"
        // We need at least a partial match (25+) in BOTH fields, plus a good total score
        if let best = scoredResults.max(by: { $0.totalScore < $1.totalScore }),
           best.artistScore >= 25,  // Artist must have at least partial match
           best.titleScore >= 25,   // Title must have at least partial match
           best.totalScore >= 100 { // Total score must be decent

            let confidence = Double(best.totalScore) / 200.0  // Max possible score is 200

            B2BLog.musicKit.info("✅ Found match with Artist:\(best.artistScore) Title:\(best.titleScore) Total:\(best.totalScore)")
            B2BLog.musicKit.info("   '\(best.result.song.title)' by \(best.result.song.artistName)")

            return SongMatchResult(
                song: best.result.song,
                confidence: confidence,
                matchDetails: "Artist:\(best.artistScore) Title:\(best.titleScore) Total:\(best.totalScore)"
            )
        }

        B2BLog.musicKit.warning("❌ No match found meeting criteria (need Artist≥25, Title≥25, Total≥100)")
        if let best = scoredResults.max(by: { $0.totalScore < $1.totalScore }) {
            B2BLog.musicKit.debug("   Best candidate was: Artist:\(best.artistScore) Title:\(best.titleScore) Total:\(best.totalScore)")
            B2BLog.musicKit.debug("   '\(best.result.song.title)' by \(best.result.song.artistName)")
        }

        return SongMatchResult(song: nil, confidence: 0.0, matchDetails: "No qualifying matches")
    }

    // MARK: - String Normalization Helpers
    // NOTE: These methods contain all MusicKit-specific string comparison logic
    // Future LLM-based matchers won't need these methods

    /// Normalizes a string for matching by handling diacritics, featuring artists, and punctuation
    private func normalizeString(_ string: String) -> String {
        var normalized = string.lowercased()

        // Handle featuring artists - remove common variations
        normalized = normalized.replacingOccurrences(of: " feat. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " ft. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " featuring ", with: " ")
        normalized = normalized.replacingOccurrences(of: " with ", with: " ")

        // Normalize "The" prefix (common in artist names)
        if normalized.hasPrefix("the ") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove common punctuation that varies (& vs and, periods, hyphens in abbreviations)
        normalized = normalized.replacingOccurrences(of: " & ", with: " and ")
        normalized = normalized.replacingOccurrences(of: "&", with: " and ")

        // Remove periods from abbreviations (T.S.U. → TSU)
        normalized = normalized.replacingOccurrences(of: ".", with: "")

        // FIX: Normalize Unicode apostrophes and quotes to ASCII
        // OpenAI often returns Unicode characters (U+2019 ') instead of ASCII apostrophes (')
        // MusicKit may use either, so we normalize to a common format
        normalized = normalized.replacingOccurrences(of: "\u{2019}", with: "'")  // Right single quotation mark → ASCII apostrophe
        normalized = normalized.replacingOccurrences(of: "\u{2018}", with: "'")  // Left single quotation mark → ASCII apostrophe
        normalized = normalized.replacingOccurrences(of: "\u{201C}", with: "\"") // Left double quotation mark → ASCII quote
        normalized = normalized.replacingOccurrences(of: "\u{201D}", with: "\"") // Right double quotation mark → ASCII quote

        // Normalize unicode characters (é → e, ñ → n, etc.)
        normalized = normalized.folding(options: .diacriticInsensitive, locale: .current)

        // Normalize multiple spaces to single space
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespaces)

        return normalized
    }

    /// Strips parentheticals and part numbers from titles
    /// Removes: "(Remastered)", "(Live)", "(Radio Edit)", "Pt. 1", "Part 1", etc.
    private func stripParentheticals(_ string: String) -> String {
        var cleaned = string

        // Remove parentheticals: (Remastered), (Live), etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )

        // Remove "Pt. 1", "Pt. 2", "Part 1", "Part 2", etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+Pt\.?\s*\d+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+Part\s+\d+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
