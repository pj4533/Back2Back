import Foundation
import MusicKit
@testable import Back2Back

@MainActor
class MockTurnManager {
    var advanceToNextSongCalled = false
    var lastAdvancedSong: Song?

    func advanceToNextSong() async -> Song? {
        advanceToNextSongCalled = true
        return lastAdvancedSong
    }
}
