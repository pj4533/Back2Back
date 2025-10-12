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
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the heart icon on songs in your session history to add them to your favorites.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoritesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(favoritesService.getFavorites()) { favoritedSong in
                    FavoriteSongRow(favoritedSong: favoritedSong)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                B2BLog.ui.info("User swiped to remove favorite: \(favoritedSong.title)")
                                favoritesService.removeFavorite(songId: favoritedSong.songId)
                            } label: {
                                Label("Remove", systemImage: "heart.slash.fill")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesListView()
    }
}
