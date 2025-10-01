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
    func searchCatalog(for searchTerm: String, limit: Int = 25) async throws -> [MusicSearchResult] {
        guard !searchTerm.isEmpty else {
            B2BLog.search.debug("Empty search term, returning empty results")
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return []
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

            return results
        } catch {
            B2BLog.search.error("❌ searchCatalog: \(error.localizedDescription)")
            await MainActor.run {
                isSearching = false
                searchResults = []
            }
            throw error
        }
    }

    /// Search the Apple Music catalog with pagination support
    /// Fetches multiple pages of results up to maxResults total
    func searchCatalogWithPagination(
        for searchTerm: String,
        pageSize: Int = 25,
        maxResults: Int = 200
    ) async throws -> [MusicSearchResult] {
        guard !searchTerm.isEmpty else {
            B2BLog.search.debug("Empty search term, returning empty results")
            return []
        }

        B2BLog.search.info("🔍 Paginated search for: \(searchTerm) (pageSize: \(pageSize), maxResults: \(maxResults))")
        let startTime = Date()

        var allResults: [MusicSearchResult] = []
        var offset = 0

        do {
            // Keep fetching pages until we reach maxResults or run out of results
            while allResults.count < maxResults {
                var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
                request.limit = pageSize
                request.offset = offset
                request.includeTopResults = (offset == 0) // Only include top results in first page

                B2BLog.network.debug("🌐 API: MusicCatalogSearchRequest (offset: \(offset))")
                let response = try await request.response()
                let pageResults = response.songs.map { MusicSearchResult(song: $0) }

                // If we got no results, we've exhausted the catalog
                if pageResults.isEmpty {
                    B2BLog.search.debug("No more results available at offset \(offset)")
                    break
                }

                allResults.append(contentsOf: pageResults)
                B2BLog.search.debug("Page results: \(pageResults.count), Total so far: \(allResults.count)")

                // If we got fewer results than the page size, we've reached the end
                if pageResults.count < pageSize {
                    B2BLog.search.debug("Received partial page (\(pageResults.count) < \(pageSize)), stopping pagination")
                    break
                }

                offset += pageSize
            }

            let duration = Date().timeIntervalSince(startTime)
            B2BLog.search.debug("⏱️ paginatedSearchDuration: \(duration)")
            B2BLog.search.info("Found \(allResults.count) total results across \(offset / pageSize + 1) pages")

            return allResults
        } catch {
            B2BLog.search.error("❌ searchCatalogWithPagination: \(error.localizedDescription)")
            throw error
        }
    }
}
