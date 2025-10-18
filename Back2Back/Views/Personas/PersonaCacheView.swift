//
//  PersonaCacheView.swift
//  Back2Back
//
//  Created on 2025-10-18.
//

import SwiftUI
import OSLog

struct PersonaCacheView: View {
    let persona: Persona
    let cacheService: PersonaSongCacheService

    @State private var cachedSongs: [CachedSong] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if cachedSongs.isEmpty {
                emptyStateView
            } else {
                cacheListView
            }
        }
        .navigationTitle("\(persona.name) Cache")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadCachedSongs()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Cached Songs",
            systemImage: "tray",
            description: Text("This persona hasn't selected any songs yet, or the cache has been cleared.")
        )
    }

    private var cacheListView: some View {
        List {
            ForEach(cachedSongs, id: \.selectedAt) { cachedSong in
                CachedSongRow(cachedSong: cachedSong)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            withAnimation {
                                removeSong(cachedSong)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func loadCachedSongs() {
        cachedSongs = cacheService.getRecentSongs(for: persona.id).reversed()
        B2BLog.ai.debug("Loaded \(cachedSongs.count) cached songs for persona \(persona.name)")
    }

    private func removeSong(_ song: CachedSong) {
        B2BLog.ui.info("User removed song from cache: '\(song.songTitle)' by '\(song.artist)' (persona: \(persona.name))")
        cacheService.removeSong(personaId: persona.id, artist: song.artist, songTitle: song.songTitle)
        loadCachedSongs() // Reload the list after removal
    }
}

#Preview {
    NavigationStack {
        PersonaCacheView(
            persona: Persona(
                name: "Rare Groove Collector",
                description: "Focused on obscure funk, soul, and jazz from the 1960s-1980s"
            ),
            cacheService: PersonaSongCacheService()
        )
    }
}
