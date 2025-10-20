import Foundation
import MusicKit

@MainActor
protocol AIRecommendationServiceProtocol {
    var isConfigured: Bool { get }
    var apiKey: String? { get }

    func reloadConfiguration()
    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], directionChange: DirectionChange?, config: AIModelConfig) async throws -> SongRecommendation
    func generateDirectionChange(persona: String, sessionHistory: [SessionSong], previousDirection: DirectionChange?) async throws -> DirectionChange
    func generatePersonaCommentary(persona: String, userSelection: Song, sessionHistory: [SessionSong], config: AIModelConfig) async throws -> String
    func generatePersonaStyleGuide(name: String, description: String, onStatusUpdate: ((String) async -> Void)?) async throws -> PersonaGenerationResult
    func simpleCompletion(prompt: String, model: String) async throws -> String
}
