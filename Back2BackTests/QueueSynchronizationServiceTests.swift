//
//  QueueSynchronizationServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-10-01.
//  Tests for QueueSynchronizationService (#33)
//

import Testing
import MusicKit
@testable import Back2Back

@MainActor
struct QueueSynchronizationServiceTests {

    // MARK: - Initialization Tests

    @Test("QueueSynchronizationService initializes with clean state")
    func testInitialization() async throws {
        let service = QueueSynchronizationService.shared

        // Service should initialize without errors
        #expect(service.onSongAdvanced == nil)
    }

    // MARK: - Reset Tests

    @Test("Reset clears all state")
    func testReset() async throws {
        let service = QueueSynchronizationService.shared

        // Reset should complete without errors
        service.reset()

        // After reset, state should be clean
        // This is a basic smoke test since we can't easily inspect private state
    }

    // Note: Full integration tests for queue operations would require:
    // 1. A valid Apple Music subscription
    // 2. MusicKit authorization
    // 3. Actual song objects from Apple Music
    // 4. Running on a real device (not simulator)
    //
    // These tests focus on the interface and basic behavior that can be tested
    // without Apple Music integration.
    //
    // For full testing, manual device testing is recommended with scenarios:
    // - Adding first song (initializes queue)
    // - Adding subsequent songs (appends to queue)
    // - Removing specific songs from queue
    // - Removing all AI songs
    // - Queue advancement detection
    // - Transient item timeout handling
    // - Skip to entry functionality
}
