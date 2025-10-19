//
//  FavoritesListView.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  Refactored to use ViewModel only (Issue #56, 2025-10-18)
//  Updated with playlist export feature (Issue #85, 2025-10-19)
//

import SwiftUI
import MusicKit
import OSLog

struct FavoritesListView: View {
    let viewModel: FavoritesViewModel
    let musicService: MusicServiceProtocol

    @State private var showPlaylistPicker = false
    @State private var selectedSongForPlaylist: FavoritedSong?

    var body: some View {
        Group {
            if viewModel.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPlaylistPicker) {
            if let selectedSong = selectedSongForPlaylist {
                PlaylistPickerView(
                    viewModel: PlaylistPickerViewModel(
                        musicService: musicService,
                        favoritedSong: selectedSong
                    )
                )
            }
        }
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
            // Use ViewModel's sorted favorites
            ForEach(viewModel.sortedFavorites) { favoritedSong in
                FavoriteSongRow(favoritedSong: favoritedSong)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button {
                            B2BLog.ui.info("User selected 'Add to Playlist' for: \(favoritedSong.title)")
                            selectedSongForPlaylist = favoritedSong
                            showPlaylistPicker = true
                        } label: {
                            Label("Add to Playlist", systemImage: "text.badge.plus")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                B2BLog.ui.info("User swiped to remove favorite: \(favoritedSong.title)")
                                viewModel.removeFavorite(songId: favoritedSong.songId)
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
        FavoritesListView(
            viewModel: FavoritesViewModel(favoritesService: FavoritesService()),
            musicService: MusicService()
        )
    }
}
