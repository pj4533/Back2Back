//
//  SongDebugService.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Manages comprehensive debugging information for AI song selections (Issue #87)
//

import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class SongDebugService: SongDebugServiceProtocol {
    private let userDefaults = UserDefaults.standard
    private let debugInfoKey = "com.back2back.songDebugInfo"
    private let maxEntries = 50

    private(set) var debugInfo: [UUID: SongDebugInfo] = [:]

    init() {
        loadDebugInfo()
        B2BLog.session.info("SongDebugService initialized (entries: \(self.debugInfo.count))")
    }

    // MARK: - Public API

    /// Log comprehensive debug information for a song selection
    func logDebugInfo(_ info: SongDebugInfo) {
        debugInfo[info.id] = info

        // FIFO eviction: Keep only the most recent maxEntries
        if debugInfo.count > maxEntries {
            // Sort by timestamp and keep the most recent ones
            let sortedEntries = debugInfo.values.sorted { $0.timestamp > $1.timestamp }
            let toKeep = sortedEntries.prefix(maxEntries)
            debugInfo = Dictionary(uniqueKeysWithValues: toKeep.map { ($0.id, $0) })

            B2BLog.session.debug("Evicted oldest debug entries (FIFO), keeping \(self.maxEntries) most recent")
        }

        saveDebugInfo()

        B2BLog.session.info("Logged debug info for song \(info.id) (outcome: \(info.outcome.rawValue), retries: \(info.retryCount))")
        B2BLog.session.debug("Debug info count: \(self.debugInfo.count)/\(self.maxEntries)")
    }

    /// Retrieve debug information for a specific session song
    func getDebugInfo(for sessionSongId: UUID) -> SongDebugInfo? {
        let info = debugInfo[sessionSongId]

        if info != nil {
            B2BLog.session.debug("Found debug info for song \(sessionSongId)")
        } else {
            B2BLog.session.debug("No debug info found for song \(sessionSongId)")
        }

        return info
    }

    /// Clear all debug information
    func clearAllDebugInfo() {
        debugInfo.removeAll()
        saveDebugInfo()
        B2BLog.session.warning("Cleared all song debug info")
    }

    /// Get all debug info sorted by timestamp (most recent first)
    func getAllDebugInfo() -> [SongDebugInfo] {
        let sorted = debugInfo.values.sorted { $0.timestamp > $1.timestamp }
        B2BLog.session.debug("Retrieved \(sorted.count) debug info entries")
        return sorted
    }

    // MARK: - Private Methods

    private func loadDebugInfo() {
        guard let data = userDefaults.data(forKey: debugInfoKey) else {
            B2BLog.session.debug("No saved song debug info found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let debugInfoArray = try decoder.decode([SongDebugInfo].self, from: data)
            debugInfo = Dictionary(uniqueKeysWithValues: debugInfoArray.map { ($0.id, $0) })

            B2BLog.session.info("Loaded \(self.debugInfo.count) song debug entries")

            // Calculate approximate storage size
            let sizeKB = Double(data.count) / 1024.0
            B2BLog.session.debug("Debug info storage size: \(String(format: "%.2f", sizeKB)) KB")

        } catch {
            B2BLog.session.error("Failed to load song debug info: \(error)")
            debugInfo = [:]
        }
    }

    private func saveDebugInfo() {
        let debugInfoArray = Array(debugInfo.values)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(debugInfoArray)
            userDefaults.set(data, forKey: debugInfoKey)

            // Log storage size
            let sizeKB = Double(data.count) / 1024.0
            B2BLog.session.debug("Saved \(debugInfoArray.count) debug entries (\(String(format: "%.2f", sizeKB)) KB)")

        } catch {
            B2BLog.session.error("Failed to save song debug info: \(error)")
        }
    }
}
