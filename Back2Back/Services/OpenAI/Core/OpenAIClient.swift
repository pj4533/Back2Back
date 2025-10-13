import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class OpenAIClient: AIRecommendationServiceProtocol {
    private(set) var config: OpenAIConfig
    let session: URLSession
    private let songSelectionService: SongSelectionService
    private let personaGenerationService: PersonaGenerationService

    init(
        config: OpenAIConfig,
        session: URLSession? = nil,
        songSelectionService: SongSelectionService,
        personaGenerationService: PersonaGenerationService
    ) {
        if let providedSession = session {
            self.session = providedSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 0
            configuration.timeoutIntervalForResource = 0
            self.session = URLSession(configuration: configuration)
        }
        self.config = config
        self.songSelectionService = songSelectionService
        self.personaGenerationService = personaGenerationService
        B2BLog.ai.debug("OpenAIClient initialized")
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
        try await songSelectionService.selectNextSong(
            persona: persona,
            personaId: personaId,
            sessionHistory: sessionHistory,
            directionChange: directionChange,
            config: config,
            client: self
        )
    }

    func generateDirectionChange(persona: String, sessionHistory: [SessionSong], previousDirection: DirectionChange? = nil) async throws -> DirectionChange {
        try await songSelectionService.generateDirectionChange(
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
        try await personaGenerationService.generatePersonaStyleGuide(
            name: name,
            description: description,
            onStatusUpdate: onStatusUpdate,
            client: self
        )
    }

    func simpleCompletion(prompt: String, model: String = "gpt-5") async throws -> String {
        try await songSelectionService.simpleCompletion(
            prompt: prompt,
            model: model,
            client: self
        )
    }
}
