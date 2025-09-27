import Foundation
import MusicKit
import SwiftUI
import Combine
import OSLog

@MainActor
class MusicAuthViewModel: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    @Published var isRequestingAuthorization: Bool = false

    private let musicService = MusicService.shared

    init() {
        B2BLog.auth.info("🔐 Initializing MusicAuthViewModel")
        checkCurrentAuthorizationStatus()
    }

    func checkCurrentAuthorizationStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
        isAuthorized = authorizationStatus == .authorized
        B2BLog.auth.debug("Current authorization status: \(String(describing: self.authorizationStatus))")
    }

    func requestAuthorization() {
        guard !isRequestingAuthorization else {
            B2BLog.auth.debug("Authorization request already in progress")
            return
        }

        Task {
            B2BLog.auth.info("👤 User action: Request music authorization")
            isRequestingAuthorization = true
            errorMessage = nil

            do {
                try await musicService.requestAuthorization()
                checkCurrentAuthorizationStatus()
                B2BLog.auth.info("✅ Authorization request completed")
            } catch {
                errorMessage = error.localizedDescription
                B2BLog.auth.error("❌ MusicAuthViewModel.requestAuthorization: \(error.localizedDescription)")
            }

            isRequestingAuthorization = false
        }
    }

    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Music access has not been requested yet."
        case .denied:
            return "Music access was denied. Please enable in Settings."
        case .restricted:
            return "Music access is restricted on this device."
        case .authorized:
            return "Music access is authorized."
        @unknown default:
            return "Unknown authorization status."
        }
    }

    var canRequestAuthorization: Bool {
        authorizationStatus == .notDetermined && !isRequestingAuthorization
    }

    var shouldShowSettingsButton: Bool {
        authorizationStatus == .denied
    }

    func openSettings() {
        B2BLog.ui.info("👤 Open settings for music authorization")
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            B2BLog.ui.debug("Opened system settings")
        } else {
            B2BLog.ui.warning("Failed to create settings URL")
        }
    }
}