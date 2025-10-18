import Foundation
import MusicKit
@testable import Back2Back

@MainActor
class MockPlaybackCoordinator {
    var onSongEnded: (() async -> Void)?
    var startMonitoringCalled = false
    var stopMonitoringCalled = false

    func startMonitoring() {
        startMonitoringCalled = true
    }

    func stopMonitoring() {
        stopMonitoringCalled = true
    }

    // Simulate song end
    func simulateSongEnded() async {
        await onSongEnded?()
    }
}
