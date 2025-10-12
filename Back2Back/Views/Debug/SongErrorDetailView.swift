//
//  SongErrorDetailView.swift
//  Back2Back
//
//  Created by Claude on 10/12/25.
//

import SwiftUI

/// Detailed view showing complete information about a song selection error
struct SongErrorDetailView: View {
    let error: SongError

    var body: some View {
        List {
            // Song Information Section
            Section {
                DetailRow(label: "Song", value: error.songTitle)
                DetailRow(label: "Artist", value: error.artistName)
                DetailRow(label: "Persona", value: error.personaName)
                DetailRow(label: "Timestamp", value: error.timestamp.formatted(date: .abbreviated, time: .shortened))
            } header: {
                Text("Song Information")
            }

            // Error Type Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: error.errorType.icon)
                        .foregroundStyle(error.errorType.color)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.errorType.displayName)
                            .font(.headline)
                            .foregroundStyle(error.errorType.color)

                        Text(error.errorReason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Error Type")
            }

            // Detailed Reason Section (if available)
            if let detailedReason = error.detailedReason, !detailedReason.isEmpty {
                Section {
                    Text(detailedReason)
                        .font(.body)
                        .foregroundStyle(.primary)
                } header: {
                    Text("Detailed Explanation")
                }
            }

            // Match Details Section (if available)
            if let matchDetails = error.matchDetails, !matchDetails.isEmpty {
                Section {
                    Text(matchDetails)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Match Details")
                }
            }
        }
        .navigationTitle("Error Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DetailRow
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview
#Preview("Validation Failed") {
    NavigationStack {
        SongErrorDetailView(
            error: SongError(
                artistName: "Ava Max",
                songTitle: "Salt",
                personaName: "NYC Rap DJ",
                errorType: .validationFailed,
                errorReason: "Wrong genre - pop vs rap",
                detailedReason: "The song 'Salt' by Ava Max is not appropriate for this DJ persona. The DJ's style focuses on female-led rap, trap, bounce, and harder-hitting cuts, while 'Salt' is an electropop song from 2018. Although Ava Max is a female artist, the genre and style do not align with the DJ's musical preferences, which are more aligned with rap and trap.",
                matchDetails: "Confidence: 0.95"
            )
        )
    }
}

#Preview("Not Found in Apple Music") {
    NavigationStack {
        SongErrorDetailView(
            error: SongError(
                artistName: "Obscure Artist",
                songTitle: "Rare Track",
                personaName: "Vinyl Collector",
                errorType: .notFoundInAppleMusic,
                errorReason: "No search results found in Apple Music"
            )
        )
    }
}
