//
//  SongError.swift
//  Back2Back
//
//  Created by Claude on 10/12/25.
//

import Foundation
import SwiftUI

/// Represents a failed song selection attempt for debugging purposes
struct SongError: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let artistName: String
    let songTitle: String
    let personaName: String
    let errorType: SongErrorType
    let errorReason: String
    let matchDetails: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        artistName: String,
        songTitle: String,
        personaName: String,
        errorType: SongErrorType,
        errorReason: String,
        matchDetails: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.artistName = artistName
        self.songTitle = songTitle
        self.personaName = personaName
        self.errorType = errorType
        self.errorReason = errorReason
        self.matchDetails = matchDetails
    }
}

// MARK: - SongErrorType
extension SongError {
    enum SongErrorType: String, Codable, CaseIterable {
        case notFoundInAppleMusic
        case noGoodMatch
        case validationFailed
        case alreadyPlayed
        case searchError

        var displayName: String {
            switch self {
            case .notFoundInAppleMusic:
                return "Not Found in Apple Music"
            case .noGoodMatch:
                return "No Good Match"
            case .validationFailed:
                return "Validation Failed"
            case .alreadyPlayed:
                return "Already Played"
            case .searchError:
                return "Search Error"
            }
        }

        var icon: String {
            switch self {
            case .notFoundInAppleMusic:
                return "magnifyingglass.circle.fill"
            case .noGoodMatch:
                return "questionmark.circle.fill"
            case .validationFailed:
                return "xmark.shield.fill"
            case .alreadyPlayed:
                return "arrow.clockwise.circle.fill"
            case .searchError:
                return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .notFoundInAppleMusic:
                return .orange
            case .noGoodMatch:
                return .yellow
            case .validationFailed:
                return .red
            case .alreadyPlayed:
                return .blue
            case .searchError:
                return .red
            }
        }
    }
}
