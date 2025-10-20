import Foundation
import MusicKit
@testable import Back2Back

/// Mock implementation of AIRecommendationServiceProtocol for testing
/// Provides realistic responses without making actual API calls
@MainActor
class MockAIRecommendationService: AIRecommendationServiceProtocol {
    var isConfigured: Bool = true
    var apiKey: String? = "mock-api-key-test-only"

    // Call tracking
    var reloadConfigurationCalled = false
    var selectNextSongCalled = false
    var generatePersonaStyleGuideCalled = false
    var generateDirectionChangeCalled = false
    var generatePersonaCommentaryCalled = false
    var simpleCompletionCalled = false

    // Configurable mock responses
    var mockRecommendation: SongRecommendation?
    var mockPersonaResult: PersonaGenerationResult?
    var mockDirectionChange: DirectionChange?
    var mockCommentary: String?
    var mockCompletionResult: String = "Mock completion"

    // Error simulation
    var shouldThrowError: Bool = false
    var errorToThrow: Error = OpenAIError.apiKeyMissing

    // Track last call parameters for verification
    var lastPersonaName: String?
    var lastSessionHistory: [SessionSong]?
    var lastDirectionChange: DirectionChange?

    func reloadConfiguration() {
        reloadConfigurationCalled = true
    }

    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], directionChange: DirectionChange? = nil, config: AIModelConfig = .default) async throws -> SongRecommendation {
        selectNextSongCalled = true
        lastPersonaName = persona
        lastSessionHistory = sessionHistory
        lastDirectionChange = directionChange

        if shouldThrowError {
            throw errorToThrow
        }

        // Return configured mock or realistic default
        return mockRecommendation ?? SongRecommendation(
            artist: "The Meters",
            song: "Cissy Strut",
            rationale: "Classic New Orleans funk instrumental with iconic bassline. Perfect for building energy and setting a groove-focused vibe."
        )
    }

    func generateDirectionChange(persona: String, sessionHistory: [SessionSong], previousDirection: DirectionChange? = nil) async throws -> DirectionChange {
        generateDirectionChangeCalled = true
        lastPersonaName = persona
        lastSessionHistory = sessionHistory

        if shouldThrowError {
            throw errorToThrow
        }

        return mockDirectionChange ?? DirectionChange(options: [
            DirectionOption(directionPrompt: "Shift to West Coast psychedelic rock with experimental production and atmospheric textures", buttonLabel: "West Coast vibes"),
            DirectionOption(directionPrompt: "Explore 60s garage rock with raw energy and lo-fi production aesthetic", buttonLabel: "60s garage rock")
        ])
    }

    func generatePersonaCommentary(persona: String, userSelection: Song, sessionHistory: [SessionSong], config: AIModelConfig = .default) async throws -> String {
        generatePersonaCommentaryCalled = true
        lastPersonaName = persona
        lastSessionHistory = sessionHistory

        if shouldThrowError {
            throw errorToThrow
        }

        return mockCommentary ?? "Nice choice! This track really fits the vibe we've been building."
    }

    func generatePersonaStyleGuide(name: String, description: String, onStatusUpdate: ((String) async -> Void)? = nil) async throws -> PersonaGenerationResult {
        generatePersonaStyleGuideCalled = true
        lastPersonaName = name

        if shouldThrowError {
            throw errorToThrow
        }

        // Simulate realistic streaming status updates
        await onStatusUpdate?("Analyzing persona description...")
        await onStatusUpdate?("Searching for musical influences...")
        await onStatusUpdate?("Generating style guide...")
        await onStatusUpdate?("Complete!")

        return mockPersonaResult ?? PersonaGenerationResult(
            name: name,
            styleGuide: """
            # \(name) - DJ Style Guide

            ## Musical Philosophy
            \(description)

            ## Core Characteristics
            - Deep knowledge of rare groove and funk records
            - Focus on building energy through carefully selected transitions
            - Emphasis on instrumental tracks with strong rhythmic elements
            - Appreciation for live instrumentation and organic production

            ## Signature Moves
            - Opening with mid-tempo funk to establish groove
            - Building intensity through percussion-heavy selections
            - Strategic use of breakbeats and samples
            - Closing with uplifting, dance-floor friendly tracks

            ## Influences
            - New Orleans funk (The Meters, Dr. John)
            - Jazz-funk fusion (Herbie Hancock, Roy Ayers)
            - African rhythms (Fela Kuti, Tony Allen)
            - Latin percussion (Willie Bobo, Ray Barretto)
            """,
            sources: [
                "https://example.com/rare-groove-guide",
                "https://example.com/funk-history",
                "https://example.com/dj-techniques"
            ]
        )
    }

    func simpleCompletion(prompt: String, model: String = "gpt-5") async throws -> String {
        simpleCompletionCalled = true

        if shouldThrowError {
            throw errorToThrow
        }

        return mockCompletionResult
    }
}
