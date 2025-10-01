//
//  ViewModelError.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Provides unified error handling pattern for ViewModels as part of Phase 3 refactoring (#23)
//

import Foundation
import OSLog

/// Protocol providing unified error handling for ViewModels
@MainActor
protocol ViewModelError: AnyObject {
    /// The current error message to display to the user
    var errorMessage: String? { get set }

    /// Handle an error with context and logging
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: A brief description of what operation failed
    func handleError(_ error: Error, context: String)

    /// Clear any existing error message
    func clearError()
}

// MARK: - Default Implementation

extension ViewModelError {
    /// Default error handling implementation with comprehensive logging
    func handleError(_ error: Error, context: String) {
        let errorDescription = error.localizedDescription
        errorMessage = "\(context): \(errorDescription)"

        // Log the error with appropriate severity
        if error is CancellationError {
            B2BLog.ui.debug("Operation cancelled: \(context)")
        } else {
            B2BLog.ui.error("❌ \(context): \(errorDescription)")
            B2BLog.ui.debug("Error details: \(String(describing: error))")
        }
    }

    /// Clear any existing error message
    func clearError() {
        if errorMessage != nil {
            B2BLog.ui.debug("Clearing error message")
            errorMessage = nil
        }
    }

    /// Handle an error with a custom message for the user
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - userMessage: The message to show to the user
    ///   - context: A brief description for logging
    func handleError(_ error: Error, userMessage: String, context: String) {
        errorMessage = userMessage

        // Log the underlying error details
        if error is CancellationError {
            B2BLog.ui.debug("Operation cancelled: \(context)")
        } else {
            B2BLog.ui.error("❌ \(context): \(error.localizedDescription)")
            B2BLog.ui.debug("Error details: \(String(describing: error))")
            B2BLog.ui.debug("User message: \(userMessage)")
        }
    }
}
