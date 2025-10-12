//
//  FavoriteSongRow.swift
//  Back2Back
//
//  Created on 2025-10-12.
//

import SwiftUI
import OSLog

struct FavoriteSongRow: View {
    let favoritedSong: FavoritedSong

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = favoritedSong.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    )
            }

            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(favoritedSong.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(favoritedSong.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(favoritedSong.personaName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(formatDate(favoritedSong.favoritedAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    FavoriteSongRow(
        favoritedSong: FavoritedSong(
            songId: "preview-id",
            title: "Test Song",
            artistName: "Test Artist",
            artworkURL: nil,
            personaName: "Test Persona",
            personaId: UUID(),
            favoritedAt: Date()
        )
    )
    .padding()
}
