import Foundation

@MainActor
protocol AIRecommendationServiceProtocol {
    var isConfigured: Bool { get }
    var apiKey: String? { get }

    func reloadConfiguration()
    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], directionChange: DirectionChange?, config: AIModelConfig) async throws -> SongRecommendation
    func generateDirectionChange(persona: String, sessionHistory: [SessionSong]) async throws -> DirectionChange
    func generatePersonaStyleGuide(name: String, description: String, onStatusUpdate: ((String) async -> Void)?) async throws -> PersonaGenerationResult
    func simpleCompletion(prompt: String, model: String) async throws -> String
}
