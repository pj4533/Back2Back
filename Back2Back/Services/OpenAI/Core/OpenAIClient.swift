import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class OpenAIClient: AIRecommendationServiceProtocol {
    static let shared = OpenAIClient()

    private(set) var config: OpenAIConfig
    let session: URLSession
    private static var isInitialized = false

    private init() {
        let configuration = URLSessionConfiguration.default
        // Disable timeouts for AI generation - web search can take very long
        configuration.timeoutIntervalForRequest = 0  // No timeout
        configuration.timeoutIntervalForResource = 0  // No timeout
        self.session = URLSession(configuration: configuration)
        self.config = OpenAIConfig()

        // Prevent duplicate initialization logs
        if !Self.isInitialized {
            B2BLog.ai.debug("OpenAIClient initialized (singleton)")
            Self.isInitialized = true
        }
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        config.isConfigured
    }

    var apiKey: String? {
        config.apiKey
    }

    func reloadConfiguration() {
        config.reload()
    }

    // MARK: - Feature Services

    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], directionChange: DirectionChange? = nil, config: AIModelConfig = .default) async throws -> SongRecommendation {
        try await SongSelectionService.shared.selectNextSong(
            persona: persona,
            personaId: personaId,
            sessionHistory: sessionHistory,
            directionChange: directionChange,
            config: config,
            client: self
        )
    }

    func generateDirectionChange(persona: String, sessionHistory: [SessionSong], previousDirection: DirectionChange? = nil) async throws -> DirectionChange {
        try await SongSelectionService.shared.generateDirectionChange(
            persona: persona,
            sessionHistory: sessionHistory,
            previousDirection: previousDirection,
            client: self
        )
    }

    func generatePersonaStyleGuide(
        name: String,
        description: String,
        onStatusUpdate: ((String) async -> Void)? = nil
    ) async throws -> PersonaGenerationResult {
        try await PersonaGenerationService.shared.generatePersonaStyleGuide(
            name: name,
            description: description,
            onStatusUpdate: onStatusUpdate,
            client: self
        )
    }

    func simpleCompletion(prompt: String, model: String = "gpt-5") async throws -> String {
        try await SongSelectionService.shared.simpleCompletion(
            prompt: prompt,
            model: model,
            client: self
        )
    }
}
