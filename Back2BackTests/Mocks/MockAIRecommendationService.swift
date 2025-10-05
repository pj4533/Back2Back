import Foundation
@testable import Back2Back

@MainActor
class MockAIRecommendationService: AIRecommendationServiceProtocol {
    var isConfigured: Bool = true
    var apiKey: String? = "mock-api-key"

    var reloadConfigurationCalled = false
    var selectNextSongCalled = false
    var generatePersonaStyleGuideCalled = false
    var generateDirectionChangeCalled = false
    var simpleCompletionCalled = false

    var mockRecommendation: SongRecommendation?
    var mockPersonaResult: PersonaGenerationResult?
    var mockDirectionChange: DirectionChange?
    var mockCompletionResult: String = "Mock completion"

    func reloadConfiguration() {
        reloadConfigurationCalled = true
    }

    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], directionChange: DirectionChange? = nil, config: AIModelConfig = .default) async throws -> SongRecommendation {
        selectNextSongCalled = true
        return mockRecommendation ?? SongRecommendation(
            artist: "Mock Artist",
            song: "Mock Song",
            rationale: "Mock rationale"
        )
    }

    func generateDirectionChange(persona: String, sessionHistory: [SessionSong], previousDirection: DirectionChange? = nil) async throws -> DirectionChange {
        generateDirectionChangeCalled = true
        return mockDirectionChange ?? DirectionChange(options: [
            DirectionOption(directionPrompt: "Mock direction prompt 1", buttonLabel: "Mock option 1"),
            DirectionOption(directionPrompt: "Mock direction prompt 2", buttonLabel: "Mock option 2")
        ])
    }

    func generatePersonaStyleGuide(name: String, description: String, onStatusUpdate: ((String) async -> Void)? = nil) async throws -> PersonaGenerationResult {
        generatePersonaStyleGuideCalled = true
        await onStatusUpdate?("Generating...")
        await onStatusUpdate?("Complete!")
        return mockPersonaResult ?? PersonaGenerationResult(
            name: name,
            styleGuide: "Mock style guide for \(name)",
            sources: ["https://example.com"]
        )
    }

    func simpleCompletion(prompt: String, model: String = "gpt-5") async throws -> String {
        simpleCompletionCalled = true
        return mockCompletionResult
    }
}
