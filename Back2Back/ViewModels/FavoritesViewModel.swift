//
//  FavoritesViewModel.swift
//  Back2Back
//
//  Created on 2025-10-18.
//  Part of MVVM architecture completion (Issue #56)
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class FavoritesViewModel {
    private let favoritesService: FavoritesService

    init(favoritesService: FavoritesService) {
        self.favoritesService = favoritesService
    }

    // MARK: - Computed Properties

    var favorites: [FavoritedSong] {
        favoritesService.favorites
    }

    var isEmpty: Bool {
        favorites.isEmpty
    }

    /// Return favorites sorted by most recent first
    var sortedFavorites: [FavoritedSong] {
        favorites.sorted { $0.favoritedAt > $1.favoritedAt }
    }

    // MARK: - Actions

    func removeFavorite(songId: String) {
        B2BLog.ui.info("Removing favorite: \(songId)")
        favoritesService.removeFavorite(songId: songId)
    }
}
