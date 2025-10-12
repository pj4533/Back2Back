//
//  FavoritesListView.swift
//  Back2Back
//
//  Created on 2025-10-12.
//

import SwiftUI
import MusicKit
import OSLog

struct FavoritesListView: View {
    private let favoritesService = FavoritesService.shared

    var body: some View {
        Group {
            if favoritesService.favorites.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "heart.slash",
            description: Text("Tap the heart icon on songs in your session history to add them to your favorites.")
        )
    }

    private var favoritesListView: some View {
        List {
            // Sort directly in the ForEach for proper observation
            ForEach(favoritesService.favorites.sorted { $0.favoritedAt > $1.favoritedAt }) { favoritedSong in
                FavoriteSongRow(favoritedSong: favoritedSong)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                B2BLog.ui.info("User swiped to remove favorite: \(favoritedSong.title)")
                                favoritesService.removeFavorite(songId: favoritedSong.songId)
                            }
                        } label: {
                            Label("Remove", systemImage: "heart.slash.fill")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        FavoritesListView()
    }
}
