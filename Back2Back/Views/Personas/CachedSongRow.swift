//
//  CachedSongRow.swift
//  Back2Back
//
//  Created on 2025-10-18.
//

import SwiftUI

struct CachedSongRow: View {
    let cachedSong: CachedSong

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder artwork icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)

                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(cachedSong.songTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(cachedSong.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Added: \(formatDate(cachedSong.selectedAt))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    List {
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "The Beatles",
                songTitle: "Come Together",
                selectedAt: Date()
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "David Bowie",
                songTitle: "Heroes",
                selectedAt: Date().addingTimeInterval(-86400)
            )
        )
    }
}
