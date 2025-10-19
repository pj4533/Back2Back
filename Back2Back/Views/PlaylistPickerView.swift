//
//  PlaylistPickerView.swift
//  Back2Back
//
//  Created as part of playlist export feature (Issue #85)
//

import SwiftUI
import MusicKit
import OSLog

struct PlaylistPickerView: View {
    let viewModel: PlaylistPickerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSuccessAlert = false
    @State private var selectedPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.hasError {
                    errorView
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    playlistListView
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadPlaylists()
            }
            .alert("Added to Playlist", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Successfully added to '\(selectedPlaylistName)'")
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading playlists...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Error Loading Playlists", systemImage: "exclamationmark.triangle")
        } description: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadPlaylists()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Playlists",
            systemImage: "music.note.list",
            description: Text("Create playlists in the Apple Music app to add songs to them.")
        )
    }

    private var playlistListView: some View {
        List {
            ForEach(viewModel.playlists, id: \.id) { playlist in
                PlaylistRow(playlist: playlist)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        addToPlaylist(playlist)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func addToPlaylist(_ playlist: Playlist) {
        Task {
            B2BLog.ui.info("User tapped playlist: \(playlist.name)")
            let success = await viewModel.addToPlaylist(playlist)

            if success {
                selectedPlaylistName = playlist.name
                showSuccessAlert = true
            }
            // Error case is handled by viewModel's errorMessage
        }
    }
}

// MARK: - Playlist Row

private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            // Playlist artwork
            if let artwork = playlist.artwork {
                ArtworkImage(artwork, width: 60)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.gray)
                    )
            }

            // Playlist details
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)

                if let trackCount = playlist.tracks?.count {
                    Text("\(trackCount) song\(trackCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chevron
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    PlaylistPickerView(
        viewModel: PlaylistPickerViewModel(
            musicService: MusicService(),
            favoritedSong: FavoritedSong(
                songId: "preview-id",
                title: "Test Song",
                artistName: "Test Artist",
                artworkURL: nil,
                personaName: "Test Persona",
                personaId: UUID()
            )
        )
    )
}
