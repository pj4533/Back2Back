//
//  SongErrorLoggerService.swift
//  Back2Back
//
//  Created by Claude on 10/12/25.
//

import Foundation
import Observation
import OSLog

/// Service for logging and managing song selection errors for debugging purposes
@MainActor
@Observable
final class SongErrorLoggerService {
    static let shared = SongErrorLoggerService()

    private(set) var errors: [SongError] = []
    private let maxErrors = 100  // Keep last 100 errors
    private let storageKey = "com.saygoodnight.back2back.songErrors"

    private init() {
        loadErrors()
    }

    /// Log a song selection error
    func logError(
        artistName: String,
        songTitle: String,
        personaName: String,
        errorType: SongError.SongErrorType,
        errorReason: String,
        detailedReason: String? = nil,
        matchDetails: String? = nil
    ) {
        let error = SongError(
            artistName: artistName,
            songTitle: songTitle,
            personaName: personaName,
            errorType: errorType,
            errorReason: errorReason,
            detailedReason: detailedReason,
            matchDetails: matchDetails
        )

        errors.insert(error, at: 0)  // Insert at beginning for newest-first order

        // Enforce FIFO eviction if we exceed max errors
        if errors.count > maxErrors {
            errors.removeLast()
        }

        saveErrors()

        // Log to B2BLog for additional visibility
        B2BLog.ai.warning("Song selection error: \(errorType.displayName) - \(artistName) - \(songTitle)")
    }

    /// Clear all logged errors
    func clearAllErrors() {
        errors.removeAll()
        saveErrors()
        B2BLog.ai.info("Cleared all song errors")
    }

    // MARK: - Persistence

    private func loadErrors() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            errors = try decoder.decode([SongError].self, from: data)
            B2BLog.ai.debug("Loaded \(self.errors.count) song errors from UserDefaults")
        } catch {
            B2BLog.ai.error("Failed to load song errors: \(error.localizedDescription)")
            errors = []
        }
    }

    private func saveErrors() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(errors)
            UserDefaults.standard.set(data, forKey: storageKey)
            B2BLog.ai.trace("Saved \(self.errors.count) song errors to UserDefaults")
        } catch {
            B2BLog.ai.error("Failed to save song errors: \(error.localizedDescription)")
        }
    }
}
