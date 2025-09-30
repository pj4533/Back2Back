import Foundation
@testable import Back2Back

@MainActor
class MockAIRecommendationService: AIRecommendationServiceProtocol {
    var isConfigured: Bool = true
    var apiKey: String? = "mock-api-key"

    var reloadConfigurationCalled = false
    var selectNextSongCalled = false
    var generatePersonaStyleGuideCalled = false
    var simpleCompletionCalled = false

    var mockRecommendation: SongRecommendation?
    var mockPersonaResult: PersonaGenerationResult?
    var mockCompletionResult: String = "Mock completion"

    func reloadConfiguration() {
        reloadConfigurationCalled = true
    }

    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], config: AIModelConfig = .default) async throws -> SongRecommendation {
        selectNextSongCalled = true
        return mockRecommendation ?? SongRecommendation(
            artist: "Mock Artist",
            song: "Mock Song",
            rationale: "Mock rationale"
        )
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
