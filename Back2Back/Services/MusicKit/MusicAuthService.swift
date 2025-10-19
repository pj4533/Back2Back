//
//  MusicAuthService.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from MusicService as part of Phase 3 refactoring (#23)
//

import Foundation
import MusicKit
import Observation
import OSLog

/// Handles Apple Music authorization (both playback and library access)
@MainActor
@Observable
final class MusicAuthService {
    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var isAuthorized: Bool = false

    // Library access permission is separate from playback permission
    var hasLibraryAccess: Bool = false

    private static var isInitialized = false

    init() {
        if !Self.isInitialized {
            B2BLog.musicKit.info("🎵 Initializing MusicAuthService")
            Self.isInitialized = true
        }
        updateAuthorizationStatus()
    }

    /// Update the current authorization status
    func updateAuthorizationStatus() {
        let status = MusicAuthorization.currentStatus
        authorizationStatus = status
        isAuthorized = status == .authorized
        B2BLog.auth.info("Authorization status: \(String(describing: status))")

        // Check library access separately
        updateLibraryAccessStatus()
    }

    /// Check if library access is available
    /// Note: Library access requires explicit permission beyond playback
    private func updateLibraryAccessStatus() {
        // Library access piggybacks on the main authorization
        // But requires the user to have granted full access (not just playback)
        hasLibraryAccess = authorizationStatus == .authorized
        B2BLog.auth.info("Library access status: \(self.hasLibraryAccess)")
    }

    /// Request Apple Music authorization from the user
    func requestAuthorization() async throws {
        B2BLog.auth.trace("→ Entering requestAuthorization")

        let status = await MusicAuthorization.request()
        B2BLog.auth.info("Authorization request returned: \(String(describing: status))")

        await MainActor.run {
            authorizationStatus = status
            isAuthorized = status == .authorized
        }

        guard status == .authorized else {
            let error: MusicAuthorizationError
            switch status {
            case .denied:
                error = MusicAuthorizationError.denied
            case .restricted:
                error = MusicAuthorizationError.restricted
            default:
                error = MusicAuthorizationError.unknown
            }
            B2BLog.auth.error("❌ requestAuthorization: \(error.localizedDescription)")
            throw error
        }

        B2BLog.auth.info("✅ Music authorization granted")
        B2BLog.auth.trace("← Exiting requestAuthorization")
    }
}
