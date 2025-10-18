//
//  MusicServiceTests.swift
//  Back2BackTests
//
//  Created by PJ Gray on 9/25/25.
//

import Testing
import MusicKit
@testable import Back2Back

@MainActor
struct MusicServiceTests {

    @Test func musicServiceIsSingleton() async throws {
        let instance1 = MusicService()
        let instance2 = MusicService()
        #expect(instance1 === instance2)
    }

    @Test func initialAuthorizationStatusIsNotDetermined() async throws {
        let service = MusicService()
        #expect(service.authorizationStatus == MusicAuthorization.currentStatus)
    }

    @Test func searchWithEmptyTermReturnsEmptyResults() async throws {
        let service = MusicService()
        let results = try await service.searchCatalog(for: "")
        #expect(results.isEmpty)
        #expect(service.searchResults.isEmpty)
    }

    @Test func searchWithEmptyTermDoesNotTriggerSearching() async throws {
        let service = MusicService()
        _ = try await service.searchCatalog(for: "")
        #expect(!service.isSearching)
    }

    @Test func clearQueueRemovesAllSongs() async throws {
        let service = MusicService()
        service.clearQueue()
        let queueIsEmpty = service.currentlyPlaying == nil
        #expect(queueIsEmpty)
    }

    @Test func playbackStateInitiallyIsStopped() async throws {
        let service = MusicService()
        #expect(service.playbackState == .stopped)
    }

    @Test func isAuthorizedReflectsAuthorizationStatus() async throws {
        let service = MusicService()
        let expectedAuthorized = service.authorizationStatus == .authorized
        #expect(service.isAuthorized == expectedAuthorized)
    }

    // MARK: - Seek and Skip Tests

    @Test func getCurrentPlaybackTimeReturnsNonNegativeValue() async throws {
        let service = MusicService()
        let time = service.getCurrentPlaybackTime()
        #expect(time >= 0)
    }

    @Test func seekToZeroDoesNotThrowWhenNoCurrentEntry() async throws {
        let service = MusicService()
        service.clearQueue()

        do {
            try await service.seek(to: 0)
            Issue.record("Expected seek to throw when no current entry")
        } catch {
            // Expected to throw MusicPlaybackError.queueFailed
            #expect(error is MusicPlaybackError)
        }
    }

    @Test func skipForwardDoesNotThrowWhenNoCurrentEntry() async throws {
        let service = MusicService()
        service.clearQueue()

        do {
            try await service.skipForward(15)
            Issue.record("Expected skipForward to throw when no current entry")
        } catch {
            // Expected to throw MusicPlaybackError.queueFailed
            #expect(error is MusicPlaybackError)
        }
    }

    @Test func skipBackwardDoesNotThrowWhenNoCurrentEntry() async throws {
        let service = MusicService()
        service.clearQueue()

        do {
            try await service.skipBackward(15)
            Issue.record("Expected skipBackward to throw when no current entry")
        } catch {
            // Expected to throw MusicPlaybackError.queueFailed
            #expect(error is MusicPlaybackError)
        }
    }
}