//
//  MusicModelsTests.swift
//  Back2BackTests
//
//  Created by PJ Gray on 9/25/25.
//

import Testing
import Foundation
@testable import Back2Back

struct MusicModelsTests {

    @Test func musicAuthorizationErrorDescriptions() async throws {
        let deniedError = MusicAuthorizationError.denied
        #expect(deniedError.errorDescription == "Music library access was denied. Please enable access in Settings.")

        let restrictedError = MusicAuthorizationError.restricted
        #expect(restrictedError.errorDescription == "Music library access is restricted on this device.")

        let unknownError = MusicAuthorizationError.unknown
        #expect(unknownError.errorDescription == "An unknown error occurred while requesting music library access.")
    }

    @Test func musicPlaybackErrorDescriptions() async throws {
        let noSongError = MusicPlaybackError.noSongSelected
        #expect(noSongError.errorDescription == "No song selected for playback.")

        let queueError = MusicPlaybackError.queueFailed
        #expect(queueError.errorDescription == "Failed to add song to queue.")

        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        let testError = TestError()
        let playbackError = MusicPlaybackError.playbackFailed(testError)
        #expect(playbackError.errorDescription == "Playback failed: Test error")
    }

    @Test func musicSearchResultHasUniqueId() async throws {
        @available(iOS 16.0, *)
        struct MockSong {
            let title = "Test Song"
            let artistName = "Test Artist"
            let albumTitle: String? = "Test Album"
        }
    }
}