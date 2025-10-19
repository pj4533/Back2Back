//
//  SongSelectionDetailsView.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Comprehensive details view for AI song selection process (Issue #87)
//

import SwiftUI
import MusicKit
import OSLog

struct SongSelectionDetailsView: View {
    let sessionSong: SessionSong
    let debugInfo: SongDebugInfo?

    @State private var showingFormatSheet = false
    @State private var showingShareSheet = false
    @State private var exportFileURLs: [URL] = []

    private let exportService = FileExportService()

    var body: some View {
        Group {
            if let debugInfo = debugInfo {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Overview Section
                        overviewSection(debugInfo)

                        // AI Recommendation Section
                        aiRecommendationSection(debugInfo)

                        // MusicKit Search Section
                        searchSection(debugInfo)

                        // Matching Decision Section
                        matchingSection(debugInfo)

                        // Validation Section (if present)
                        if let validation = debugInfo.validationPhase {
                            validationSection(validation)
                        }

                        // Final Song Section (if present)
                        if let finalSong = debugInfo.finalSong {
                            finalSongSection(finalSong)
                        }

                        // Session Context Section
                        sessionContextSection(debugInfo)

                        // Persona Snapshot Section
                        personaSection(debugInfo)

                        // Direction Change Section (if present)
                        if let direction = debugInfo.directionChange {
                            directionChangeSection(direction)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Selection Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingFormatSheet = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showingFormatSheet) {
                    ExportFormatSheet { format in
                        exportDebugInfo(debugInfo, format: format)
                    }
                }
                .sheet(isPresented: $showingShareSheet, onDismiss: cleanupExportFiles) {
                    FileShareSheet(fileURLs: exportFileURLs, onComplete: cleanupExportFiles)
                }
            } else {
                ContentUnavailableView(
                    "No Selection Details",
                    systemImage: "info.circle",
                    description: Text("Song selection tracking was not enabled when this song was selected.\n\nEnable it in Configuration → Song Selection Tracking")
                )
            }
        }
    }

    // MARK: - Overview Section

    @ViewBuilder
    private func overviewSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Overview", icon: "info.circle.fill", color: .blue)

            infoRow("Outcome", value: debugInfo.outcome.rawValue.capitalized, highlighted: debugInfo.outcome != .success)
            infoRow("Timestamp", value: debugInfo.timestamp.formatted(date: .abbreviated, time: .standard))
            infoRow("Retry Count", value: "\(debugInfo.retryCount)")
        }
        .sectionStyle()
    }

    // MARK: - AI Recommendation Section

    @ViewBuilder
    private func aiRecommendationSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("AI Recommendation", icon: "brain.head.profile", color: .purple)

            infoRow("Artist", value: debugInfo.aiRecommendation.artist)
            infoRow("Title", value: debugInfo.aiRecommendation.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Rationale")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(debugInfo.aiRecommendation.rationale)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            infoRow("Model", value: debugInfo.aiRecommendation.model)
            infoRow("Reasoning Level", value: debugInfo.aiRecommendation.reasoningLevel)
        }
        .sectionStyle()
    }

    // MARK: - Search Section

    @ViewBuilder
    private func searchSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MusicKit Search", icon: "magnifyingglass", color: .green)

            infoRow("Query", value: debugInfo.searchPhase.query)
            infoRow("Results Found", value: "\(debugInfo.searchPhase.resultCount)")
            infoRow("Duration", value: String(format: "%.2f seconds", debugInfo.searchPhase.duration))

            if !debugInfo.searchPhase.results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Results")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(Array(debugInfo.searchPhase.results.enumerated()), id: \.element.id) { index, result in
                        searchResultRow(result, index: index)
                    }
                }
            }
        }
        .sectionStyle()
    }

    @ViewBuilder
    private func searchResultRow(_ result: SearchResultInfo, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(result.ranking + 1).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(result.title)
                            .font(.body)
                            .fontWeight(result.wasSelected ? .bold : .regular)

                        if result.wasSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }

                    Text(result.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let album = result.album {
                        Text(album)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let releaseDate = result.releaseDate {
                        Text("Released: \(releaseDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(result.wasSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Matching Section

    @ViewBuilder
    private func matchingSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Matching Decision", icon: "slider.horizontal.3", color: .orange)

            infoRow("Matcher Type", value: debugInfo.matchingPhase.matcherType)

            if let confidence = debugInfo.matchingPhase.confidenceScore {
                HStack {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", confidence * 100))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(confidence >= 0.8 ? .green : confidence >= 0.5 ? .orange : .red)
                }
            }

            if let reasoning = debugInfo.matchingPhase.reasoning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reasoning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(reasoning)
                        .font(.body)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if let llmResponse = debugInfo.matchingPhase.llmResponse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM Response")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(llmResponse)
                        .font(.body)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .sectionStyle()
    }

    // MARK: - Validation Section

    @ViewBuilder
    private func validationSection(_ validation: ValidationPhase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Validation", icon: "checkmark.shield.fill", color: validation.passed ? .green : .red)

            HStack {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(validation.passed ? "Passed" : "Failed", systemImage: validation.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(validation.passed ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(validation.shortExplanation)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Detailed Reasoning")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(validation.longExplanation)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .sectionStyle()
    }

    // MARK: - Final Song Section

    @ViewBuilder
    private func finalSongSection(_ finalSong: FinalSongInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Final Song", icon: "music.note", color: .pink)

            infoRow("Title", value: finalSong.title)
            infoRow("Artist", value: finalSong.artist)

            if let album = finalSong.album {
                infoRow("Album", value: album)
            }

            if let releaseDate = finalSong.releaseDate {
                infoRow("Released", value: releaseDate.formatted(date: .abbreviated, time: .omitted))
            }

            if let duration = finalSong.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                infoRow("Duration", value: "\(minutes):\(String(format: "%02d", seconds))")
            }

            if !finalSong.genreNames.isEmpty {
                infoRow("Genres", value: finalSong.genreNames.joined(separator: ", "))
            }
        }
        .sectionStyle()
    }

    // MARK: - Session Context Section

    @ViewBuilder
    private func sessionContextSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Session Context", icon: "list.bullet", color: .cyan)

            infoRow("Turn State", value: debugInfo.sessionContext.turnState.capitalized)
            infoRow("History Count", value: "\(debugInfo.sessionContext.historyCount) songs")
            infoRow("Queue Count", value: "\(debugInfo.sessionContext.queueCount) songs")

            if !debugInfo.sessionContext.recentSongs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Songs")
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(Array(debugInfo.sessionContext.recentSongs.enumerated()), id: \.offset) { index, recentSong in
                        HStack {
                            Text("\(debugInfo.sessionContext.recentSongs.count - index).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recentSong.title)
                                    .font(.body)
                                Text("\(recentSong.artist) • \(recentSong.selectedBy)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .sectionStyle()
    }

    // MARK: - Persona Section

    @ViewBuilder
    private func personaSection(_ debugInfo: SongDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Persona Snapshot", icon: "person.fill", color: .indigo)

            infoRow("Name", value: debugInfo.personaSnapshot.name)

            VStack(alignment: .leading, spacing: 4) {
                Text("Style Guide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(debugInfo.personaSnapshot.styleGuide)
                        .font(.body)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            infoRow("Created", value: debugInfo.personaSnapshot.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
        .sectionStyle()
    }

    // MARK: - Direction Change Section

    @ViewBuilder
    private func directionChangeSection(_ direction: DirectionChangeInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Direction Change", icon: "arrow.triangle.turn.up.right.diamond.fill", color: .yellow)

            infoRow("Button Label", value: direction.buttonLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text("Direction Prompt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(direction.directionPrompt)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            infoRow("Applied", value: direction.timestamp.formatted(date: .abbreviated, time: .standard))
        }
        .sectionStyle()
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, value: String, highlighted: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(highlighted ? .red : .primary)
        }
    }

    // MARK: - Export Functionality

    private func exportDebugInfo(_ debugInfo: SongDebugInfo, format: FileExportService.ExportFormat) {
        // Generate filename from song info
        let artist = sessionSong.song.artistName ?? "Unknown"
        let title = sessionSong.song.title
        let baseFilename = "Back2Back_Debug_\(artist)_\(title)"

        do {
            let content: String

            switch format {
            case .text:
                content = debugInfo.generateReport()

            case .json:
                content = debugInfo.generateJSON()

            case .combined:
                let report = debugInfo.generateReport()
                let json = debugInfo.generateJSON()
                content = """
                === Text Report ===

                \(report)

                === JSON Export ===

                \(json)
                """
            }

            // Create temporary file
            let fileURL = try exportService.createTemporaryFile(
                content: content,
                filename: baseFilename,
                format: format
            )

            // Store URL and show share sheet
            exportFileURLs = [fileURL]
            showingShareSheet = true

        } catch {
            B2BLog.general.error("Failed to export debug info: \(error.localizedDescription)")
            // TODO: Show error alert to user
        }
    }

    private func cleanupExportFiles() {
        exportService.cleanupFiles(exportFileURLs)
        exportFileURLs.removeAll()
    }
}

// MARK: - View Modifiers

extension View {
    func sectionStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

// Note: Preview disabled because Song requires actual MusicKit data
// #Preview {
//     NavigationStack {
//         SongSelectionDetailsView(
//             sessionSong: /* Requires actual MusicKit Song */,
//             debugInfo: nil
//         )
//     }
// }
