//
//  ToastService.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  Toast notification system for user feedback
//

import Foundation
import SwiftUI
import Observation
import OSLog

/// Manages toast notifications across the app
@MainActor
@Observable
final class ToastService {
    /// Currently displayed toast (nil if none showing)
    private(set) var currentToast: Toast?

    /// Queue of pending toasts
    private var toastQueue: [Toast] = []

    /// Timer for auto-dismiss
    private var dismissTask: Task<Void, Never>?

    init() {
        B2BLog.ui.debug("ToastService initialized")
    }

    /// Show a toast notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of toast (error, success, info, warning)
    ///   - duration: Auto-dismiss duration (default: 4 seconds)
    ///   - action: Optional action button configuration
    func show(
        _ message: String,
        type: ToastType = .error,
        duration: TimeInterval = 4.0,
        action: ToastAction? = nil
    ) {
        let toast = Toast(
            id: UUID(),
            message: message,
            type: type,
            duration: duration,
            action: action
        )

        B2BLog.ui.info("Showing \(String(describing: type)) toast: \(message)")

        if currentToast == nil {
            // No toast showing, display immediately
            presentToast(toast)
        } else {
            // Queue for later
            toastQueue.append(toast)
            B2BLog.ui.debug("Toast queued (\(self.toastQueue.count) in queue)")
        }
    }

    /// Dismiss the current toast
    func dismiss() {
        guard let toast = currentToast else { return }

        B2BLog.ui.debug("Dismissing toast: \(toast.message)")
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = nil
        }

        // Show next queued toast if any
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300)) // Wait for animation
            if !toastQueue.isEmpty {
                let nextToast = toastQueue.removeFirst()
                presentToast(nextToast)
            }
        }
    }

    /// Clear all pending toasts
    func clearQueue() {
        B2BLog.ui.debug("Clearing toast queue (\(self.toastQueue.count) toasts)")
        toastQueue.removeAll()
    }

    // MARK: - Private Methods

    private func presentToast(_ toast: Toast) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentToast = toast
        }

        // Schedule auto-dismiss
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(toast.duration))
            if currentToast?.id == toast.id {
                dismiss()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension ToastService {
    /// Show an error toast
    func error(_ message: String, duration: TimeInterval = 4.0) {
        show(message, type: .error, duration: duration)
    }

    /// Show a success toast
    func success(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .success, duration: duration)
    }

    /// Show an info toast
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .info, duration: duration)
    }

    /// Show a warning toast
    func warning(_ message: String, duration: TimeInterval = 3.5) {
        show(message, type: .warning, duration: duration)
    }

    /// Show an error toast with retry action
    func errorWithRetry(_ message: String, onRetry: @escaping () -> Void) {
        show(
            message,
            type: .error,
            duration: 6.0,
            action: ToastAction(label: "Retry", action: onRetry)
        )
    }
}
