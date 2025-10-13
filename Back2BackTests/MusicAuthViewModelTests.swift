//
//  MusicAuthViewModelTests.swift
//  Back2BackTests
//
//  Created by PJ Gray on 9/25/25.
//

import Testing
import MusicKit
@testable import Back2Back

@MainActor
struct MusicAuthViewModelTests {
    private func makeViewModel() -> MusicAuthViewModel {
        let musicService = MusicService(
            authService: MusicAuthService(),
            searchService: MusicSearchService(),
            playbackService: MusicPlaybackService()
        )
        return MusicAuthViewModel(musicService: musicService)
    }

    @Test func viewModelInitializesWithCurrentStatus() async throws {
        let viewModel = makeViewModel()
        #expect(viewModel.authorizationStatus == MusicAuthorization.currentStatus)
    }

    @Test func isAuthorizedReflectsAuthorizationStatus() async throws {
        let viewModel = makeViewModel()
        let expectedAuthorized = viewModel.authorizationStatus == .authorized
        #expect(viewModel.isAuthorized == expectedAuthorized)
    }

    @Test func statusDescriptionForNotDetermined() async throws {
        let viewModel = makeViewModel()
        if viewModel.authorizationStatus == .notDetermined {
            #expect(viewModel.statusDescription == "Music access has not been requested yet.")
        }
    }

    @Test func statusDescriptionForAuthorized() async throws {
        let viewModel = makeViewModel()
        if viewModel.authorizationStatus == .authorized {
            #expect(viewModel.statusDescription == "Music access is authorized.")
        }
    }

    @Test func canRequestAuthorizationOnlyWhenNotDetermined() async throws {
        let viewModel = makeViewModel()
        let canRequest = viewModel.authorizationStatus == .notDetermined && !viewModel.isRequestingAuthorization
        #expect(viewModel.canRequestAuthorization == canRequest)
    }

    @Test func shouldShowSettingsButtonOnlyWhenDenied() async throws {
        let viewModel = makeViewModel()
        let shouldShow = viewModel.authorizationStatus == .denied
        #expect(viewModel.shouldShowSettingsButton == shouldShow)
    }

    @Test func initialErrorMessageIsNil() async throws {
        let viewModel = makeViewModel()
        #expect(viewModel.errorMessage == nil)
    }

    @Test func isRequestingAuthorizationInitiallyFalse() async throws {
        let viewModel = makeViewModel()
        #expect(!viewModel.isRequestingAuthorization)
    }
}
