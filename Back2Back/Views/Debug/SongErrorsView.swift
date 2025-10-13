//
//  SongErrorsView.swift
//  Back2Back
//
//  Created by Claude on 10/12/25.
//

import SwiftUI
import Observation

/// Debug view displaying failed song selection attempts
struct SongErrorsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var errorService: SongErrorLoggerService
    @State private var showingClearAlert = false

    init(errorService: SongErrorLoggerService) {
        self._errorService = Bindable(wrappedValue: errorService)
    }

    var body: some View {
        List {
            if errorService.errors.isEmpty {
                ContentUnavailableView(
                    "No Song Errors",
                    systemImage: "checkmark.circle",
                    description: Text("All song selections successful")
                )
            } else {
                ForEach(errorService.errors) { error in
                    NavigationLink(destination: SongErrorDetailView(error: error)) {
                        SongErrorRow(error: error)
                    }
                }
            }
        }
        .navigationTitle("Song Errors")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !errorService.errors.isEmpty {
                Button("Clear All", role: .destructive) {
                    showingClearAlert = true
                }
            }
        }
        .alert("Clear All Errors?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                errorService.clearAllErrors()
            }
        } message: {
            Text("This will remove all logged song errors. This action cannot be undone.")
        }
    }
}

// MARK: - SongErrorRow
struct SongErrorRow: View {
    let error: SongError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Song info with error icon
            HStack(spacing: 12) {
                Image(systemName: error.errorType.icon)
                    .foregroundStyle(error.errorType.color)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(error.songTitle)
                        .font(.headline)
                        .lineLimit(2)

                    Text(error.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Metadata row
            HStack {
                Label(error.personaName, systemImage: "music.mic")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(error.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Error type badge
            Text(error.errorType.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(error.errorType.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(error.errorType.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Error reason
            if !error.errorReason.isEmpty {
                Text(error.errorReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Optional match details (confidence scores, etc.)
            if let details = error.matchDetails, !details.isEmpty {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("With Errors") {
    NavigationStack {
        SongErrorsView(errorService: SongErrorLoggerService())
    }
}

#Preview("Empty State") {
    NavigationStack {
        SongErrorsView(errorService: SongErrorLoggerService())
    }
}
