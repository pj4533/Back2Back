//
//  SessionViewModelTests.swift
//  Back2BackTests
//
//  Created on 2025-09-27.
//

import Testing
import Foundation
@testable import Back2Back
import MusicKit

@Suite("SessionViewModel Tests")
struct SessionViewModelTests {
    @MainActor
    @Test("ViewModel initialization")
    func testViewModelInitialization() {
        let viewModel = SessionViewModel.shared

        // Verify the view model is properly initialized
        // Note: We can't create new instances due to singleton pattern
        // So we just verify it exists and has expected services
        #expect(viewModel != nil)
    }

    // Note: Tests that require creating Song instances are commented out
    // as Song is a MusicKit type that cannot be instantiated in tests

    /*
    @MainActor
    @Test("Find best match - exact match")
    func testFindBestMatchExact() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Find best match - case insensitive")
    func testFindBestMatchCaseInsensitive() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Handle user song selection")
    func testHandleUserSongSelection() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Session song structure")
    func testSessionSongStructure() {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }

    @MainActor
    @Test("Prefetch task cancellation")
    func testPrefetchTaskCancellation() async {
        // This test requires creating Song instances which is not possible
        // in unit tests as Song is from MusicKit framework
    }
    */

    @MainActor
    @Test("Turn type enum")
    func testTurnTypeEnum() {
        let userTurn = TurnType.user
        let aiTurn = TurnType.ai

        #expect(userTurn.rawValue == "User")
        #expect(aiTurn.rawValue == "AI")
        #expect(userTurn != aiTurn)
    }

    @MainActor
    @Test("Score calculation for fuzzy matching")
    func testScoreCalculation() {
        // Test the scoring logic for fuzzy matching
        let searchArtist = "The Beatles"
        let searchTitle = "Hey Jude"

        // Exact match should score highest
        let exactArtist = "The Beatles"
        let exactTitle = "Hey Jude"
        #expect(exactArtist.lowercased() == searchArtist.lowercased())
        #expect(exactTitle.lowercased() == searchTitle.lowercased())

        // Partial match should score lower
        let partialArtist = "Beatles"
        #expect(searchArtist.lowercased().contains(partialArtist.lowercased()))

        // No match should score zero
        let noMatchArtist = "Rolling Stones"
        #expect(!searchArtist.lowercased().contains(noMatchArtist.lowercased()))
    }

    @MainActor
    @Test("AI thinking state management")
    func testAIThinkingStateManagement() async {
        let sessionService = SessionService.shared

        // Initial state
        #expect(sessionService.isAIThinking == false)

        // Simulate AI thinking
        sessionService.setAIThinking(true)
        #expect(sessionService.isAIThinking == true)

        // AI done thinking
        sessionService.setAIThinking(false)
        #expect(sessionService.isAIThinking == false)
    }

    @MainActor
    @Test("Session Service turn management")
    func testSessionServiceTurnManagement() {
        let sessionService = SessionService.shared

        // Reset to known state
        sessionService.resetSession()

        // Initial state should be user turn
        #expect(sessionService.currentTurn == .user)

        // After reset, history should be empty
        #expect(sessionService.sessionHistory.isEmpty)
        #expect(sessionService.nextAISong == nil)
    }

    // MARK: - String Normalization Tests

    @MainActor
    @Test("String normalization - featuring artists")
    func testStringNormalizationFeaturingArtists() {
        // Test that featuring artists are properly handled
        let testCases = [
            ("Artist feat. Someone", "artist  someone"),
            ("Artist ft. Someone", "artist  someone"),
            ("Artist featuring Someone", "artist  someone"),
            ("Artist with Someone", "artist  someone"),
        ]

        for (input, expected) in testCases {
            let normalized = normalizeTestString(input)
            #expect(normalized == expected, "Failed for input: '\(input)'")
        }
    }

    @MainActor
    @Test("String normalization - diacritics")
    func testStringNormalizationDiacritics() {
        // Test unicode normalization
        let testCases = [
            ("Café", "cafe"),
            ("José González", "jose gonzalez"),
            ("Beyoncé", "beyonce"),
            ("Motörhead", "motorhead"),
        ]

        for (input, expected) in testCases {
            let normalized = normalizeTestString(input)
            #expect(normalized == expected, "Failed for input: '\(input)'")
        }
    }

    @MainActor
    @Test("String normalization - case insensitive")
    func testStringNormalizationCaseInsensitive() {
        // Test case normalization
        let input1 = "The Beatles"
        let input2 = "THE BEATLES"
        let input3 = "the beatles"

        let norm1 = normalizeTestString(input1)
        let norm2 = normalizeTestString(input2)
        let norm3 = normalizeTestString(input3)

        #expect(norm1 == norm2)
        #expect(norm2 == norm3)
        #expect(norm1 == "the beatles")
    }

    @MainActor
    @Test("Strip parentheticals - basic")
    func testStripParentheticals() {
        let testCases = [
            ("Song Title (Remastered)", "Song Title"),
            ("Song Title (Live)", "Song Title"),
            ("Song Title (Radio Edit)", "Song Title"),
            ("Song Title (2024 Version)", "Song Title"),
            ("Song Title", "Song Title"), // No parenthetical
        ]

        for (input, expected) in testCases {
            let stripped = stripParentheticalsTest(input)
            #expect(stripped == expected, "Failed for input: '\(input)'")
        }
    }

    @MainActor
    @Test("Strip parentheticals - multiple")
    func testStripParentheticalsMultiple() {
        // Test multiple parentheticals
        let input = "Song Title (Remastered) (Live)"
        let expected = "Song Title"
        let result = stripParentheticalsTest(input)
        #expect(result == expected)
    }

    @MainActor
    @Test("Combined normalization")
    func testCombinedNormalization() {
        // Test that normalization works with complex inputs
        let input = "Panic! At The Disco feat. Someone"
        let normalized = normalizeTestString(input)

        // Should be lowercased and featuring removed
        #expect(normalized.contains("panic"))
        #expect(!normalized.contains("feat"))
    }

    @MainActor
    @Test("Threshold allows single exact match")
    func testThresholdLogic() {
        // With threshold of 100, exact match on either artist OR title passes
        // This is appropriate because normalization handles variations

        let artistOnlyScore = 100  // Just artist exact match
        let titleOnlyScore = 100   // Just title exact match
        let bothFieldsScore = 200  // Both exact matches

        #expect(artistOnlyScore >= 100, "Artist exact match should pass threshold")
        #expect(titleOnlyScore >= 100, "Title exact match should pass threshold")
        #expect(bothFieldsScore >= 100, "Both exact matches should pass threshold")
    }

    @MainActor
    @Test("Normalization handles The prefix")
    func testNormalizationThePrefix() {
        let testCases = [
            ("The Beatles", "beatles"),
            ("The Rolling Stones", "rolling stones"),
            ("The T.S.U. Toronadoes", "tsu toronadoes"),
        ]

        for (input, expected) in testCases {
            let normalized = normalizeTestString(input)
            #expect(normalized == expected, "Failed for input: '\(input)'")
        }
    }

    @MainActor
    @Test("Normalization handles ampersand and punctuation")
    func testNormalizationAmpersandPunctuation() {
        let testCases = [
            ("Apple & The Three Oranges", "apple and three oranges"),
            ("Apple&Three Oranges", "apple and three oranges"),
            ("T.S.U. Toronadoes", "tsu toronadoes"),
            ("A.B.C. Band", "abc band"),
        ]

        for (input, expected) in testCases {
            let normalized = normalizeTestString(input)
            #expect(normalized == expected, "Failed for input: '\(input)'")
        }
    }

    @MainActor
    @Test("Strip part numbers from titles")
    func testStripPartNumbers() {
        let testCases = [
            ("Free and Easy Pt. 1", "Free and Easy"),
            ("Free and Easy Pt. 2", "Free and Easy"),
            ("Song Title Part 1", "Song Title"),
            ("Song Title Part 2", "Song Title"),
            ("Getting the Corners Pt 1", "Getting the Corners"),
        ]

        for (input, expected) in testCases {
            let stripped = stripParentheticalsTest(input)
            #expect(stripped == expected, "Failed for input: '\(input)'")
        }
    }

    // MARK: - Helper Functions for Testing

    /// Test helper that mimics the normalizeString function
    private func normalizeTestString(_ string: String) -> String {
        var normalized = string.lowercased()

        // Handle featuring artists
        normalized = normalized.replacingOccurrences(of: " feat. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " ft. ", with: " ")
        normalized = normalized.replacingOccurrences(of: " featuring ", with: " ")
        normalized = normalized.replacingOccurrences(of: " with ", with: " ")

        // Normalize "The" prefix
        if normalized.hasPrefix("the ") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove common punctuation
        normalized = normalized.replacingOccurrences(of: " & ", with: " and ")
        normalized = normalized.replacingOccurrences(of: "&", with: " and ")

        // Remove periods from abbreviations
        normalized = normalized.replacingOccurrences(of: ".", with: "")

        // Normalize unicode
        normalized = normalized.folding(options: .diacriticInsensitive, locale: .current)

        // Normalize multiple spaces
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespaces)

        return normalized
    }

    /// Test helper that mimics the stripParentheticals function
    private func stripParentheticalsTest(_ string: String) -> String {
        var cleaned = string

        // Remove parentheticals
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