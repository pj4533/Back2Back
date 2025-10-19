//
//  SongDebugInfo.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Implements comprehensive debugging details for AI song selection (Issue #87)
//

import Foundation
import MusicKit
import OSLog

/// Comprehensive debug information for a single AI song selection
/// Maintains 1:1 relationship with SessionSong via UUID reference
struct SongDebugInfo: Codable, Identifiable {
    let id: UUID // Matches SessionSong.id
    let timestamp: Date
    let outcome: SelectionOutcome
    let retryCount: Int

    // Phase 1: AI Recommendation
    let aiRecommendation: AIRecommendation

    // Phase 2: MusicKit Search
    let searchPhase: SearchPhase

    // Phase 3: Matching Decision
    let matchingPhase: MatchingPhase

    // Phase 4: Validation Result (optional)
    let validationPhase: ValidationPhase?

    // Phase 5: Final Outcome
    let finalSong: FinalSongInfo?

    // Context
    let sessionContext: SessionContext
    let personaSnapshot: PersonaSnapshot
    let directionChange: DirectionChangeInfo?
}

// MARK: - Selection Outcome

enum SelectionOutcome: String, Codable {
    case success
    case failedSearch
    case failedMatch
    case failedValidation
    case failedQueue
    case cancelled
}

// MARK: - AI Recommendation

struct AIRecommendation: Codable {
    let artist: String
    let title: String
    let rationale: String
    let model: String
    let reasoningLevel: String
    let timestamp: Date
}

// MARK: - Search Phase

struct SearchPhase: Codable {
    let query: String
    let results: [SearchResultInfo]
    let resultCount: Int
    let duration: TimeInterval
    let timestamp: Date
}

struct SearchResultInfo: Codable, Identifiable {
    let id: String // MusicKit ID
    let title: String
    let artist: String
    let album: String?
    let releaseDate: Date?
    let duration: TimeInterval?
    let genreNames: [String]
    let ranking: Int // Position in search results (0-based)
    let wasSelected: Bool
}

// MARK: - Matching Phase

struct MatchingPhase: Codable {
    let matcherType: String // "StringBased" or "LLMBased"
    let selectedResultId: String?
    let confidenceScore: Double?
    let reasoning: String?
    let timestamp: Date

    // For LLM matcher: additional context
    let llmResponse: String?
}

// MARK: - Validation Phase

struct ValidationPhase: Codable {
    let passed: Bool
    let shortExplanation: String
    let longExplanation: String
    let timestamp: Date
}

// MARK: - Final Song Info

struct FinalSongInfo: Codable {
    let musicKitId: String
    let title: String
    let artist: String
    let album: String?
    let releaseDate: Date?
    let duration: TimeInterval?
    let genreNames: [String]
    let artworkURL: String?
}

// MARK: - Session Context

struct SessionContext: Codable {
    let turnState: String // "user" or "ai"
    let historyCount: Int
    let queueCount: Int
    let recentSongs: [RecentSongInfo] // Last 5 songs for context
}

struct RecentSongInfo: Codable {
    let title: String
    let artist: String
    let selectedBy: String
}

// MARK: - Persona Snapshot

struct PersonaSnapshot: Codable {
    let name: String
    let styleGuide: String
    let createdAt: Date
}

// MARK: - Direction Change Info

struct DirectionChangeInfo: Codable {
    let directionPrompt: String
    let buttonLabel: String
    let timestamp: Date
}

// MARK: - Debug Info Builder

/// Builder pattern for incrementally collecting debug data during async AI selection
@MainActor
final class SongDebugInfoBuilder {
    private var sessionSongId: UUID
    private var timestamp: Date
    private var outcome: SelectionOutcome = .success
    private var retryCount: Int = 0

    private var aiRecommendation: AIRecommendation?
    private var searchPhase: SearchPhase?
    private var matchingPhase: MatchingPhase?
    private var validationPhase: ValidationPhase?
    private var finalSong: FinalSongInfo?
    private var sessionContext: SessionContext?
    private var personaSnapshot: PersonaSnapshot?
    private var directionChange: DirectionChangeInfo?

    init(sessionSongId: UUID) {
        self.sessionSongId = sessionSongId
        self.timestamp = Date()
    }

    func setOutcome(_ outcome: SelectionOutcome) {
        self.outcome = outcome
    }

    func setRetryCount(_ count: Int) {
        self.retryCount = count
    }

    func setAIRecommendation(_ recommendation: AIRecommendation) {
        self.aiRecommendation = recommendation
    }

    func setSearchPhase(_ search: SearchPhase) {
        self.searchPhase = search
    }

    func setMatchingPhase(_ matching: MatchingPhase) {
        self.matchingPhase = matching
    }

    func setValidationPhase(_ validation: ValidationPhase) {
        self.validationPhase = validation
    }

    func setFinalSong(_ song: FinalSongInfo) {
        self.finalSong = song
    }

    func setSessionContext(_ context: SessionContext) {
        self.sessionContext = context
    }

    func setPersonaSnapshot(_ persona: PersonaSnapshot) {
        self.personaSnapshot = persona
    }

    func setDirectionChange(_ direction: DirectionChangeInfo) {
        self.directionChange = direction
    }

    /// Build the final SongDebugInfo object
    /// Returns nil if required fields are missing
    func build() -> SongDebugInfo? {
        guard let aiRecommendation = aiRecommendation,
              let searchPhase = searchPhase,
              let matchingPhase = matchingPhase,
              let sessionContext = sessionContext,
              let personaSnapshot = personaSnapshot else {
            B2BLog.session.error("Cannot build SongDebugInfo: missing required fields")
            return nil
        }

        return SongDebugInfo(
            id: sessionSongId,
            timestamp: timestamp,
            outcome: outcome,
            retryCount: retryCount,
            aiRecommendation: aiRecommendation,
            searchPhase: searchPhase,
            matchingPhase: matchingPhase,
            validationPhase: validationPhase,
            finalSong: finalSong,
            sessionContext: sessionContext,
            personaSnapshot: personaSnapshot,
            directionChange: directionChange
        )
    }
}

// MARK: - Helper Extensions

extension SongDebugInfo {
    /// Generate a human-readable debug report
    func generateReport() -> String {
        var report = """
        === Back2Back Song Debug Report ===
        Timestamp: \(timestamp.formatted(date: .long, time: .standard))
        Outcome: \(outcome.rawValue.capitalized)
        Retry Count: \(retryCount)

        === Session Context ===
        Turn: \(sessionContext.turnState)
        History: \(sessionContext.historyCount) songs
        Queue: \(sessionContext.queueCount) songs

        === Persona ===
        Name: \(personaSnapshot.name)
        Style Guide: \(personaSnapshot.styleGuide)

        """

        if let direction = directionChange {
            report += """

            === Direction Change ===
            Button Label: \(direction.buttonLabel)
            Direction: \(direction.directionPrompt)

            """
        }

        report += """

        === AI Recommendation ===
        Artist: \(aiRecommendation.artist)
        Title: \(aiRecommendation.title)
        Rationale: \(aiRecommendation.rationale)
        Model: \(aiRecommendation.model)
        Reasoning Level: \(aiRecommendation.reasoningLevel)

        === MusicKit Search ===
        Query: \(searchPhase.query)
        Results: \(searchPhase.resultCount) found
        Duration: \(String(format: "%.2f", searchPhase.duration))s

        Top Results:

        """

        for result in searchPhase.results.prefix(10) {
            let selected = result.wasSelected ? " [SELECTED]" : ""
            report += "\(result.ranking + 1). \(result.artist) - \(result.title)\(selected)\n"
            if let album = result.album {
                report += "   Album: \(album)\n"
            }
            if let releaseDate = result.releaseDate {
                report += "   Released: \(releaseDate.formatted(date: .abbreviated, time: .omitted))\n"
            }
        }

        report += """

        === Matching Decision ===
        Matcher: \(matchingPhase.matcherType)

        """

        if let confidence = matchingPhase.confidenceScore {
            report += "Confidence: \(String(format: "%.2f%%", confidence * 100))\n"
        }

        if let reasoning = matchingPhase.reasoning {
            report += "Reasoning: \(reasoning)\n"
        }

        if let llmResponse = matchingPhase.llmResponse {
            report += "LLM Response: \(llmResponse)\n"
        }

        if let validation = validationPhase {
            report += """

            === Validation ===
            Passed: \(validation.passed ? "✓" : "✗")
            \(validation.shortExplanation)

            Details: \(validation.longExplanation)

            """
        }

        if let final = finalSong {
            report += """

            === Final Song ===
            Title: \(final.title)
            Artist: \(final.artist)

            """

            if let album = final.album {
                report += "Album: \(album)\n"
            }

            if let releaseDate = final.releaseDate {
                report += "Released: \(releaseDate.formatted(date: .abbreviated, time: .omitted))\n"
            }

            if let duration = final.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                report += "Duration: \(minutes):\(String(format: "%02d", seconds))\n"
            }

            if !final.genreNames.isEmpty {
                report += "Genres: \(final.genreNames.joined(separator: ", "))\n"
            }
        }

        report += "\n=== End of Report ===\n"
        return report
    }

    /// Generate JSON export of debug info
    func generateJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode debug info\"}"
        }

        return json
    }
}
