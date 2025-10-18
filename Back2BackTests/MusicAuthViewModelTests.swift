//
//  MusicAuthViewModelTests.swift
//  Back2BackTests
//
//  Created by PJ Gray on 9/25/25.
//

import Testing
import MusicKit
@testable import Back2Back

@Suite("MusicAuthViewModel Tests")
@MainActor
struct MusicAuthViewModelTests {

    @Test("ViewModel initializes with current status")
    func viewModelInitializesWithCurrentStatus() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.authorizationStatus == mockMusicService.authorizationStatus)
    }

    @Test("isAuthorized reflects authorization status")
    func isAuthorizedReflectsAuthorizationStatus() async throws {
        let mockMusicService = MockMusicService()
        mockMusicService.authorizationStatus = .authorized
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.isAuthorized == true)
    }

    @Test("Status description for notDetermined")
    func statusDescriptionForNotDetermined() async throws {
        let mockMusicService = MockMusicService()
        mockMusicService.authorizationStatus = .notDetermined
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.statusDescription == "Music access has not been requested yet.")
    }

    @Test("Status description for authorized")
    func statusDescriptionForAuthorized() async throws {
        let mockMusicService = MockMusicService()
        mockMusicService.authorizationStatus = .authorized
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.statusDescription == "Music access is authorized.")
    }

    @Test("Can request authorization only when notDetermined")
    func canRequestAuthorizationOnlyWhenNotDetermined() async throws {
        let mockMusicService = MockMusicService()
        mockMusicService.authorizationStatus = .notDetermined
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.canRequestAuthorization == true)
    }

    @Test("Should show settings button only when denied")
    func shouldShowSettingsButtonOnlyWhenDenied() async throws {
        let mockMusicService = MockMusicService()
        mockMusicService.authorizationStatus = .denied
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.shouldShowSettingsButton == true)
    }

    @Test("Initial error message is nil")
    func initialErrorMessageIsNil() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Is requesting authorization initially false")
    func isRequestingAuthorizationInitiallyFalse() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        #expect(!viewModel.isRequestingAuthorization)
    }
}