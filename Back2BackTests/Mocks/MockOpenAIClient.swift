import Foundation
@testable import Back2Back

@MainActor
class MockOpenAIClient {
    var isConfigured: Bool = true
    var selectSongCalled = false
    var generateDirectionChangeCalled = false
    var generatePersonaStyleGuideCalled = false

    var mockSongRecommendation: SongRecommendation?
    var mockDirectionChange: DirectionChange?
    var mockStyleGuide: String?

    // Track calls
    var lastSelectionHistory: [SessionSong]?
    var lastSelectionPersonaName: String?
    var lastSelectionStyleGuide: String?
}

// Extend MockOpenAIClient to conform to required protocols if needed
extension MockOpenAIClient {
    func selectSong(
        sessionHistory: [SessionSong],
        personaName: String,
        styleGuide: String,
        directionPrompt: String? = nil,
        recentSongs: [String] = []
    ) async throws -> SongRecommendation {
        selectSongCalled = true
        lastSelectionHistory = sessionHistory
        lastSelectionPersonaName = personaName
        lastSelectionStyleGuide = styleGuide

        if let mockSongRecommendation = mockSongRecommendation {
            return mockSongRecommendation
        }

        // Return default mock recommendation
        return SongRecommendation(
            artist: "Mock Artist",
            song: "Mock Song",
            rationale: "Mock rationale"
        )
    }

    func generateDirectionChange(
        sessionHistory: [SessionSong],
        personaName: String,
        styleGuide: String
    ) async throws -> DirectionChange {
        generateDirectionChangeCalled = true

        if let mockDirectionChange = mockDirectionChange {
            return mockDirectionChange
        }

        // Return default mock direction change
        return DirectionChange(
            directionPrompt: "Mock direction prompt",
            buttonLabel: "Mock label"
        )
    }

    func generatePersonaStyleGuide(
        personaName: String,
        influences: [String],
        onProgress: @escaping (String) -> Void
    ) async throws -> String {
        generatePersonaStyleGuideCalled = true

        if let mockStyleGuide = mockStyleGuide {
            onProgress("Generating style guide...")
            return mockStyleGuide
        }

        onProgress("Generating style guide...")
        return "Mock style guide for \(personaName)"
    }
}
