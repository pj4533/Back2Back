import Foundation
import Observation

@MainActor
@Observable
final class AppDependencies {
    let environmentService: EnvironmentService
    let toastService: ToastService
    let statusMessageService: StatusMessageService
    let personaSongCacheService: PersonaSongCacheService
    let songErrorLoggerService: SongErrorLoggerService
    let favoritesService: FavoritesService
    let personaService: PersonaService
    let musicService: MusicService
    let sessionService: SessionService
    let openAINetworking: OpenAINetworking
    let openAIStreaming: OpenAIStreaming
    let songSelectionService: SongSelectionService
    let personaGenerationService: PersonaGenerationService
    let openAIClient: OpenAIClient
    let playbackCoordinator: PlaybackCoordinator
    let turnManager: TurnManager
    let aiSongCoordinator: AISongCoordinator
    let sessionViewModel: SessionViewModel
    let personasViewModel: PersonasViewModel
    let musicAuthViewModel: MusicAuthViewModel

    init() {
        environmentService = EnvironmentService()
        toastService = ToastService()
        statusMessageService = StatusMessageService()
        personaSongCacheService = PersonaSongCacheService()
        songErrorLoggerService = SongErrorLoggerService()
        favoritesService = FavoritesService()
        personaService = PersonaService(statusMessageService: statusMessageService)
        let authService = MusicAuthService()
        let searchService = MusicSearchService()
        let playbackService = MusicPlaybackService()
        musicService = MusicService(
            authService: authService,
            searchService: searchService,
            playbackService: playbackService
        )
        let historyService = SessionHistoryService()
        let queueManager = QueueManager()
        sessionService = SessionService(
            personaService: personaService,
            historyService: historyService,
            queueManager: queueManager
        )
        openAINetworking = OpenAINetworking()
        openAIStreaming = OpenAIStreaming()
        songSelectionService = SongSelectionService(
            networking: openAINetworking,
            personaSongCacheService: personaSongCacheService
        )
        personaGenerationService = PersonaGenerationService(streaming: openAIStreaming)
        let openAIConfig = OpenAIConfig(environmentService: environmentService)
        openAIClient = OpenAIClient(
            config: openAIConfig,
            songSelectionService: songSelectionService,
            personaGenerationService: personaGenerationService
        )
        playbackCoordinator = PlaybackCoordinator(
            musicService: musicService,
            sessionService: sessionService
        )
        turnManager = TurnManager(
            sessionService: sessionService,
            musicService: musicService
        )
        aiSongCoordinator = AISongCoordinator(
            openAIClient: openAIClient,
            sessionService: sessionService,
            environmentService: environmentService,
            musicService: musicService,
            personaService: personaService,
            personaSongCacheService: personaSongCacheService,
            songErrorLoggerService: songErrorLoggerService,
            toastService: toastService
        )
        sessionViewModel = SessionViewModel(
            musicService: musicService,
            sessionService: sessionService,
            openAIClient: openAIClient,
            playbackCoordinator: playbackCoordinator,
            aiSongCoordinator: aiSongCoordinator,
            turnManager: turnManager
        )
        personasViewModel = PersonasViewModel(
            personaService: personaService,
            aiService: openAIClient
        )
        musicAuthViewModel = MusicAuthViewModel(musicService: musicService)
    }
}
