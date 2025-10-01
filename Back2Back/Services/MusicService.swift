//
//  MusicService.swift
//  Back2Back
//
//  Refactored as part of Phase 3 refactoring (#23)
//  Now acts as a facade delegating to specialized services
//

import Foundation
import MusicKit
import Combine
import Observation
import OSLog

@MainActor
@Observable
class MusicService: MusicServiceProtocol {
    static let shared = MusicService()

    // Delegated services
    private let authService = MusicAuthService()
    private let searchService = MusicSearchService()
    private let playbackService = MusicPlaybackService()

    // MARK: - Exposed Properties (delegated)

    var authorizationStatus: MusicAuthorization.Status {
        authService.authorizationStatus
    }

    var isAuthorized: Bool {
        authService.isAuthorized
    }

    var searchResults: [MusicSearchResult] {
        searchService.searchResults
    }

    var currentlyPlaying: NowPlayingItem? {
        playbackService.currentlyPlaying
    }

    var isSearching: Bool {
        searchService.isSearching
    }

    var playbackState: ApplicationMusicPlayer.PlaybackStatus {
        playbackService.playbackState
    }

    var currentSongId: String? {
        playbackService.currentSongId
    }

    private init() {
        B2BLog.musicKit.info("🎵 Initializing MusicService (facade)")
    }

    // MARK: - Authorization (delegated to MusicAuthService)

    func requestAuthorization() async throws {
        try await authService.requestAuthorization()
    }

    // MARK: - Search (delegated to MusicSearchService)

    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws {
        try await searchService.searchCatalog(for: searchTerm, limit: limit)
    }

    // MARK: - Playback (delegated to MusicPlaybackService)

    func playSong(_ song: Song) async throws {
        try await playbackService.playSong(song)
    }

    func addToQueue(_ song: Song) async throws {
        try await playbackService.addToQueue(song)
    }

    func togglePlayPause() async throws {
        try await playbackService.togglePlayPause()
    }

    func skipToNext() async throws {
        try await playbackService.skipToNext()
    }

    func skipToPrevious() async throws {
        try await playbackService.skipToPrevious()
    }

    func clearQueue() {
        playbackService.clearQueue()
    }

    func getCurrentPlaybackTime() -> TimeInterval {
        playbackService.getCurrentPlaybackTime()
    }
}
