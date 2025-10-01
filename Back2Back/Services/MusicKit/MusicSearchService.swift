//
//  MusicSearchService.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from MusicService as part of Phase 3 refactoring (#23)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Handles Apple Music catalog search
@MainActor
@Observable
final class MusicSearchService {
    var searchResults: [MusicSearchResult] = []
    var isSearching: Bool = false

    init() {
        B2BLog.musicKit.debug("Initializing MusicSearchService")
    }

    /// Search the Apple Music catalog
    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws {
        guard !searchTerm.isEmpty else {
            B2BLog.search.debug("Empty search term, clearing results")
            await MainActor.run {
                searchResults = []
            }
            return
        }

        B2BLog.search.info("🔍 Searching for: \(searchTerm)")
        let startTime = Date()

        await MainActor.run {
            isSearching = true
        }

        do {
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
            request.limit = limit
            request.includeTopResults = true

            B2BLog.network.debug("🌐 API: MusicCatalogSearchRequest")
            let response = try await request.response()
            let results = response.songs.map { MusicSearchResult(song: $0) }

            let duration = Date().timeIntervalSince(startTime)
            B2BLog.search.debug("⏱️ searchDuration: \(duration)")
            B2BLog.search.info("Found \(results.count) results for '\(searchTerm)'")

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            B2BLog.search.error("❌ searchCatalog: \(error.localizedDescription)")
            await MainActor.run {
                isSearching = false
                searchResults = []
            }
            throw error
        }
    }
}
