import Foundation
import MusicKit
@testable import Back2Back

@MainActor
class MockAISongCoordinator {
    var startPrefetchCalled = false
    var cancelPrefetchCalled = false
    var lastPrefetchQueueStatus: QueueStatus?

    func startPrefetch(queueStatus: QueueStatus) {
        startPrefetchCalled = true
        lastPrefetchQueueStatus = queueStatus
    }

    func cancelPrefetch() {
        cancelPrefetchCalled = true
    }
}
