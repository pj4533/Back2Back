import Foundation
import MusicKit

struct MusicSearchResult: Identifiable {
    let id = UUID()
    let song: Song

    var title: String { song.title }
    var artistName: String { song.artistName }
    var albumTitle: String? { song.albumTitle }
    var artwork: Artwork? { song.artwork }
}

struct NowPlayingItem {
    let song: Song
    let isPlaying: Bool
    let playbackTime: TimeInterval
    let duration: TimeInterval
}

enum MusicAuthorizationError: LocalizedError {
    case denied
    case restricted
    case unknown

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Music library access was denied. Please enable access in Settings."
        case .restricted:
            return "Music library access is restricted on this device."
        case .unknown:
            return "An unknown error occurred while requesting music library access."
        }
    }
}

enum MusicPlaybackError: LocalizedError {
    case noSongSelected
    case playbackFailed(Error)
    case queueFailed

    var errorDescription: String? {
        switch self {
        case .noSongSelected:
            return "No song selected for playback."
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .queueFailed:
            return "Failed to add song to queue."
        }
    }
}

enum QueueStatus: CustomStringConvertible {
    case playing
    case upNext
    case queuedIfUserSkips
    case played

    var displayText: String {
        switch self {
        case .playing:
            return "Now Playing"
        case .upNext:
            return "Up Next"
        case .queuedIfUserSkips:
            return "Queued (AI continues if no user selection)"
        case .played:
            return ""
        }
    }

    var description: String {
        switch self {
        case .playing:
            return "playing"
        case .upNext:
            return "upNext"
        case .queuedIfUserSkips:
            return "queuedIfUserSkips"
        case .played:
            return "played"
        }
    }
}