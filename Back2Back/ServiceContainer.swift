//
//  ServiceContainer.swift
//  Back2Back
//
//  Created on 2025-10-13.
//  Part of singleton elimination refactoring (Issue #52)
//

import Foundation
import SwiftUI
import OSLog

/// Central dependency injection container for all app services
/// Eliminates singleton anti-pattern by managing service lifecycles and dependencies
@MainActor
@Observable
final class ServiceContainer {

    // MARK: - Core Services (no dependencies)

    let environmentService: EnvironmentService
    let personaSongCacheService: PersonaSongCacheService
    let toastService: ToastService
    let favoritesService: FavoritesService
    let songErrorLoggerService: SongErrorLoggerService
    let songDebugService: SongDebugService

    // MARK: - OpenAI Services (depends on EnvironmentService)

    let openAIClient: OpenAIClient

    // MARK: - Service Layer (depends on OpenAI)

    let statusMessageService: StatusMessageService
    let personaService: PersonaService

    // MARK: - Music Services (no external dependencies)

    let musicService: MusicService

    // MARK: - Session Services (depends on PersonaService)

    let sessionService: SessionService

    // MARK: - Coordinators (depends on multiple services)

    let playbackCoordinator: PlaybackCoordinator
    let turnManager: TurnManager
    let aiSongCoordinator: AISongCoordinator

    // MARK: - Cache Services (depends on coordinators)

    let firstSongCacheService: FirstSongCacheService

    // MARK: - ViewModels (depends on services and coordinators)

    let sessionViewModel: SessionViewModel
    let personasViewModel: PersonasViewModel
    let contentViewModel: ContentViewModel
    let sessionHeaderViewModel: SessionHeaderViewModel
    let sessionHistoryViewModel: SessionHistoryViewModel
    let sessionActionButtonsViewModel: SessionActionButtonsViewModel
    let favoritesViewModel: FavoritesViewModel

    // MARK: - Initialization

    init() {
        B2BLog.general.info("🏗️ Initializing ServiceContainer with dependency injection")

        // Step 1: Initialize services with no dependencies
        environmentService = EnvironmentService()
        personaSongCacheService = PersonaSongCacheService()
        toastService = ToastService()
        favoritesService = FavoritesService()
        songErrorLoggerService = SongErrorLoggerService()
        songDebugService = SongDebugService()

        B2BLog.general.debug("✅ Core services initialized")

        // Step 2: Initialize OpenAI client (depends on EnvironmentService and PersonaSongCacheService)
        openAIClient = OpenAIClient(
            environmentService: environmentService,
            personaSongCacheService: personaSongCacheService
        )

        B2BLog.general.debug("✅ OpenAI client initialized")

        // Step 3: Initialize services that depend on OpenAI
        statusMessageService = StatusMessageService(openAIClient: openAIClient)
        personaService = PersonaService(statusMessageService: statusMessageService)

        B2BLog.general.debug("✅ Persona and status services initialized")

        // Step 4: Initialize music service
        musicService = MusicService()

        B2BLog.general.debug("✅ Music service initialized")

        // Step 5: Initialize session service (depends on PersonaService)
        sessionService = SessionService(personaService: personaService)

        B2BLog.general.debug("✅ Session service initialized")

        // Step 6: Initialize coordinators (depend on multiple services)
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
            musicMatcher: nil, // Will use default based on config
            toastService: toastService,
            personaService: personaService,
            personaSongCacheService: personaSongCacheService,
            songErrorLoggerService: songErrorLoggerService,
            songDebugService: songDebugService
        )

        B2BLog.general.debug("✅ Coordinators initialized")

        // Step 6.5: Initialize first song cache service (depends on AISongCoordinator)
        firstSongCacheService = FirstSongCacheService(
            personaService: personaService,
            musicService: musicService,
            aiSongCoordinator: aiSongCoordinator
        )

        B2BLog.general.debug("✅ First song cache service initialized")

        // Step 7: Initialize view models (depend on services and coordinators)
        sessionViewModel = SessionViewModel(
            musicService: musicService,
            sessionService: sessionService,
            playbackCoordinator: playbackCoordinator,
            aiSongCoordinator: aiSongCoordinator,
            turnManager: turnManager,
            openAIClient: openAIClient
        )

        personasViewModel = PersonasViewModel(
            personaService: personaService,
            aiService: openAIClient
        )

        contentViewModel = ContentViewModel(
            musicService: musicService
        )

        sessionHeaderViewModel = SessionHeaderViewModel(
            sessionService: sessionService,
            musicService: musicService
        )

        sessionHistoryViewModel = SessionHistoryViewModel(
            sessionService: sessionService
        )

        sessionActionButtonsViewModel = SessionActionButtonsViewModel(
            sessionService: sessionService,
            personaService: personaService
        )

        favoritesViewModel = FavoritesViewModel(
            favoritesService: favoritesService
        )

        B2BLog.general.info("✅ ServiceContainer fully initialized - All dependencies injected")
    }

    // MARK: - Helper Methods

    /// Create appropriate music matcher based on configuration
    private static func createMusicMatcher(
        musicService: MusicService,
        personaService: PersonaService,
        songErrorLoggerService: SongErrorLoggerService
    ) -> MusicMatchingProtocol {
        // Read configuration to determine which matcher to use
        let config: AIModelConfig
        if let data = UserDefaults.standard.data(forKey: "aiModelConfig"),
           let decoded = try? JSONDecoder().decode(AIModelConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
        }

        switch config.musicMatcher {
        case .stringBased:
            return StringBasedMusicMatcher(
                musicService: musicService,
                personaService: personaService,
                songErrorLoggerService: songErrorLoggerService
            )
        case .llmBased:
            return LLMBasedMusicMatcher(
                musicService: musicService,
                personaService: personaService,
                songErrorLoggerService: songErrorLoggerService
            )
        }
    }

    // MARK: - Configuration Helper

    /// Check OpenAI configuration status
    func checkOpenAIConfiguration() {
        if openAIClient.isConfigured {
            B2BLog.ai.info("✅ OpenAI API key configured")
        } else {
            B2BLog.ai.warning("⚠️ OpenAI API key not configured")
            B2BLog.ai.warning("Set OPENAI_API_KEY in your Xcode scheme's environment variables")
        }
    }

    /// Pregenerate status messages for the selected persona
    func pregenerateStatusMessages() {
        if let selectedPersona = personaService.selectedPersona {
            B2BLog.ai.info("Pregenerating status messages for selected persona: \(selectedPersona.name)")
            statusMessageService.pregenerateMessages(for: selectedPersona)
        } else {
            B2BLog.ai.debug("No persona selected, skipping status message pregeneration")
        }
    }
}

// MARK: - SwiftUI Environment Key

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer? = nil
}

extension EnvironmentValues {
    var services: ServiceContainer? {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

extension View {
    /// Inject the service container into the SwiftUI environment
    func withServices(_ container: ServiceContainer) -> some View {
        self.environment(\.services, container)
    }
}
