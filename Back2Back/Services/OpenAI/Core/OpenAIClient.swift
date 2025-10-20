import Foundation
import Observation
import OSLog
import MusicKit

@Observable
@MainActor
class OpenAIClient: AIRecommendationServiceProtocol {
    private(set) var config: OpenAIConfig
    let session: URLSession
    private let environmentService: EnvironmentService

    // Feature services
    private let songSelectionService: SongSelectionService
    private let personaGenerationService: PersonaGenerationService
    private let networking: OpenAINetworking
    private let streaming: OpenAIStreaming

    init(environmentService: EnvironmentService, personaSongCacheService: PersonaSongCacheService) {
        self.environmentService = environmentService

        let configuration = URLSessionConfiguration.default
        // Disable timeouts for AI generation - web search can take very long
        configuration.timeoutIntervalForRequest = 0  // No timeout
        configuration.timeoutIntervalForResource = 0  // No timeout
        self.session = URLSession(configuration: configuration)
        self.config = OpenAIConfig(environmentService: environmentService)

        // Initialize feature services
        self.songSelectionService = SongSelectionService(personaSongCacheService: personaSongCacheService)
        self.personaGenerationService = PersonaGenerationService()
        self.networking = OpenAINetworking()
        self.streaming = OpenAIStreaming()

        B2BLog.ai.debug("OpenAIClient initialized with dependency injection")
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

    func generatePersonaCommentary(persona: String, userSelection: Song, sessionHistory: [SessionSong], config: AIModelConfig = .default) async throws -> String {
        try await songSelectionService.generatePersonaCommentary(
            persona: persona,
            userSelection: userSelection,
            sessionHistory: sessionHistory,
            config: config,
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

    // MARK: - Network Access (for feature services)

    func performNetworkRequest(_ request: ResponsesRequest) async throws -> ResponsesResponse {
        try await networking.responses(request: request, client: self)
    }

    func performStreamingRequest(
        _ request: ResponsesRequest,
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws -> ResponsesResponse {
        try await streaming.streamingResponses(request: request, client: self, onEvent: onEvent)
    }
}
