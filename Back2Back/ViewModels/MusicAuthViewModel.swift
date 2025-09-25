import Foundation
import MusicKit
import SwiftUI
import Combine

@MainActor
class MusicAuthViewModel: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    @Published var isRequestingAuthorization: Bool = false

    private let musicService = MusicService.shared

    init() {
        checkCurrentAuthorizationStatus()
    }

    func checkCurrentAuthorizationStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
        isAuthorized = authorizationStatus == .authorized
    }

    func requestAuthorization() {
        guard !isRequestingAuthorization else { return }

        Task {
            isRequestingAuthorization = true
            errorMessage = nil

            do {
                try await musicService.requestAuthorization()
                checkCurrentAuthorizationStatus()
            } catch {
                errorMessage = error.localizedDescription
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
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}