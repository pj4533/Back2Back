//
//  TestFixtures.swift
//  Back2BackTests
//
//  Created for comprehensive testing upgrade
//  Provides test data and helper functions for creating mock objects
//

import Foundation
import MusicKit
@testable import Back2Back

/// Test fixtures and helper functions for creating test data
@MainActor
enum TestFixtures {
    // MARK: - Mock Song Creation

    /// Create a mock Song for testing
    /// Note: MusicKit Song cannot be instantiated directly, so this uses reflection/unsafe techniques
    /// For most tests, use SessionSong with mock data instead
    static func createMockSessionSong(
        id: UUID = UUID(),
        title: String = "Test Song",
        artist: String = "Test Artist",
        selectedBy: TurnType = .user,
        queueStatus: QueueStatus = .upNext,
        rationale: String? = nil
    ) -> SessionSong? {
        // We cannot create actual Song objects in tests due to MusicKit limitations
        // This is a placeholder that returns nil - tests should use protocol mocks instead
        return nil
    }

    // MARK: - Session History

    static var emptySessionHistory: [SessionSong] {
        []
    }

    static func sessionHistoryWithSongs(count: Int, selectedBy: TurnType = .user) -> [SessionSong] {
        // Returns empty array since we can't create real Song objects
        // Tests should use mock data or protocols
        []
    }

    // MARK: - Personas

    static var mockPersona: Persona {
        Persona(
            id: UUID(),
            name: "Test DJ",
            description: "A test persona for unit testing",
            styleGuide: "You are a test DJ. Select songs that match the test criteria."
        )
    }

    static var mockPersonas: [Persona] {
        [
            Persona(
                id: UUID(),
                name: "Test DJ 1",
                description: "First test persona",
                styleGuide: "Test style guide 1"
            ),
            Persona(
                id: UUID(),
                name: "Test DJ 2",
                description: "Second test persona",
                styleGuide: "Test style guide 2"
            )
        ]
    }

    // MARK: - AI Recommendations

    static var mockSongRecommendation: SongRecommendation {
        SongRecommendation(
            artist: "Test Artist",
            song: "Test Song",
            rationale: "This song perfectly matches the test criteria"
        )
    }

    static var mockDirectionChange: DirectionChange {
        DirectionChange(options: [
            DirectionOption(
                directionPrompt: "Try exploring West Coast psychedelic rock with experimental production",
                buttonLabel: "West Coast vibes"
            ),
            DirectionOption(
                directionPrompt: "Shift to 60s garage rock with raw, energetic vibes",
                buttonLabel: "60s garage rock"
            )
        ])
    }

    // MARK: - AI Model Config

    static var defaultAIModelConfig: AIModelConfig {
        AIModelConfig(
            songSelectionModel: "gpt-5",
            songSelectionReasoningLevel: .low,
            musicMatcher: .stringBased
        )
    }

    static var highReasoningConfig: AIModelConfig {
        AIModelConfig(
            songSelectionModel: "gpt-5",
            songSelectionReasoningLevel: .high,
            musicMatcher: .stringBased
        )
    }

    // MARK: - String Normalization Test Cases

    struct NormalizationTestCase {
        let input: String
        let expected: String
        let description: String
    }

    static var unicodeNormalizationCases: [NormalizationTestCase] {
        [
            NormalizationTestCase(
                input: "Don't Stop Believin'",
                expected: "dont stop believin",
                description: "Curly apostrophes (U+2019)"
            ),
            NormalizationTestCase(
                input: "\u{201C}Quotes\u{201D}",
                expected: "quotes",
                description: "Curly quotes (U+201C, U+201D)"
            ),
            NormalizationTestCase(
                input: "café naïve résumé",
                expected: "cafe naive resume",
                description: "Diacritics (é, ï, é)"
            ),
            NormalizationTestCase(
                input: "The Beatles",
                expected: "beatles",
                description: "The prefix removal"
            ),
            NormalizationTestCase(
                input: "Artist feat. Someone",
                expected: "artist someone",
                description: "Featuring artist (feat.)"
            ),
            NormalizationTestCase(
                input: "Artist ft. Someone",
                expected: "artist someone",
                description: "Featuring artist (ft.)"
            ),
            NormalizationTestCase(
                input: "Artist featuring Someone",
                expected: "artist someone",
                description: "Featuring artist (full word)"
            ),
            NormalizationTestCase(
                input: "Artist with Someone",
                expected: "artist someone",
                description: "Featuring artist (with)"
            ),
            NormalizationTestCase(
                input: "Artist & Someone",
                expected: "artist and someone",
                description: "Ampersand to 'and'"
            ),
            NormalizationTestCase(
                input: "T.S.U.",
                expected: "tsu",
                description: "Abbreviation period removal"
            ),
            NormalizationTestCase(
                input: "Song (Remastered)",
                expected: "song",
                description: "Parenthetical removal"
            ),
            NormalizationTestCase(
                input: "Song (Live)",
                expected: "song",
                description: "Live version parenthetical"
            ),
            NormalizationTestCase(
                input: "Song Pt. 1",
                expected: "song",
                description: "Part number removal"
            ),
            NormalizationTestCase(
                input: "Song Part 2",
                expected: "song",
                description: "Part number (full word)"
            )
        ]
    }

    // MARK: - Queue Status Test Cases

    struct QueueStatusTestCase {
        let currentTurn: TurnType
        let expected: QueueStatus
        let description: String
    }

    static var queueStatusCases: [QueueStatusTestCase] {
        [
            QueueStatusTestCase(
                currentTurn: .user,
                expected: .queuedIfUserSkips,
                description: "User's turn → AI queues as backup"
            ),
            QueueStatusTestCase(
                currentTurn: .ai,
                expected: .upNext,
                description: "AI's turn → song will definitely play"
            )
        ]
    }
}
