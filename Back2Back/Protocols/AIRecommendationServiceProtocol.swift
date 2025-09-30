import Foundation

@MainActor
protocol AIRecommendationServiceProtocol {
    var isConfigured: Bool { get }
    var apiKey: String? { get }

    func reloadConfiguration()
    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], config: AIModelConfig) async throws -> SongRecommendation
    func generatePersonaStyleGuide(name: String, description: String, onStatusUpdate: ((String) async -> Void)?) async throws -> PersonaGenerationResult
    func simpleCompletion(prompt: String, model: String) async throws -> String
}
