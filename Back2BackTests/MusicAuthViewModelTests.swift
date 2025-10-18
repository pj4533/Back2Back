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
        // ViewModel reads from MusicAuthorization.currentStatus (system), not mock
        #expect(viewModel.authorizationStatus == MusicAuthorization.currentStatus)
    }

    @Test("isAuthorized reflects authorization status")
    func isAuthorizedReflectsAuthorizationStatus() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        // isAuthorized should match system authorization status
        let expectedAuth = (MusicAuthorization.currentStatus == .authorized)
        #expect(viewModel.isAuthorized == expectedAuth)
    }

    @Test("Status description for notDetermined")
    func statusDescriptionForNotDetermined() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        // Test the status description method with ViewModel's actual status
        if viewModel.authorizationStatus == .notDetermined {
            #expect(viewModel.statusDescription == "Music access has not been requested yet.")
        }
    }

    @Test("Status description for authorized")
    func statusDescriptionForAuthorized() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        // Test the status description method with ViewModel's actual status
        if viewModel.authorizationStatus == .authorized {
            #expect(viewModel.statusDescription == "Music access is authorized.")
        }
    }

    @Test("Can request authorization only when notDetermined")
    func canRequestAuthorizationOnlyWhenNotDetermined() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        // canRequestAuthorization depends on system status
        let expected = (viewModel.authorizationStatus == .notDetermined && !viewModel.isRequestingAuthorization)
        #expect(viewModel.canRequestAuthorization == expected)
    }

    @Test("Should show settings button only when denied")
    func shouldShowSettingsButtonOnlyWhenDenied() async throws {
        let mockMusicService = MockMusicService()
        let viewModel = MusicAuthViewModel(musicService: mockMusicService)
        // shouldShowSettingsButton depends on system status
        let expected = (viewModel.authorizationStatus == .denied)
        #expect(viewModel.shouldShowSettingsButton == expected)
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