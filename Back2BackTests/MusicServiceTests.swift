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
        let instance1 = MusicService.shared
        let instance2 = MusicService.shared
        #expect(instance1 === instance2)
    }

    @Test func initialAuthorizationStatusIsNotDetermined() async throws {
        let service = MusicService.shared
        #expect(service.authorizationStatus == MusicAuthorization.currentStatus)
    }

    @Test func searchWithEmptyTermReturnsEmptyResults() async throws {
        let service = MusicService.shared
        let results = try await service.searchCatalog(for: "")
        #expect(results.isEmpty)
        #expect(service.searchResults.isEmpty)
    }

    @Test func searchWithEmptyTermDoesNotTriggerSearching() async throws {
        let service = MusicService.shared
        _ = try await service.searchCatalog(for: "")
        #expect(!service.isSearching)
    }

    @Test func clearQueueRemovesAllSongs() async throws {
        let service = MusicService.shared
        service.clearQueue()
        let queueIsEmpty = service.currentlyPlaying == nil
        #expect(queueIsEmpty)
    }

    @Test func playbackStateInitiallyIsStopped() async throws {
        let service = MusicService.shared
        #expect(service.playbackState == .stopped)
    }

    @Test func isAuthorizedReflectsAuthorizationStatus() async throws {
        let service = MusicService.shared
        let expectedAuthorized = service.authorizationStatus == .authorized
        #expect(service.isAuthorized == expectedAuthorized)
    }
}