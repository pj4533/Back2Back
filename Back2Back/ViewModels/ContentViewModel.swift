//
//  ContentViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation

@MainActor
@Observable
final class ContentViewModel {
    private let musicService: MusicService

    init(musicService: MusicService) {
        self.musicService = musicService
    }

    // MARK: - Computed Properties

    var isAuthorized: Bool {
        musicService.isAuthorized
    }
}
