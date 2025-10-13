//
//  LLMBasedMusicMatcher.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Updated for GitHub issue #42 - Implements Apple FoundationModels-based matching
//

import Foundation
import MusicKit
import OSLog
import FoundationModels

/// Response structure for LLM-guided music matching
@Generable
struct MatchResponse {
    /// Index (0-based) of best matching song, or -1 if no good match
    let matchIndex: Int

    /// Confidence level: "high", "medium", "low"
    let confidence: String

    /// Brief explanation of the match decision
    let reasoning: String
}

/// LLM-based music matching implementation using Apple's FoundationModels framework
/// Uses Apple's on-device SystemLanguageModel (~3B parameter) to intelligently match
/// AI recommendations against MusicKit search results with semantic understanding.
///
/// Benefits over string matching:
/// - Handles semantic similarity (e.g., "Fool's Gold" vs "Fools Gold")
/// - Better understanding of artist name variations
/// - Can reason about remixes, covers, and versions
/// - Less brittle than regex-based normalization
/// - Privacy-first: On-device processing, no external API calls
/// - Cost-free: No OpenAI API charges
/// - Offline: Works without internet connectivity
@MainActor
final class LLMBasedMusicMatcher: MusicMatchingProtocol {
    private let musicService: MusicService
    private let fallbackMatcher: StringBasedMusicMatcher

    // Foundation Models components
    private let model: SystemLanguageModel
    private var session: LanguageModelSession?

    init(
        musicService: MusicService,
        fallbackMatcher: StringBasedMusicMatcher,
        model: SystemLanguageModel = .default
    ) {
        self.musicService = musicService
        self.fallbackMatcher = fallbackMatcher
        self.model = model
        // Configure session with instructions if model is available
        if model.availability == .available {
            let instructions = """
            You are a music matching assistant. Given a recommendation and search results, \
            identify the best match considering artist names, song titles, and semantic similarity. \
            Return the index (0-based) of the best match, or -1 if no good match exists.
            """
            session = LanguageModelSession(instructions: instructions)
            B2BLog.musicKit.info("✅ SystemLanguageModel available for LLM-based matching")
        } else {
            B2BLog.musicKit.warning("⚠️ SystemLanguageModel not available (requires iOS 26+ with Apple Intelligence)")
        }
    }

    func searchAndMatch(recommendation: SongRecommendation) async throws -> Song? {
        B2BLog.musicKit.info("LLM-based matching for: \(recommendation.song) by \(recommendation.artist)")

        // Use paginated search to get up to 200 results (same as StringBasedMusicMatcher)
        var searchResults = try await musicService.searchCatalogWithPagination(
            for: "\(recommendation.artist) \(recommendation.song)",
            pageSize: 25,
            maxResults: 200
        )

        if searchResults.isEmpty {
            B2BLog.musicKit.debug("No results from combined search, trying title-only search")
            searchResults = try await musicService.searchCatalogWithPagination(
                for: recommendation.song,
                pageSize: 25,
                maxResults: 200
            )
        }

        if searchResults.isEmpty {
            B2BLog.musicKit.warning("No search results found for: \(recommendation.song) by \(recommendation.artist)")
            return nil
        }

        // Prioritize top 3 results first (Apple's ranking is usually good)
        let topResults = Array(searchResults.prefix(3))
        B2BLog.musicKit.debug("Checking top \(topResults.count) results first with LLM")

        let topMatchResult = await findMatch(recommendation: recommendation, in: topResults)
        if topMatchResult.confidence >= 0.7, let song = topMatchResult.song {
            B2BLog.musicKit.info("✅ LLM found match in top results: '\(song.title)' by \(song.artistName)")
            return song
        }

        // Fall back to full results if top results didn't yield a good match
        B2BLog.musicKit.debug("No match in top results, checking all \(searchResults.count) results with LLM")
        let fullMatchResult = await findMatch(recommendation: recommendation, in: searchResults)

        if fullMatchResult.confidence >= 0.7, let song = fullMatchResult.song {
            B2BLog.musicKit.info("✅ LLM found match in full results: '\(song.title)' by \(song.artistName)")
            return song
        }

        B2BLog.musicKit.warning("❌ No good match found after LLM searching \(searchResults.count) results")
        return nil
    }

    func findMatch(
        recommendation: SongRecommendation,
        in searchResults: [MusicSearchResult]
    ) async -> SongMatchResult {
        // If model not available, fall back to string matching
        guard let session = session else {
            B2BLog.musicKit.warning("SystemLanguageModel not available, falling back to string matching")
            return await fallbackMatcher.findMatch(recommendation: recommendation, in: searchResults)
        }

        // Format search results for LLM
        let resultsText = searchResults.enumerated().map { index, result in
            "[\(index)] \"\(result.song.title)\" by \(result.song.artistName)"
        }.joined(separator: "\n")

        let prompt = """
        Recommendation: "\(recommendation.song)" by \(recommendation.artist)

        Search Results:
        \(resultsText)

        Which result best matches the recommendation? Consider variations in spelling, \
        punctuation, artist name formats, and semantic similarity. Be strict about artist matching.
        """

        do {
            // Use guided generation for structured response
            B2BLog.musicKit.debug("🤖 Querying SystemLanguageModel for best match...")
            let response = try await session.respond(to: prompt, generating: MatchResponse.self)
            let matchResponse = response.content

            // Validate match index
            guard matchResponse.matchIndex >= 0 && matchResponse.matchIndex < searchResults.count else {
                B2BLog.musicKit.warning("LLM found no good match: \(matchResponse.reasoning)")
                return SongMatchResult(
                    song: nil,
                    confidence: 0.0,
                    matchDetails: "LLM: \(matchResponse.reasoning)"
                )
            }

            let matchedSong = searchResults[matchResponse.matchIndex].song
            let confidence = confidenceScore(from: matchResponse.confidence)

            B2BLog.musicKit.info("✅ LLM matched: '\(matchedSong.title)' by \(matchedSong.artistName) (confidence: \(matchResponse.confidence))")
            B2BLog.musicKit.debug("Reasoning: \(matchResponse.reasoning)")

            return SongMatchResult(
                song: matchedSong,
                confidence: confidence,
                matchDetails: "LLM: \(matchResponse.reasoning)"
            )

        } catch {
            B2BLog.musicKit.error("LLM matching failed: \(error.localizedDescription)")
            B2BLog.musicKit.info("Falling back to string-based matching")
            return await fallbackMatcher.findMatch(recommendation: recommendation, in: searchResults)
        }
    }

    /// Converts confidence level string to numeric score
    private func confidenceScore(from level: String) -> Double {
        switch level.lowercased() {
        case "high": return 0.9
        case "medium": return 0.7
        case "low": return 0.5
        default: return 0.6
        }
    }
}
